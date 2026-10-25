import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_action_guard.dart';
import '../../../../services/kakao_local_api.dart';

/// 주소 검색 결과 — 기본 도로명/지번 + 우편번호만 (상세주소 없음)
class DaumPostcodeResult {
  const DaumPostcodeResult({
    required this.zonecode,
    required this.roadAddress,
    required this.jibunAddress,
    this.buildingName,
    this.sido,
    this.sigungu,
    this.latitude,
    this.longitude,
  });

  final String zonecode;
  final String roadAddress;
  final String jibunAddress;
  final String? buildingName;
  final String? sido;
  final String? sigungu;

  /// 카카오 검색에서 이미 받은 좌표 (있으면 재지오코딩 불필요)
  final double? latitude;
  final double? longitude;

  /// 도로명 우선, 없으면 지번
  String get baseAddress {
    final road = roadAddress.trim();
    if (road.isNotEmpty) return road;
    return jibunAddress.trim();
  }

  /// 메인 입력창용 — 도로명/지번만 (우편번호·건물명·상세주소 제외)
  String get displayLabel => baseAddress;

  /// 좌표 검색용 쿼리 (우편번호 제외)
  String get geocodeQuery {
    final base = baseAddress;
    return base.isNotEmpty ? base : zonecode;
  }

  factory DaumPostcodeResult.fromKakao(KakaoPlaceResult place) {
    final road = place.roadAddress?.trim() ?? '';
    final jibun = place.address.trim();
    final building = place.buildingName?.trim() ?? place.placeName?.trim();
    return DaumPostcodeResult(
      zonecode: place.zonecode?.trim() ?? '',
      roadAddress: road,
      jibunAddress: jibun,
      buildingName:
          (building != null && building.isNotEmpty) ? building : null,
      latitude: place.latitude,
      longitude: place.longitude,
    );
  }
}

/// 카카오 로컬 API 주소 검색 바텀시트
///
/// 입력 중에는 API를 호출하지 않고, [검색] 버튼·키보드 검색(엔터) 시에만 조회합니다.
Future<DaumPostcodeResult?> showDaumPostcodeSheet(BuildContext context) {
  return showModalBottomSheet<DaumPostcodeResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _KakaoAddressSearchSheet(),
  );
}

class _KakaoAddressSearchSheet extends StatefulWidget {
  const _KakaoAddressSearchSheet();

  @override
  State<_KakaoAddressSearchSheet> createState() =>
      _KakaoAddressSearchSheetState();
}

class _KakaoAddressSearchSheetState extends State<_KakaoAddressSearchSheet> {
  final _api = KakaoLocalApi();
  final _queryCtrl = TextEditingController();
  final _focus = FocusNode();
  final _searchGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 400),
  );

  bool _searching = false;
  bool _hasSearched = false;
  String? _error;
  List<KakaoPlaceResult> _results = const [];
  int _searchGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _focus.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _submitSearch() async {
    final q = _queryCtrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _hasSearched = false;
        _error = '주소를 2자 이상 입력해 주세요.';
      });
      return;
    }

    await _searchGuard.run(() async {
      final gen = ++_searchGen;
      FocusScope.of(context).unfocus();
      setState(() {
        _searching = true;
        _error = null;
        _hasSearched = true;
      });

      try {
        var list = await _api.searchAddress(q);
        if (list.isEmpty) {
          list = await _api.searchKeyword(q);
        }
        if (!mounted || gen != _searchGen) return;
        setState(() {
          _results = list;
          _searching = false;
          _error =
              list.isEmpty ? '검색 결과가 없습니다. 다른 키워드로 시도해 주세요.' : null;
        });
      } catch (_) {
        if (!mounted || gen != _searchGen) return;
        setState(() {
          _results = const [];
          _searching = false;
          _error = '주소 검색에 실패했습니다. 네트워크를 확인해 주세요.';
        });
      }
    });
  }

  void _select(KakaoPlaceResult place) {
    Navigator.of(context).pop(DaumPostcodeResult.fromKakao(place));
  }

  void _clearQuery() {
    _queryCtrl.clear();
    setState(() {
      _results = const [];
      _error = null;
      _hasSearched = false;
      _searching = false;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.85;
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '주소 검색',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '주소를 입력한 뒤 검색을 누르고, 목록에서 매장 주소를 선택하세요.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    // 한글 IME: suggestions/autocorrect 끄면 영문 고정되는 기기 있음
                    // TextField는 리빌드하지 않음 (조합 중 입력 끊김 방지)
                    child: TextField(
                      controller: _queryCtrl,
                      focusNode: _focus,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: true,
                      enableSuggestions: true,
                      onSubmitted: (_) => _submitSearch(),
                      decoration: InputDecoration(
                        hintText: '예: 강남대로 123, 시청',
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 22),
                        // 고정 폭 suffix — 나타날 때 폭 변해 IME가 리셋되지 않게
                        suffixIcon: ListenableBuilder(
                          listenable: _queryCtrl,
                          builder: (context, _) {
                            final empty = _queryCtrl.text.isEmpty;
                            return IgnorePointer(
                              ignoring: empty,
                              child: Opacity(
                                opacity: empty ? 0 : 1,
                                child: IconButton(
                                  tooltip: '지우기',
                                  onPressed:
                                      _searching ? null : _clearQuery,
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _searching ? null : _submitSearch,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.buttonFill,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: const StadiumBorder(),
                      ),
                      child: _searching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '검색',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildBody(textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_searching) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (_error != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: _error!.startsWith('검색 결과') ||
                      _error!.startsWith('주소를 2자')
                  ? AppColors.textSecondary
                  : AppColors.holiday,
            ),
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Text(
          '주소를 입력한 뒤 검색을 눌러 주세요',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final place = _results[index];
        final addr = place.primaryAddress;
        final title = place.titleName;
        final showSubtitle = title != null &&
            title.isNotEmpty &&
            addr.isNotEmpty &&
            title != addr;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          title: Text(
            addr.isNotEmpty ? addr : (title ?? ''),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: showSubtitle
              ? Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
          onTap: () => _select(place),
        );
      },
    );
  }
}
