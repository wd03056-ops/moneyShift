import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/firestore_paths.dart';
import '../core/navigation/notification_deep_link.dart';
import 'enums/notification_type.dart';

/// 인앱 알림 — `users/{userId}/notifications/{id}`
class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.storeId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.data = const {},
    this.targetRoute = '',
    this.params = const {},
  });

  final String id;

  /// 수신자 UID
  final String userId;

  /// 관련 매장/방 ID
  final String storeId;

  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  /// FCM/딥링크용 부가 필드 (scheduleId, swapId …)
  final Map<String, String> data;

  /// 클릭 시 이동 경로 (예: `/schedule`, `/notices/detail`)
  final String targetRoute;

  /// 경로 파라미터 (storeId, requestId, noticeId …)
  final Map<String, String> params;

  String get docPath => FirestorePaths.userNotification(userId, id);

  String get typeLabelKo => type.labelKo;

  /// 레거시 호환 alias
  String get recipientUid => userId;
  DateTime get timestamp => createdAt;

  /// 해석된 딥링크 (레거시 data 만 있어도 복원)
  NotificationDeepLink get deepLink => NotificationDeepLink.parse(
        targetRoute: targetRoute,
        params: params,
        type: type,
        storeId: storeId,
        data: data,
      );

  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? fallbackUserId,
  }) {
    return NotificationModel.fromMap(
      doc.data() ?? {},
      id: doc.id,
      fallbackUserId: fallbackUserId,
    );
  }

  factory NotificationModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
    String? fallbackUserId,
  }) {
    final rawData = map['data'];
    final data = <String, String>{};
    if (rawData is Map) {
      for (final e in rawData.entries) {
        data[e.key.toString()] = '${e.value}';
      }
    }

    final storeId = (map['storeId'] as String?)?.trim().isNotEmpty == true
        ? map['storeId'] as String
        : (data['storeId'] ?? '');

    final type = NotificationType.fromFirestore(map['type'] as String?);
    final params = _readParams(map, data);
    final targetRoute = _readTargetRoute(map, data, type, storeId, params);

    final readFlag = map['isRead'] ?? map['read'] ?? false;

    return NotificationModel(
      id: id ?? map['id'] as String? ?? '',
      userId: map['userId'] as String? ??
          map['recipientUid'] as String? ??
          fallbackUserId ??
          '',
      storeId: storeId,
      type: type,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isRead: readFlag == true,
      createdAt: _toDateTime(map['createdAt'] ?? map['timestamp']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      data: data,
      targetRoute: targetRoute,
      params: params,
    );
  }

  static Map<String, String> _readParams(
    Map<String, dynamic> map,
    Map<String, String> data,
  ) {
    final out = <String, String>{};

    void absorb(dynamic raw) {
      if (raw is Map) {
        for (final e in raw.entries) {
          final v = '${e.value}'.trim();
          if (v.isNotEmpty) out[e.key.toString()] = v;
        }
      } else if (raw is String && raw.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            for (final e in decoded.entries) {
              final v = '${e.value}'.trim();
              if (v.isNotEmpty) out[e.key.toString()] = v;
            }
          }
        } catch (_) {}
      }
    }

    absorb(map['params']);
    absorb(data['params']);
    // data 내 개별 키도 params 로 승격
    for (final k in [
      'storeId',
      'scheduleId',
      'shiftId',
      'requestId',
      'swapId',
      'noticeId',
      'id',
      'action',
      'approved',
    ]) {
      final v = data[k] ?? map[k]?.toString();
      if (v != null && v.trim().isNotEmpty) out.putIfAbsent(k, () => v.trim());
    }
    return out;
  }

  static String _readTargetRoute(
    Map<String, dynamic> map,
    Map<String, String> data,
    NotificationType type,
    String storeId,
    Map<String, String> params,
  ) {
    final raw = (map['targetRoute'] as String?)?.trim().isNotEmpty == true
        ? map['targetRoute'] as String
        : (data['targetRoute'] ?? '');
    if (raw.trim().isNotEmpty) {
      return NotificationDeepLink.pathOnly(raw);
    }
    return NotificationDeepLink.fromType(
      type: type,
      storeId: storeId,
      data: {...data, ...params},
    ).targetRoute;
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    final link = deepLink;
    final payload = link.toPayloadMap(type: type.firestoreValue);
    return {
      'id': id,
      'userId': userId,
      'recipientUid': userId,
      'storeId': storeId,
      'type': type.firestoreValue,
      'title': title,
      'body': body,
      'isRead': isRead,
      'read': isRead,
      'targetRoute': link.targetRoute,
      'params': link.params,
      'data': {
        ...data,
        ...payload,
        if (storeId.isNotEmpty) 'storeId': storeId,
        'type': type.firestoreValue,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) ...{
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      },
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? storeId,
    NotificationType? type,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
    Map<String, String>? data,
    String? targetRoute,
    Map<String, String>? params,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
      targetRoute: targetRoute ?? this.targetRoute,
      params: params ?? this.params,
    );
  }

  /// 생성 시 targetRoute/params 를 type·data 에서 채움
  factory NotificationModel.withDeepLink({
    required String id,
    required String userId,
    required String storeId,
    required NotificationType type,
    required String title,
    required String body,
    required bool isRead,
    required DateTime createdAt,
    Map<String, String> data = const {},
    String? targetRoute,
    Map<String, String>? params,
  }) {
    final link = NotificationDeepLink.fromType(
      type: type,
      storeId: storeId,
      data: data,
      targetRouteOverride: targetRoute,
    );
    final mergedParams = {...link.params, ...?params};
    final route = (targetRoute != null && targetRoute.trim().isNotEmpty)
        ? NotificationDeepLink.pathOnly(targetRoute)
        : link.targetRoute;
    return NotificationModel(
      id: id,
      userId: userId,
      storeId: storeId,
      type: type,
      title: title,
      body: body,
      isRead: isRead,
      createdAt: createdAt,
      data: {
        ...data,
        ...NotificationDeepLink(targetRoute: route, params: mergedParams)
            .toPayloadMap(type: type.firestoreValue),
      },
      targetRoute: route,
      params: mergedParams,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        storeId,
        type,
        title,
        body,
        isRead,
        createdAt,
        targetRoute,
      ];
}

/// UI/기존 코드 호환 — [NotificationModel] 별칭
typedef NotificationItem = NotificationModel;
