class PriorityQueueItem {
  final String learnerId;
  final int priority; // Higher priority for pending changes
  final int lastSyncTime; // For round-robin fairness

  PriorityQueueItem(this.learnerId, this.priority, this.lastSyncTime);
}

class QueueManager {
  List<PriorityQueueItem> _queue = [];
  final int maxConnections;

  QueueManager({this.maxConnections = 10});

  void addLearner(String learnerId, {bool hasPendingChanges = false}) {
    final priority = hasPendingChanges ? 1 : 0;
    if (!_queue.any((item) => item.learnerId == learnerId)) {
      _queue.add(PriorityQueueItem(learnerId, priority, DateTime.now().millisecondsSinceEpoch));
    }
  }

  String getNextLearner() {
    if (_queue.isEmpty) return null;
    _queue.sort((a, b) {
      if (a.priority != b.priority) return b.priority.compareTo(a.priority);
      return a.lastSyncTime.compareTo(b.lastSyncTime);
    });
    final learner = _queue.removeAt(0);
    return learner.learnerId;
  }

  bool canAcceptConnection() => _queue.length < maxConnections;

  void updateLastSyncTime(String learnerId) {
    final index = _queue.indexWhere((item) => item.learnerId == learnerId);
    if (index != -1) {
      _queue[index] = PriorityQueueItem(
        learnerId,
        _queue[index].priority,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }
}