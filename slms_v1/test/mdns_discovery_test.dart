import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:school_app/services/database_service.dart';
import 'package:school_app/services/sync_service.dart';
import 'package:multicast_dns/multicast_dns.dart';

class MockDatabaseService extends Mock implements DatabaseService {}

class MockMDnsClient extends Mock implements MDnsClient {}

void main() {
  group('mDNS Discovery Tests', () {
    SyncService syncService;
    MockDatabaseService mockDbService;
    MockMDnsClient mockMdnsClient;

    setUp(() {
      mockDbService = MockDatabaseService();
      mockMdnsClient = MockMDnsClient();
      syncService = SyncService(mockDbService).._mdnsClient = mockMdnsClient;
    });

    test('Discover teacher with cached IP', () async {
      when(mockDbService.getTeacherDevice('teacher_1', 'class_1'))
          .thenAnswer((_) async => {
                'ip': '192.168.1.100',
                'port': 8080,
                'last_discovered': DateTime.now().millisecondsSinceEpoch,
              });

      final result = await syncService.discoverTeacher('teacher_1', 'class_1');
      expect(result['ip'], '192.168.1.100');
      expect(result['port'], 8080);
      verifyNever(mockMdnsClient.start());
    });

    test('Discover teacher via mDNS', () async {
      when(mockDbService.getTeacherDevice('teacher_1', 'class_1'))
          .thenAnswer((_) async => {});
      when(mockMdnsClient.start()).thenAnswer((_) async {});
      when(mockMdnsClient.lookup<PtrResourceRecord>(any))
          .thenAnswer((_) => Stream.fromIterable([
                PtrResourceRecord(
                    'Teacher_teacher_1.class_1._schoolapp._tcp.local', 3600,
                    domainName:
                        'Teacher_teacher_1.class_1._schoolapp._tcp.local'),
              ]));
      when(mockMdnsClient.lookup<SrvResourceRecord>(any))
          .thenAnswer((_) => Stream.fromIterable([
                SrvResourceRecord(
                    'Teacher_teacher_1.class_1._schoolapp._tcp.local', 3600,
                    port: 8080, target: '192.168.1.100.local'),
              ]));
      when(mockMdnsClient.lookup<TxtResourceRecord>(any))
          .thenAnswer((_) => Stream.fromIterable([
                TxtResourceRecord(
                    'Teacher_teacher_1.class_1._schoolapp._tcp.local', 3600,
                    text: 'teacherId=teacher_1,classId=class_1'),
              ]));
      when(mockMdnsClient.lookup<IPAddressResourceRecord>(any))
          .thenAnswer((_) => Stream.fromIterable([
                IPAddressResourceRecord('192.168.1.100.local', 3600,
                    address: InternetAddress('192.168.1.100')),
              ]));

      final result = await syncService.discoverTeacher('teacher_1', 'class_1');
      expect(result['ip'], '192.168.1.100');
      expect(result['port'], 8080);
      verify(mockDbService.cacheTeacherDevice(
              'teacher_1', 'class_1', '192.168.1.100', 8080))
          .called(1);
    });
  });
}
