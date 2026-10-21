import 'dart:convert';

import '../../models/enums/notification_type.dart';

/// 알림 딥링크 경로 상수 (FCM · NotificationModel 동기화)
abstract final class NotificationRoutes {
  NotificationRoutes._();

  static const employees = '/employees';
  static const schedule = '/schedule';
  /// 직원 — 근무 배정표(확인 대기) 화면
  static const assignedSchedule = '/assigned-schedule';
  static const scheduleChange = '/requests/schedule-change';
  static const substituteAccept = '/requests/substitute/accept';
  static const substituteApprove = '/requests/substitute/approve';
  static const commuteHistory = '/commute-history';
  static const myAttendance = '/my-attendance';
  static const noticeDetail = '/notices/detail';
  static const commuteCorrection = '/requests/commute-correction';
  static const inbox = '/notifications';
}

/// 해석된 딥링크 (경로 + params)
class NotificationDeepLink {
  const NotificationDeepLink({
    required this.targetRoute,
    this.params = const {},
  });

  /// 경로만. 예: `/schedule`, `/notices/detail`
  final String targetRoute;

  /// storeId, shiftId, requestId, noticeId, swapId …
  final Map<String, String> params;

  String? get storeId => _first(['storeId', 'roomId']);
  String? get requestId => _first(['requestId', 'id', 'swapId']);
  String? get shiftId => _first(['shiftId', 'scheduleId']);
  String? get noticeId => _first(['noticeId', 'id']);
  String? get swapId => _first(['swapId', 'requestId', 'id']);

  String? _first(List<String> keys) {
    for (final k in keys) {
      final v = params[k]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// 표시·로컬 푸시용 URI
  String get uriString {
    if (params.isEmpty) return targetRoute;
    final q = params.entries
        .where((e) => e.value.trim().isNotEmpty)
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return q.isEmpty ? targetRoute : '$targetRoute?$q';
  }

  /// FCM data 맵용 (중첩 불가 → params JSON + flatten)
  Map<String, String> toPayloadMap({String? type}) {
    return {
      if (type != null && type.isNotEmpty) 'type': type,
      'targetRoute': targetRoute,
      'params': jsonEncode(params),
      ...params,
    };
  }

  static String routeForType(NotificationType type) {
    switch (type) {
      case NotificationType.register:
        return NotificationRoutes.employees;
      case NotificationType.assign:
        return NotificationRoutes.assignedSchedule;
      case NotificationType.scheduleConfirmed:
        return NotificationRoutes.schedule;
      case NotificationType.requestUpdate:
        return NotificationRoutes.scheduleChange;
      case NotificationType.resultUpdate:
        return NotificationRoutes.schedule;
      case NotificationType.subRequest:
        return NotificationRoutes.substituteAccept;
      case NotificationType.subAccept:
        return NotificationRoutes.substituteApprove;
      case NotificationType.subConfirm:
        return NotificationRoutes.schedule;
      case NotificationType.commute:
        return NotificationRoutes.commuteHistory;
      case NotificationType.absent:
        return NotificationRoutes.myAttendance;
      case NotificationType.notice:
        return NotificationRoutes.noticeDetail;
      case NotificationType.commuteCorrection:
        return NotificationRoutes.commuteCorrection;
      case NotificationType.commuteCorrectionResult:
        return NotificationRoutes.commuteHistory;
      case NotificationType.generic:
        return NotificationRoutes.inbox;
    }
  }

  static Map<String, String> buildParams({
    required NotificationType type,
    required String storeId,
    Map<String, String> data = const {},
  }) {
    final out = <String, String>{};
    void put(String key, String? value) {
      final v = value?.trim();
      if (v != null && v.isNotEmpty) out[key] = v;
    }

    put('storeId', storeId.isNotEmpty ? storeId : data['storeId']);
    put('storeId', out['storeId'] ?? data['roomId']);

    final scheduleId = data['scheduleId'] ?? data['shiftId'];
    put('scheduleId', scheduleId);
    put('shiftId', data['shiftId'] ?? scheduleId);

    final requestId =
        data['requestId'] ?? data['swapId'] ?? data['id'] ?? scheduleId;
    put('requestId', requestId);
    put('swapId', data['swapId'] ?? data['requestId']);
    put('noticeId', data['noticeId']);
    put('action', data['action']);
    put('approved', data['approved']);
    put(
      'requestId',
      data['requestId'] ?? data['correctionId'] ?? out['requestId'],
    );

    switch (type) {
      case NotificationType.requestUpdate:
      case NotificationType.subRequest:
      case NotificationType.subAccept:
      case NotificationType.commuteCorrection:
        put('id', requestId ?? data['correctionId']);
        break;
      case NotificationType.notice:
        put('id', data['noticeId']);
        break;
      case NotificationType.assign:
      case NotificationType.scheduleConfirmed:
      case NotificationType.resultUpdate:
      case NotificationType.subConfirm:
      case NotificationType.absent:
        put('id', scheduleId ?? requestId);
        break;
      case NotificationType.register:
      case NotificationType.commute:
      case NotificationType.commuteCorrectionResult:
      case NotificationType.generic:
        break;
    }

    return out;
  }

  static NotificationDeepLink fromType({
    required NotificationType type,
    required String storeId,
    Map<String, String> data = const {},
    String? targetRouteOverride,
  }) {
    final route = (targetRouteOverride != null &&
            targetRouteOverride.trim().isNotEmpty)
        ? pathOnly(targetRouteOverride)
        : routeForType(type);
    return NotificationDeepLink(
      targetRoute: route,
      params: buildParams(type: type, storeId: storeId, data: data),
    );
  }

  /// FCM / NotificationModel / 로컬 페이로드에서 복원
  static NotificationDeepLink parse({
    String? targetRoute,
    Map<String, String>? params,
    NotificationType? type,
    String storeId = '',
    Map<String, String> data = const {},
  }) {
    final merged = <String, String>{...data, ...?params};
    if (storeId.isNotEmpty) merged.putIfAbsent('storeId', () => storeId);

    final rawParamsJson = data['params'] ?? merged['params'];
    if (rawParamsJson != null && rawParamsJson.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(rawParamsJson);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            merged[e.key.toString()] = '${e.value}';
          }
        }
      } catch (_) {}
    }

