class Analytics {
  String? questionId;
  String? learnerId;
  int? timeSpentSeconds; // Time spent on the question in seconds
  String? submissionStatus; // e.g., 'submitted', 'draft', 'failed'
  String? deviceId; // Device identifier
  int? timestamp; // When the analytics data was recorded
  String? timetableId; // Added for traceability
  String? slotId; // Added for traceability

  Analytics({
    this.questionId,
    this.learnerId,
    this.timeSpentSeconds,
    this.submissionStatus,
    this.deviceId,
    this.timestamp,
    this.timetableId, // Added
    this.slotId, // Added
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
    };
  }
}
