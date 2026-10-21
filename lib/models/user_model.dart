import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import 'enums/member_role.dart';

/// `users/{userId}` 문서
class UserModel extends Equatable {
  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.realName,
    this.phoneNumber,
    this.kakaoId,
    this.profileImageUrl,
    this.role = MemberRole.parttime,
    this.authProvider = 'anonymous',
    this.fcmToken,
    this.fcmTokens = const [],
    this.ownedRoomCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String email;
  final String displayName;

  /// 사용자가 온보딩에서 입력한 실명 (급여·근태용)
  final String? realName;

  final String? phoneNumber;

  /// 카카오 회원번호 (문자열)
  final String? kakaoId;

  final String? profileImageUrl;

  /// 기본 역할(사장/매니저/직원/알바) — 매장 멤버십과 별도 앱 전역 기본값
  final MemberRole role;

  /// `kakao` | `anonymous` | `mock` 등
  final String authProvider;

  /// 최신 디바이스 FCM 토큰 (푸시 조회용 단일 필드)
  final String? fcmToken;

  /// 멀티 디바이스 FCM 토큰
  final List<String> fcmTokens;

  /// 사장으로서 생성한 방 수 (무료 한도: [AppConstants.freeMaxOwnedRooms])
  final int ownedRoomCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canCreateMoreRooms =>
      ownedRoomCount < AppConstants.freeMaxOwnedRooms;

  /// 실명 온보딩 완료 여부 (공백 제외 2자 이상)
  bool get hasRealName {
    final name = realName?.trim() ?? '';
    return name.length >= 2;
  }

  /// UI 표시용 — 실명 우선, 없으면 닉네임
  String get preferredDisplayName {
    if (hasRealName) return realName!.trim();
    return displayName.trim().isNotEmpty ? displayName.trim() : '사용자';
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel.fromMap(data, uid: doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? uid}) {
    return UserModel(
      uid: uid ?? map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      realName: map['realName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      kakaoId: map['kakaoId'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      role: MemberRole.fromFirestore(
        map['role'] as String? ?? MemberRole.parttime.firestoreValue,
      ),
      authProvider: map['authProvider'] as String? ?? 'anonymous',
      fcmToken: map['fcmToken'] as String?,
      fcmTokens: List<String>.from(map['fcmTokens'] as List? ?? const []),
      ownedRoomCount: map['ownedRoomCount'] as int? ?? 0,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      if (realName != null) 'realName': realName,
      'phoneNumber': phoneNumber,
      'kakaoId': kakaoId,
      'profileImageUrl': profileImageUrl,
      'role': role.firestoreValue,
      'authProvider': authProvider,
      if (fcmToken != null) 'fcmToken': fcmToken,
      'fcmTokens': fcmTokens,
      'ownedRoomCount': ownedRoomCount,
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// 카카오/Mock 로그인 upsert 시 기존 필드를 덮어쓰지 않도록 merge 맵
  /// (realName 은 온보딩에서만 기록 — 여기서는 값이 있을 때만 merge)
  Map<String, dynamic> toKakaoUpsertMap({required bool isCreate}) {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      if (kakaoId != null) 'kakaoId': kakaoId,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      if (realName != null && realName!.trim().isNotEmpty)
        'realName': realName!.trim(),
      'authProvider': authProvider,
      'role': role.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isCreate) ...{
        'fcmTokens': fcmTokens,
        'ownedRoomCount': ownedRoomCount,
        'createdAt': FieldValue.serverTimestamp(),
      },
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? realName,
    String? phoneNumber,
    String? kakaoId,
    String? profileImageUrl,
    MemberRole? role,
    String? authProvider,
    String? fcmToken,
    List<String>? fcmTokens,
    int? ownedRoomCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      realName: realName ?? this.realName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      kakaoId: kakaoId ?? this.kakaoId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      authProvider: authProvider ?? this.authProvider,
      fcmToken: fcmToken ?? this.fcmToken,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      ownedRoomCount: ownedRoomCount ?? this.ownedRoomCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get docPath => FirestorePaths.user(uid);

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        realName,
        phoneNumber,
        kakaoId,
        profileImageUrl,
        role,
        authProvider,
        fcmToken,
        fcmTokens,
        ownedRoomCount,
        createdAt,
        updatedAt,
      ];
}
