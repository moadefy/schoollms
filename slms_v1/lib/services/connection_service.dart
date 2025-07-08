import 'dart:io';
import 'dart:convert';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:archive/archive.dart'; // Added for GZipEncoder
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/utils/crypto_utils.dart';
import 'package:schoollms/utils/queue_manager.dart';

class ConnectionService {
  ServerSocket? _hotspotServer; // Removed BluetoothServerSocket
  RawDatagramSocket? _discoveryServer;
  MDnsClient? _mdnsClient;
  final QueueManager _queueManager = QueueManager(maxConnections: 10);
  final List<Socket> _activeConnections = [];
  final DatabaseService _dbService;
  static const int discoveryPort = 8081;
  static const String serviceType = '_schoollms._tcp';
  static const int connectionTimeout = 30000; // 30 seconds per learner

  ConnectionService(this._dbService);

  Future<void> startTeacherConnection(String teacherId, String classId) async {
    try {
      // Fallback to hotspot (Bluetooth server not supported with flutter_bluetooth_serial)
      final ssid = 'SchoolLMS_$teacherId';
      final psk = CryptoUtils.generatePSK('teacher', teacherId, classId);
      await WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true);
      await WiFiForIoTPlugin.setWiFiAPEnabled(true);
      await WiFiForIoTPlugin.setWiFiAPSSID(ssid);
      await WiFiForIoTPlugin.setWiFiAPPreSharedKey(psk);

      _hotspotServer = await ServerSocket.bind('0.0.0.0', 8080);
      await _dbService.cacheTeacherDevice(
          teacherId, classId, _hotspotServer!.address.host, 8080);

      await _mdnsClient!.start();
      _hotspotServer!.listen((client) {
        _handleNewConnection(client, teacherId, classId);
      });

      _discoveryServer = await RawDatagramSocket.bind('0.0.0.0', discoveryPort);
      _discoveryServer!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoveryServer!.receive();
          if (datagram != null) {
            final request = jsonDecode(utf8.decode(datagram.data));
            if (request['type'] == 'connect_request') {
              _queueManager.addLearner(request['learnerId']);
            }
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to start connection: $e');
    }
  }

  void _handleNewConnection(Socket client, String teacherId, String classId) {
    if (_activeConnections.length < _queueManager.maxConnections) {
      _activeConnections.add(client);
      _scheduleConnectionTime(client, teacherId, classId);
    } else {
      client.write(utf8.encode(jsonEncode({'status': 'queue_full'})));
      client.close();
    }
  }

  void _scheduleConnectionTime(
      Socket client, String teacherId, String classId) {
    final learnerId = extractLearnerId(client);
    _queueManager.addLearner(learnerId);
    _processNextConnection(teacherId, classId);
  }

  void _processNextConnection(String teacherId, String classId) {
    if (_activeConnections.isNotEmpty) return; // Already processing

    final nextLearner = _queueManager.getNextLearner();
    if (nextLearner != null) {
      final client = _activeConnections.firstWhere(
        (c) => extractLearnerId(c) == nextLearner,
        orElse: () => null as Socket,
      );
      if (client != null) {
        _activeConnections.remove(client);
        _handleClientConnection(client, teacherId, classId);
        Future.delayed(Duration(milliseconds: connectionTimeout), () {
          client.close();
          _activeConnections.remove(client);
          _processNextConnection(teacherId, classId);
        });
      }
    }
  }

