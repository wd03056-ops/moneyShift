import '../models/monthly_labor_cost.dart';
import 'month_payroll_aggregator.dart';

/// 인건비 집계 단기 메모이제이션 — 동일 키면 재계산/불필요 반복 방지
class LaborCostMemo {
  LaborCostMemo._();

  static MonthlyLaborCost? _roomCost;
  static String? _roomKey;
  static List<WorkerLaborCostRow>? _rows;
  static String? _rowsKey;

  static void invalidate() {
    _roomCost = null;
    _roomKey = null;
    _rows = null;
    _rowsKey = null;
  }

  static MonthlyLaborCost room({
    required String key,
    required MonthlyLaborCost Function() compute,
  }) {
    if (_roomKey == key && _roomCost != null) return _roomCost!;
    final value = compute();
    _roomKey = key;
    _roomCost = value;
    return value;
  }

  static List<WorkerLaborCostRow> rows({
    required String key,
    required List<WorkerLaborCostRow> Function() compute,
  }) {
    if (_rowsKey == key && _rows != null) return _rows!;
    final value = compute();
    _rowsKey = key;
    _rows = value;
    return value;
  }
}