    final routeRaw = (targetRoute != null && targetRoute.trim().isNotEmpty)
        ? targetRoute
        : (merged['targetRoute'] ?? '');

    if (routeRaw.isNotEmpty) {
      final uri = Uri.tryParse(
        routeRaw.startsWith('/') ? 'app://local$routeRaw' : routeRaw,
      );
      if (uri != null) {
        final path = uri.path.isNotEmpty ? uri.path : pathOnly(routeRaw);
        final q = <String, String>{
          ...merged,
          ...uri.queryParameters,
        };
        q.remove('targetRoute');
        q.remove('params');
        return NotificationDeepLink(targetRoute: path, params: q);
      }
    }

    final resolvedType =
        type ?? NotificationType.fromFirestore(merged['type']);
    return fromType(
      type: resolvedType,
      storeId: storeId.isNotEmpty ? storeId : (merged['storeId'] ?? ''),
      data: merged,
    );
  }

  static String pathOnly(String raw) {
    final i = raw.indexOf('?');
    return (i < 0 ? raw : raw.substring(0, i)).trim();
  }

  /// 역할에 따른 RoomDetail 탭 인덱스 (없으면 null → 기본 탭)
  static int? tabIndexFor({
    required String targetRoute,
    required bool isOwner,
  }) {
    switch (pathOnly(targetRoute)) {
      case NotificationRoutes.employees:
        return isOwner ? 0 : 0;
      case NotificationRoutes.schedule:
        return isOwner ? 1 : 1;
      case NotificationRoutes.assignedSchedule:
        return isOwner ? 1 : 0;
      case NotificationRoutes.scheduleChange:
        return isOwner ? 1 : 1;
      case NotificationRoutes.substituteAccept:
        return isOwner ? 1 : 0;
      case NotificationRoutes.substituteApprove:
        return isOwner ? 1 : 1;
      case NotificationRoutes.commuteHistory:
        // 사장은 전용 OwnerCommuteDashboardScreen 으로 푸시 (탭 인덱스 미사용)
        return isOwner ? null : 0;
      case NotificationRoutes.myAttendance:
        return isOwner ? 1 : 0;
      case NotificationRoutes.commuteCorrection:
        return isOwner ? null : 0;
      default:
        return null;
    }
  }
}