  void _handleClientConnection(
      Socket client, String teacherId, String classId) {
    client.listen((data) async {
      try {
        final learnerId = extractLearnerId(client);
        final deviceData = await _dbService.getLearnerDevice(learnerId);
        final psk = deviceData['psk'] ??
            CryptoUtils.generatePSK(learnerId, teacherId, classId);
        final decompressed = GZipDecoder().decodeBytes(data);
        final decrypted =
            CryptoUtils.decryptData(utf8.decode(decompressed), psk);
        final payload = jsonDecode(decrypted);
        if (payload['type'] == 'check_install') {
          client.write(utf8.encode(jsonEncode({'status': 'connected'})));
        }
      } catch (e) {
        client.write(utf8
            .encode(jsonEncode({'status': 'error', 'message': e.toString()})));
      } finally {
        client.close();
        _activeConnections.remove(client);
        _processNextConnection(teacherId, classId);
      }
    }, onError: (e) {
      client.close();
      _activeConnections.remove(client);
      _processNextConnection(teacherId, classId);
    }, onDone: () {
      client.close(); // Explicitly close without return
      _activeConnections.remove(client);
      _processNextConnection(teacherId, classId);
    });
  }

  String extractLearnerId(Socket client) {
    return client
        .remoteAddress.address; // Enhance with Bluetooth device ID if needed
  }

  Future<Map<String, dynamic>> discoverTeacher(
      String teacherId, String classId) async {
    int retries = 0;
    while (retries < 3) {
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
        if (retries >= 3) {
          throw Exception('Failed to discover teacher after 3 attempts: $e');
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
    return (await records.firstWhere((r) => r.address != null)).address.address;
  }

  bool _isCacheValid(int lastDiscovered) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastDiscovered) < 300000;
  }

  Future<void> connectLearner(
      String teacherId, String classId, String learnerId) async {
    int retries = 0;
    while (retries < 3) {
      try {
        final deviceData = await _dbService.getLearnerDevice(learnerId);
        final psk = deviceData['psk'] ??
            CryptoUtils.generatePSK(learnerId, teacherId, classId);

        final bluetoothState = await FlutterBluetoothSerial.instance.state;
        if (bluetoothState == BluetoothState.STATE_ON) {
          final pairedDevices =
              await FlutterBluetoothSerial.instance.getBondedDevices();
          final teacherDevice = pairedDevices.firstWhere(
            (d) => d.name?.contains(teacherId) ?? false,
            orElse: () => throw Exception(
                'No paired device found for teacherId $teacherId'),
          );
          if (teacherDevice != null) {
            final socket =
                await BluetoothConnection.toAddress(teacherDevice.address);
            final payload = {
              'type': 'connect_request',
              'learnerId': learnerId,
            };
            final jsonData = jsonEncode(payload);
            final compressed = GZipEncoder().encode(utf8.encode(jsonData))!;
            final encrypted =
                CryptoUtils.encryptData(utf8.decode(compressed), psk);
            socket.output.add(utf8.encode(encrypted));
            await socket.finish();
            return;
          }
        }

        final teacherInfo = await discoverTeacher(teacherId, classId);
        if (teacherInfo.isEmpty) throw Exception('Teacher hotspot not found');

        await WiFiForIoTPlugin.connect(
          'SchoolLMS_$teacherId',
          password: psk,
          security: NetworkSecurity.WPA,
          joinOnce: true,
        );

        final socket =
            await Socket.connect(teacherInfo['ip'], teacherInfo['port']);
        final payload = {
          'type': 'connect_request',
          'learnerId': learnerId,
        };
        final jsonData = jsonEncode(payload);
        final compressed = GZipEncoder().encode(utf8.encode(jsonData))!;
        final encrypted = CryptoUtils.encryptData(utf8.decode(compressed), psk);
        socket.write(utf8.encode(encrypted));
        await socket.close();
        return;
      } catch (e) {
        retries++;
        if (retries >= 3) {
          throw Exception('Failed to connect after 3 attempts: $e');
        }
        await Future.delayed(Duration(seconds: 2 * retries));
      }
    }
  }

  Future<void> stopConnection() async {
    _hotspotServer?.close();
    _discoveryServer?.close();
    _mdnsClient?.stop();
    await WiFiForIoTPlugin.setWiFiAPEnabled(false);
  }

  // Expose connection status for dependent services
  bool get hasActiveConnections => _activeConnections.isNotEmpty;
  List<Socket> get activeConnections => List.unmodifiable(_activeConnections);
}
