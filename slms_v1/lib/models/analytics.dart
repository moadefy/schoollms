class Analytics {
  String? questionId;
  String? learnerId;
  int? timeSpentSeconds; // Time spent on the question in seconds
  String? submissionStatus; // e.g., 'submitted', 'draft', 'failed'
  String? deviceId; // Device identifier
  int? timestamp; // When the analytics data was recorded
  String? timetableId; // Added for traceability
  String? slotId; // Added for traceability
  int? install_count; // Number of installations facilitated by this user
  int? sync_count; // Number of syncs performed by this user

  Analytics({
    this.questionId,
    this.learnerId,
    this.timeSpentSeconds,
    this.submissionStatus,
    this.deviceId,
    this.timestamp,
    this.timetableId, // Added
    this.slotId, // Added
    this.install_count = 0, // Default to 0
    this.sync_count = 0, // Default to 0
  });

  factory Analytics.fromJson(Map<String, dynamic> json) {
    return Analytics(
      questionId: json['questionId'] as String?,
      learnerId: json['learnerId'] as String?,
      timeSpentSeconds: json['timeSpentSeconds'] as int?,
      submissionStatus: json['submissionStatus'] as String?,
      deviceId: json['deviceId'] as String?,
      timestamp: json['timestamp'] as int?,
      timetableId: json['timetableId'] as String?, // Added
      slotId: json['slotId'] as String?, // Added
      install_count: json['install_count'] as int? ?? 0, // Default to 0
      sync_count: json['sync_count'] as int? ?? 0, // Default to 0
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'learnerId': learnerId,
      'timeSpentSeconds': timeSpentSeconds,
      'submissionStatus': submissionStatus,
      'deviceId': deviceId,
      'timestamp': timestamp,
      'timetableId': timetableId, // Added
      'slotId': slotId, // Added
      'install_count': install_count,
      'sync_count': sync_count,
    };
  }
}
