import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:school_app/services/database_service.dart';
import 'package:school_app/services/sync_service.dart';
import 'package:school_app/utils/crypto_utils.dart';
import 'package:school_app/utils/queue_manager.dart';

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  group('SyncService Tests', () {
    SyncService syncService;
    MockDatabaseService mockDbService;

    setUp(() {
      mockDbService = MockDatabaseService();
      syncService = SyncService(mockDbService);
    });

    test('Encrypt and decrypt sync data', () {
      final data = jsonEncode({'test': 'value'});
      final psk = CryptoUtils.generatePSK('learner_1', 'teacher_1', 'class_1');
      final encrypted = CryptoUtils.encryptData(data, psk);
      final decrypted = CryptoUtils.decryptData(encrypted, psk);
      expect(decrypted, data);
    });

    test('Queue manager prioritizes pending changes', () {
      final queueManager = QueueManager(maxConnections: 2);
      queueManager.addLearner('learner_1', hasPendingChanges: true);
      queueManager.addLearner('learner_2', hasPendingChanges: false);
      expect(queueManager.getNextLearner(), 'learner_1');
      queueManager.addLearner('learner_2', hasPendingChanges: false);
      expect(queueManager.getNextLearner(), 'learner_2');
    });

    test('Queue manager enforces max connections', () {
      final queueManager = QueueManager(maxConnections: 1);
      queueManager.addLearner('learner_1');
      queueManager.addLearner('learner_2');
      expect(queueManager.canAcceptConnection(), false);
      queueManager.getNextLearner();
      expect(queueManager.canAcceptConnection(), true);
    });
  });
}
