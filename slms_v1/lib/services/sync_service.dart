import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/utils/crypto_utils.dart';
import 'package:schoollms/utils/queue_manager.dart';

class SyncService {
  ServerSocket? _server;
  RawDatagramSocket? _discoveryServer;
  MDnsClient? _mdnsClient;
  final QueueManager _queueManager = QueueManager(maxConnections: 10);
  final List<Socket> _activeConnections = [];
  final DatabaseService _dbService;
  static const int maxRetries = 3;
  static const int discoveryPort = 8081;
  static const String serviceType = '_schoollms._tcp';
  static const int chunkSize = 1024 * 512; // 512KB

  SyncService(this._dbService) {
    _mdnsClient = MDnsClient();
  }

  Future<void> startTeacherHotspot(String teacherId, String classId) async {
    try {
      final ssid = 'SchoolLMS_$teacherId';
      final psk = CryptoUtils.generatePSK('teacher', teacherId, classId);
      // Ensure WiFi is enabled
      await WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true);
      // Create hotspot
      await WiFiForIoTPlugin.setWiFiAPEnabled(true);
      await WiFiForIoTPlugin.setWiFiAPSSID(ssid);
      await WiFiForIoTPlugin.setWiFiAPPreSharedKey(psk);
    } catch (e) {
      throw Exception('Failed to start hotspot: $e');
    }
  }

  Future<void> startSyncServer(String teacherId, String classId) async {
    try {
      _server = await ServerSocket.bind('0.0.0.0', 8080);
      await _dbService.cacheTeacherDevice(
          teacherId, classId, _server!.address.host, 8080);

      await _mdnsClient!.start();
      final ptrRecord = PtrResourceRecord(serviceType, 3600,
          domainName: 'Teacher_$teacherId.$classId.$serviceType.local');
      final srvRecord = SrvResourceRecord(
        'Teacher_$teacherId.$classId.$serviceType.local',
        3600,
        port: 8080,
        target: '${_server!.address.host}.local',
        priority: 0,
        weight: 0,
      );
      final txtRecord = TxtResourceRecord(
        'Teacher_$teacherId.$classId.$serviceType.local',
        3600,
        text: 'teacherId=$teacherId,classId=$classId',
      );

      _server!.listen((client) {
        if (_activeConnections.length < _queueManager.maxConnections) {
          _activeConnections.add(client);
          _handleClient(client, teacherId, classId);
        } else {
          client.write(utf8.encode(jsonEncode({'status': 'queue_full'})));
          client.close();
        }
      });

      _discoveryServer = await RawDatagramSocket.bind('0.0.0.0', discoveryPort);
      _discoveryServer!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoveryServer!.receive();
          if (datagram != null) {
            final request = jsonDecode(utf8.decode(datagram.data));
            if (request['type'] == 'connect_request') {
              _queueManager.addLearner(
                request['learnerId'],
                hasPendingChanges: request['hasPendingChanges'] ?? false,
              );
            }
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to start sync server: $e');
    }
  }

  void _handleClient(Socket client, String teacherId, String classId) {
    client.listen((data) async {
      try {
        final learnerId = _extractLearnerId(client);
        final deviceData = await _dbService.getLearnerDevice(learnerId);
        final psk = deviceData['psk'] ??
            CryptoUtils.generatePSK(learnerId, teacherId, classId);
        final lastSyncTime = deviceData['last_sync_time'] ?? 0;
        final decompressed = GZipDecoder().decodeBytes(data);
        final decrypted =
            CryptoUtils.decryptData(utf8.decode(decompressed), psk);
        final payload = jsonDecode(decrypted);
        if (payload['type'] == 'request_sync') {
          await _processSyncRequest(client, learnerId, psk, lastSyncTime);
          await _dbService.updateLastSyncTime(
              learnerId, DateTime.now().millisecondsSinceEpoch);
          _queueManager.updateLastSyncTime(learnerId);
        }
        client.write(utf8.encode(jsonEncode({'status': 'synced'})));
        client.close();
        _activeConnections.remove(client);
        _processQueue();
      } catch (e) {
        client.write(utf8
            .encode(jsonEncode({'status': 'error', 'message': e.toString()})));
        client.close();
        _activeConnections.remove(client);
        _processQueue();
      }
    }, onError: (e) {
      client.close();
      _activeConnections.remove(client);
      _processQueue();
    });
  }

  Future<void> _processSyncRequest(
      Socket client, String learnerId, String psk, int lastSyncTime) async {
    final pendingSyncs =
        await _dbService.getPendingSyncs(sinceTimestamp: lastSyncTime);
    final learnerTimetables = await _dbService.getLearnerTimetable(learnerId,
        sinceTimestamp: lastSyncTime);
    final questions = await _dbService.getQuestionsByTimetable('');
    final answers = await _dbService.getAnswersByQuestion('');
    final analytics = await _dbService.getAnalyticsByQuestion('');

    final batchedSyncs = <String, List<Map<String, dynamic>>>{};
    for (var sync in pendingSyncs) {
      final key = '${sync['table_name']}_${sync['operation']}';
      batchedSyncs[key] ??= [];
      batchedSyncs[key]!.add(sync);
    }

    // Delta sync for canvas data
    final protoData = ProtoCanvasData(
      strokes: questions
          .expand((q) {
            final json = jsonDecode(q.content);
            return (json['strokes'] as List)
                .map((s) => Stroke.fromJson(s).toProto());
          })
          .where((s) => s.points.isNotEmpty)
          .toList(),
      assets: questions.expand((q) {
        final json = jsonDecode(q.content);
        return (json['assets'] as List).map((a) => ProtoAsset(
              id: a['id'],
              type: a['type'],
              data: a['data'],
              position:
                  ProtoPoint(x: a['position']['x'], y: a['position']['y']),
              pageIndex: a['pageIndex'],
            ));
      }).toList(),
      lastSyncTime: lastSyncTime,
    );

    final syncData = {
      'timetables': learnerTimetables.map((t) => t.toMap()).toList(),
      'questions': questions.map((q) => q.toMap()).toList(),
      'answers': answers.map((a) => a.toMap()).toList(),
      'analytics': analytics.map((a) => a.toMap()).toList(),
      'batched_pending': batchedSyncs,
      'proto_data': protoData.toJson(), // Simulated Protobuf
    };
    final jsonData = jsonEncode(syncData);
    final compressed = GZipEncoder().encode(utf8.encode(jsonData))!;

    // Chunk large data
    for (int i = 0; i < compressed.length; i += chunkSize) {
      final chunk =
          compressed.sublist(i, min(i + chunkSize, compressed.length));
      final encrypted = CryptoUtils.encryptData(utf8.decode(chunk), psk);
      client.write(utf8.encode(encrypted));
    }

    for (var sync in pendingSyncs) {
      await _dbService.clearPendingSync(sync['id']);
    }
  }

  void _processQueue() {
    final nextLearner = _queueManager.getNextLearner();
    if (nextLearner != null) {
      // Notify learner to connect
    }
  }

  String _extractLearnerId(Socket client) {
    return client.remoteAddress.address;
  }

  Future<Map<String, dynamic>> discoverTeacher(
      String teacherId, String classId) async {
    int retries = 0;
    while (retries < maxRetries) {
      try {
        final cached = await _dbService.getTeacherDevice(teacherId, classId);
        if (cached.isNotEmpty && _isCacheValid(cached['last_discovered'])) {
          return {'ip': cached['ip'], 'port': cached['port']};
        }

        await _mdnsClient!.start();
        final serviceName = 'Teacher_$teacherId.$classId.$serviceType.local';
        await for (final ptr in _mdnsClient!.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(serviceType),
        )) {
          if (ptr.domainName == serviceName) {
            await for (final srv in _mdnsClient!.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(serviceName),
            )) {
              await for (final txt in _mdnsClient!.lookup<TxtResourceRecord>(
                ResourceRecordQuery.text(serviceName),
              )) {
                final txtData = txt.text
                    .split(',')
                    .fold<Map<String, String>>({}, (map, pair) {
                  final parts = pair.split('=');
                  map[parts[0]] = parts[1];
                  return map;
                });
                if (txtData['teacherId'] == teacherId &&
                    txtData['classId'] == classId) {
                  final ip = await _resolveIp(srv.target);
                  await _dbService.cacheTeacherDevice(
                      teacherId, classId, ip, srv.port);
                  return {'ip': ip, 'port': srv.port};
                }
              }
            }
          }
        }
        throw Exception('Teacher service not found');
      } catch (e) {
        retries++;
        if (retries >= maxRetries) {
          throw Exception(
              'Failed to discover teacher after $maxRetries attempts: $e');
        }
        await Future.delayed(Duration(seconds: 2 * retries));
      } finally {
        _mdnsClient!.stop();
      }
    }
    return {};
  }

  Future<String> _resolveIp(String hostname) async {
    final records = await _mdnsClient!.lookup<IPAddressResourceRecord>(
      ResourceRecordQuery.addressIPv4(hostname),
    );
    return records.firstWhere((r) => r.address != null).address.address;
  }

  bool _isCacheValid(int lastDiscovered) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastDiscovered) < 300000;
  }

  Future<void> connectLearner(
      String teacherId, String classId, String learnerId) async {
    int retries = 0;
    while (retries < maxRetries) {
      try {
        final deviceData = await _dbService.getLearnerDevice(learnerId);
        final psk = deviceData['psk'] ??
            CryptoUtils.generatePSK(learnerId, teacherId, classId);
        final lastSyncTime = deviceData['last_sync_time'] ?? 0;

        // Connect to teacher's hotspot
        final teacherInfo = await discoverTeacher(teacherId, classId);
        if (teacherInfo.isEmpty) throw Exception('Teacher hotspot not found');

        // Attempt to join hotspot (platform-specific, may require manual connection)
        await WiFiForIoTPlugin.connect(
          'SchoolLMS_$teacherId',
          password: psk,
          security: NetworkSecurity.WPA,
          joinOnce: true,
        );

        final socket =
            await Socket.connect(teacherInfo['ip'], teacherInfo['port']);
        final payload = {
          'type': 'request_sync',
          'learnerId': learnerId,
          'lastSyncTime': lastSyncTime
        };
        final jsonData = jsonEncode(payload);
        final compressed = GZipEncoder().encode(utf8.encode(jsonData))!;
        final encrypted = CryptoUtils.encryptData(utf8.decode(compressed), psk);
        socket.write(utf8.encode(encrypted));
        socket.listen((data) {
          try {
            final decompressed = GZipDecoder().decodeBytes(data);
            final decrypted =
                CryptoUtils.decryptData(utf8.decode(decompressed), psk);
            final response = jsonDecode(decrypted);
            if (response['status'] == 'synced') {
              _processSyncResponse(response);
              _dbService.updateLastSyncTime(
                  learnerId, DateTime.now().millisecondsSinceEpoch);
            }
            socket.close();
          } catch (e) {
            socket.close();
            throw Exception('Sync failed: $e');
          }
        }, onError: (e) {
          socket.close();
          throw Exception('Sync failed: $e');
        });
        return;
      } catch (e) {
        retries++;
        if (retries >= maxRetries) {
          throw Exception('Failed to connect after $maxRetries attempts: $e');
        }
        await Future.delayed(Duration(seconds: 2 * retries));
      }
    }
  }

  void _processSyncResponse(Map<String, dynamic> response) {
    final timetables = response['timetables'] as List;
    final questions = response['questions'] as List;
    final answers = response['answers'] as List;
    final analytics = response['analytics'] as List;
    final batchedPending = response['batched_pending'] as Map<String, dynamic>;

    for (var t in timetables) {
      _dbService._db.insert('learner_timetables', t,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (var q in questions) {
      _dbService._db
          .insert('questions', q, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (var a in answers) {
      _dbService._db
          .insert('answers', a, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (var a in analytics) {
      _dbService._db
          .insert('analytics', a, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    batchedPending.forEach((key, batch) {
      for (var item in batch) {
        final data = item['data'];
        _dbService._db.insert(
          item['table_name'],
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> stopSyncServer() async {
    _server?.close();
    _discoveryServer?.close();
    _mdnsClient?.stop();
    await WiFiForIoTPlugin.setWiFiAPEnabled(false);
  }
}
