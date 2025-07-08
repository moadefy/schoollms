import 'dart:io'; // Added for HttpServer, ContentType, HttpStatus
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http_server/http_server.dart'; // Removed 'as http_server' prefix
import 'package:archive/archive.dart'; // For GZipEncoder
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/utils/crypto_utils.dart';
import 'package:uuid/uuid.dart';

class InstallService {
  static const String appFileName = 'schoollms_install.apk'; // Base app file
  HttpServer? _installServer; // Changed from http_server.HttpServer
  final _uuid = const Uuid();

  Future<void> prepareBaseApk(
      String teacherId, String classId, DatabaseService dbService) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final installFilePath = '${dir.path}/$appFileName';
      final file = File(installFilePath);

      // Check if APK exists, otherwise throw an error
      if (!await file.exists()) {
        throw Exception(
            'Base APK not found at $installFilePath. Please distribute it manually or bundle it with the app.');
      }

      // Generate and cache PSK for teacher
      final psk = CryptoUtils.generatePSK(teacherId, classId, '');
      await dbService.cacheTeacherDevice(
          teacherId, classId, InternetAddress.anyIPv4.address, 8081);
    } catch (e) {
      throw Exception('Failed to prepare base APK: $e');
    }
  }

  Future<void> startInstallServer(String teacherId, String classId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final installFilePath = '${dir.path}/$appFileName';
      _installServer = await HttpServer.bind(InternetAddress.anyIPv4, 8081);
      await _installServer!.listen((HttpRequest request) async {
        if (request.uri.path == '/install') {
          final file = File(installFilePath);
          if (await file.exists()) {
            request.response.headers.contentType = ContentType.binary;
            request.response.addStream(file.openRead());
            await request.response.close();
          } else {
            request.response
              ..statusCode = HttpStatus.notFound
              ..write('Install file not found')
              ..close();
          }
        } else if (request.uri.path == '/config') {
          final psk = await _getPSK(teacherId, classId);
          final config = jsonEncode(
              {'teacherId': teacherId, 'classId': classId, 'psk': psk});
          request.response
            ..headers.contentType = ContentType.json
            ..write(config)
            ..close();
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found')
            ..close();
        }
      });
      print('Install server started for $teacherId');
    } catch (e) {
      throw Exception('Failed to start install server: $e');
    }
  }

  Future<String> _getPSK(String teacherId, String classId) async {
    final dbService = DatabaseService();
    await dbService.init();
    final deviceData = await dbService.getTeacherDevice(teacherId, classId);
    return deviceData['psk'] ?? CryptoUtils.generatePSK(teacherId, classId, '');
  }

  Future<void> checkAndServeInstall(
      Socket client,
      String recipientId,
      String installerId,
      String classId,
      DatabaseService dbService,
      String role) async {
    bool appInstalled = false; // Placeholder for actual detection logic
    if (!appInstalled) {
      final installUrl = 'http://${client.address.address}:8081/install';
      final configUrl = 'http://${client.address.address}:8081/config';
      final psk = await _getPSK(installerId, classId);
      final response = {
        'status': 'not_installed',
        'install_url': installUrl,
        'config_url': configUrl,
        'installer_id': installerId,
        'class_id': classId,
        'psk': psk,
      };
      final jsonData = jsonEncode(response);
      final compressed = GZipEncoder().encode(utf8.encode(jsonData))!;
      final encrypted = CryptoUtils.encryptData(utf8.decode(compressed), psk);
      client.write(utf8.encode(encrypted));

      // Log installation event
      await dbService.insertData('installation_logs', {
        'id': _uuid.v4(),
        'installer_id': installerId,
        'recipient_id': recipientId,
        'role': role,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ip': client.address.address,
        'status': 'installed',
      });

      if (role == 'teacher') {
        await dbService.cacheTeacherDevice(
            recipientId, classId, client.address.address, 8081);
      } else if (role == 'learner') {
        await dbService.cacheLearnerDevice(
            recipientId, client.address.address, psk, 0);
      }
    } else {
      client.write(utf8.encode(jsonEncode({'status': 'installed'})));
    }
  }

  Future<void> startLearnerInstallServer(
      String learnerId, String parentId, DatabaseService dbService) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final installFilePath = '${dir.path}/$appFileName';
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 8082);
      await server.listen((HttpRequest request) async {
        if (request.uri.path == '/install') {
          final file = File(installFilePath);
          if (await file.exists()) {
            request.response.headers.contentType = ContentType.binary;
            request.response.addStream(file.openRead());
            await request.response.close();
          } else {
            request.response
              ..statusCode = HttpStatus.notFound
              ..write('Install file not found')
              ..close();
          }
        } else if (request.uri.path == '/config') {
          final psk = CryptoUtils.generatePSK(learnerId, parentId, '');
          final config = jsonEncode(
              {'learnerId': learnerId, 'parentId': parentId, 'psk': psk});
          request.response
            ..headers.contentType = ContentType.json
            ..write(config)
            ..close();
          await dbService.cacheTeacherDevice(
              learnerId, parentId, InternetAddress.anyIPv4.address, 8082);
        }
      });
      print('Learner install server started for $learnerId');
    } catch (e) {
      throw Exception('Failed to start learner install server: $e');
    }
  }

  Future<void> checkAndServeParentInstall(Socket client, String parentId,
      String learnerId, String classId, DatabaseService dbService) async {
    bool appInstalled = false; // Placeholder for actual detection logic
    if (!appInstalled) {
      final installUrl = 'http://${client.address.address}:8082/install';
      final configUrl = 'http://${client.address.address}:8082/config';
      final psk = CryptoUtils.generatePSK(learnerId, parentId, '');
      final response = {
        'status': 'not_installed',
        'install_url': installUrl,
        'config_url': configUrl,
        'learner_id': learnerId,
        'class_id': classId,
        'psk': psk,
      };
      final jsonData = jsonEncode(response);
      final compressed = GZipEncoder().encode(utf8.encode(jsonData))!;
      final encrypted = CryptoUtils.encryptData(utf8.decode(compressed), psk);
      client.write(utf8.encode(encrypted));

      // Log installation event
      await dbService.insertData('installation_logs', {
        'id': _uuid.v4(),
        'installer_id': learnerId,
        'recipient_id': parentId,
        'role': 'parent',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ip': client.address.address,
        'status': 'installed',
      });

      await dbService.cacheLearnerDevice(
          parentId, client.address.address, psk, 0);
    } else {
      client.write(utf8.encode(jsonEncode({'status': 'installed'})));
    }
  }

  Future<void> stopInstallServer() async {
    await _installServer?.close();
  }

  Future<void> stopLearnerInstallServer(HttpServer server) async {
    await server.close();
  }
}
