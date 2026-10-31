class AttendanceModel {
  final String id;
  final String userId;
  final String userName;
  final String date;
  final String scheduledIn;
  final String? clockIn;
  final String? clockOut;
  final int latenessMinutes;
  final String status; // 'HADIR', 'TERLAMBAT', 'PULANG_CEPAT', 'IZIN', 'ALPA'
  final String? notes;
  final String? photoPath;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.date,
    this.scheduledIn = '08:00',
    this.clockIn,
    this.clockOut,
    this.latenessMinutes = 0,
    this.status = 'HADIR',
    this.notes,
    this.photoPath,
  });

  bool get isClockedIn => clockIn != null;
  bool get isClockedOut => clockOut != null;
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      date: map['date'] as String,
      scheduledIn: map['scheduled_in'] as String? ?? '08:00',
      clockIn: map['clock_in'] as String?,
      clockOut: map['clock_out'] as String?,
      latenessMinutes: map['lateness_minutes'] as int? ?? 0,
      status: map['status'] as String? ?? 'HADIR',
      notes: map['notes'] as String?,
      photoPath: map['photo_path'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'date': date,
      'scheduled_in': scheduledIn,
      'clock_in': clockIn,
      'clock_out': clockOut,
      'lateness_minutes': latenessMinutes,
      'status': status,
      'notes': notes,
      'photo_path': photoPath,
    };
  }
}
