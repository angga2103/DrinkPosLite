class AuditLogModel {
  final String id;
  final String action;
  final String entityType;
  final String? entityId;
  final String? userId;
  final String? userName;
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final String createdAt;

  AuditLogModel({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    this.userId,
    this.userName,
    this.oldValue,
    this.newValue,
    this.reason,
    required this.createdAt,
  });

  factory AuditLogModel.fromMap(Map<String, dynamic> map) {
    return AuditLogModel(
      id: map['id'] as String,
      action: map['action'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String?,
      userId: map['user_id'] as String?,
      userName: map['user_name'] as String?,
      oldValue: map['old_value'] as String?,
      newValue: map['new_value'] as String?,
      reason: map['reason'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'user_id': userId,
      'user_name': userName,
      'old_value': oldValue,
      'new_value': newValue,
      'reason': reason,
      'created_at': createdAt,
    };
  }
}
