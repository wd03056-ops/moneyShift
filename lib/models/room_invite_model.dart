import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/firestore_paths.dart';
import '../core/deeplink/invite_link.dart';
import 'enums/member_role.dart';

/// `room_invites/{inviteId}` — 직책이 미리 지정된 초대
///
/// 사장이 초대 생성 전 [role]을 선택하면, 가입 시 해당 직책으로
/// `room_members`에 자동 등록됩니다.
class RoomInviteModel extends Equatable {
  const RoomInviteModel({
    required this.id,
    required this.roomId,
    required this.code,
    required this.role,
    required this.createdBy,
    this.customRoleName,
    this.customRoleId,
    this.isActive = true,
    this.usedCount = 0,
    this.maxUses,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String roomId;

  /// 공유용 초대 코드 (숫자 8자리 · 전역 유일)
  final String code;

  /// 권한용 직책 — 가입 시 `room_members.role` 에 적용
  final MemberRole role;

  /// 커스텀 직책 표시명 (있으면 UI는 이 이름 사용)
  final String? customRoleName;

  /// `rooms/{roomId}/custom_roles/{id}` 참조
  final String? customRoleId;

  final String createdBy;
  final bool isActive;
  final int usedCount;

  /// null이면 무제한
  final int? maxUses;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  /// UI 표시용 — 커스텀명 우선
  String get roleLabel {
    final custom = customRoleName?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return role.labelKo;
  }

  /// 공유용 HTTPS 앱링크 (미설치 시 웹→스토어, 설치 시 앱 실행)
  String get inviteLink => InviteLink.buildHttps(code);

  /// 하위 호환 커스텀 스킴
  String get inviteCustomSchemeLink => InviteLink.buildCustomScheme(code);

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get hasReachedMaxUses {
    if (maxUses == null) return false;
    return usedCount >= maxUses!;
  }

  bool get canBeUsed => isActive && !isExpired && !hasReachedMaxUses;

  String get docPath => FirestorePaths.roomInvite(id);

  factory RoomInviteModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RoomInviteModel.fromMap(data, id: doc.id);
  }

  factory RoomInviteModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return RoomInviteModel(
      id: id ?? map['id'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      code: map['code'] as String? ?? '',
      role: MemberRole.fromFirestore(map['role'] as String? ?? 'parttime'),
      createdBy: map['createdBy'] as String? ?? '',
      customRoleName: map['customRoleName'] as String?,
      customRoleId: map['customRoleId'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      usedCount: map['usedCount'] as int? ?? 0,
      maxUses: map['maxUses'] as int?,
      expiresAt: _toDateTime(map['expiresAt']),
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'roomId': roomId,
      'code': code,
      'role': role.firestoreValue,
      'createdBy': createdBy,
      if (customRoleName != null) 'customRoleName': customRoleName,
      if (customRoleId != null) 'customRoleId': customRoleId,
      'isActive': isActive,
      'usedCount': usedCount,
      if (maxUses != null) 'maxUses': maxUses,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  RoomInviteModel copyWith({
    String? id,
    String? roomId,
    String? code,
    MemberRole? role,
    String? createdBy,
    String? customRoleName,
    String? customRoleId,
    bool? isActive,
    int? usedCount,
    int? maxUses,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return RoomInviteModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      code: code ?? this.code,
      role: role ?? this.role,
      createdBy: createdBy ?? this.createdBy,
      customRoleName: customRoleName ?? this.customRoleName,
      customRoleId: customRoleId ?? this.customRoleId,
      isActive: isActive ?? this.isActive,
      usedCount: usedCount ?? this.usedCount,
      maxUses: maxUses ?? this.maxUses,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        code,
        role,
        customRoleName,
        customRoleId,
        createdBy,
        isActive,
        usedCount,
        maxUses,
        expiresAt,
        createdAt,
      ];
}
