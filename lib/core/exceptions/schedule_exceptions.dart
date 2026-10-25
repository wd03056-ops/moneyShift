class ScheduleNotFoundException implements Exception {
  const ScheduleNotFoundException([this.message = '근무 일정을 찾을 수 없습니다.']);
  final String message;

  @override
  String toString() => message;
}

class SchedulePermissionDeniedException implements Exception {
  const SchedulePermissionDeniedException([
    this.message = '이 일정을 변경할 권한이 없습니다.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class ScheduleChangeConflictException implements Exception {
  const ScheduleChangeConflictException([
    this.message = '이미 대기 중인 변경 요청이 있습니다.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class NoPendingChangeException implements Exception {
  const NoPendingChangeException([
    this.message = '확인할 변경 요청이 없습니다.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class InvalidScheduleTimeException implements Exception {
  const InvalidScheduleTimeException([
    this.message = '종료 시간은 시작 시간보다 이후여야 합니다.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class DuplicateScheduleException implements Exception {
  const DuplicateScheduleException([
    this.message = '중복된 근무배정입니다.',
  ]);
  final String message;

  @override
  String toString() => message;
}

/// 신규 배정 시 과거 날짜 차단
class PastDateAssignmentException implements Exception {
  const PastDateAssignmentException([
    this.message = '지나간 날짜에는 새 근무를 배정할 수 없습니다.',
  ]);
  final String message;

  @override
  String toString() => message;
}
