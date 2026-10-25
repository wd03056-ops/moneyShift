import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/room_exceptions.dart';
import '../../../core/permissions/location_disclosure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/async_action_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_select_chip.dart';
import '../../../core/widgets/app_text_input_defaults.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../services/kakao_local_api.dart';
import '../widgets/premium_room_limit_dialog.dart';
import 'widgets/daum_postcode_sheet.dart';

/// 방 만들기 — 순백 배경 + Primary Blue CTA
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  /// 검색 버튼·입력 카드 공통 높이
  static const double _controlHeight = 52;

  static const _radii = [50.0, 100.0, 150.0, 200.0];

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _kakaoApi = KakaoLocalApi();
  final _submitGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 600),
  );
  final _postcodeGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 500),
  );

  double? _latitude;
  double? _longitude;
  String? _selectedAddress;
  String? _selectedPlaceName;
  bool _loadingGps = false;
  bool _resolvingPostcode = false;
  bool _submitting = false; // 연타 시 중복 생성 요청 차단
  String? _searchError;
  double _geofenceRadius =
      AppConstants.attendanceGeofenceRadiusMeters;

  /// 래퍼가 테두리·그림자를 담당 → 버튼 자체 보더는 없음
  ButtonStyle get _flatButtonStyle => ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
        elevation: const WidgetStatePropertyAll(0),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(BorderSide.none),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, _controlHeight)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  /// floating label 대신 hint만 — 높이 팽창 방지
  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF8B95A1),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      filled: false,
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _shadowButton({
    required VoidCallback? onPressed,
    required Widget child,
    double? width,
  }) {
    return SizedBox(
      height: _controlHeight,
      width: width,
      child: DecoratedBox(
        decoration: AppDecorations.borderedSurface(radius: 12),
        child: OutlinedButton(
          style: _flatButtonStyle,
          onPressed: onPressed,
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _kakaoApi.dispose();
    super.dispose();
  }

  int get _ownedCount {
    final uid = MockSession.instance.currentUser?.uid;
    if (uid == null) return 0;
    return MockStore.instance.rooms.values.where((r) => r.ownerId == uid).length;
  }

  Future<void> _openPostcodeSearch() async {
    await _postcodeGuard.run(() async {
      final result = await showDaumPostcodeSheet(context);
      if (!mounted || result == null) return;
      await _applyPostcodeResult(result);
    });
  }

  Future<void> _applyPostcodeResult(DaumPostcodeResult result) async {
    setState(() {
      _resolvingPostcode = true;
      _searchError = null;
      _selectedAddress = result.baseAddress;
      _selectedPlaceName = result.buildingName;
      _addressController.text = result.displayLabel;
    });

    try {
      // 검색 결과에 좌표가 있으면 재조회 생략
      final lat = result.latitude;
      final lng = result.longitude;
      if (lat != null && lng != null) {
        if (!mounted) return;
        setState(() {
          _latitude = lat;
          _longitude = lng;
          _searchError = null;
        });
        return;
      }

      final place = await _geocodeQuery(result.geocodeQuery);
      if (!mounted) return;
      if (place == null) {
        setState(() {
          _latitude = null;
          _longitude = null;
          _searchError = '선택한 주소의 좌표를 찾지 못했습니다. 다시 검색해 주세요.';
        });
        return;
      }
      setState(() {
        _latitude = place.latitude;
        _longitude = place.longitude;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _latitude = null;
        _longitude = null;
        _searchError = '좌표 변환 실패: $e';
      });
    } finally {
      if (mounted) setState(() => _resolvingPostcode = false);
    }
  }

  Future<KakaoPlaceResult?> _geocodeQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    var results = await _kakaoApi.searchAddress(trimmed);
    if (results.isEmpty) {
      results = await _kakaoApi.searchKeyword(trimmed);
    }
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<void> _useCurrentLocation() async {
    final disclosed = await LocationDisclosure.ensureAccepted(context);
    if (!disclosed || !mounted) return;

    setState(() {
      _loadingGps = true;
      _searchError = null;
    });

    try {
      final position = await _resolveCurrentPosition();
      final reverse = await _kakaoApi.coordToAddress(
        longitude: position.longitude,
        latitude: position.latitude,
      );

      if (!mounted) return;

      if (reverse == null ||
          (reverse.address.isEmpty &&
              (reverse.roadAddress?.isEmpty ?? true))) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _selectedAddress = '현재 위치 (주소 미확인)';
          _selectedPlaceName = '현재 위치';
          _addressController.text = '현재 위치';
          _searchError = '주소 변환 결과가 없습니다. 주소 검색으로 선택해 주세요.';
        });
        return;
      }

      // 좌표→주소는 지번이 자주 나옴 → 주소 검색과 같은 API로 도로명 정규화
      final place = await _normalizeLikeAddressSearch(
            reverse,
            latitude: position.latitude,
            longitude: position.longitude,
          ) ??
          reverse;

      if (!mounted) return;

      // 표시 포맷은 주소 검색과 동일 (도로명 우선, 우편번호·건물명 제외)
      // 출퇴근 좌표는 실제 GPS 위치 유지
      final mapped = DaumPostcodeResult.fromKakao(place);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _selectedAddress = mapped.baseAddress;
        _selectedPlaceName = mapped.buildingName;
        _addressController.text = mapped.displayLabel;
        _searchError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현재 위치 주소를 불러왔습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('현재 위치 가져오기 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  /// GPS 역지오코딩 결과를 주소 검색과 같은 도로명 표기로 맞춤
  Future<KakaoPlaceResult?> _normalizeLikeAddressSearch(
    KakaoPlaceResult reverse, {
    required double latitude,
    required double longitude,
  }) async {
    final road = reverse.roadAddress?.trim() ?? '';
    final jibun = reverse.address.trim();

    // 1) 도로명이 있으면 그걸로 주소 검색 (검색 UX와 동일)
    if (road.isNotEmpty) {
      final byRoad = await _geocodeQuery(road);
      if (byRoad != null) return byRoad;
    }

    // 2) 지번으로 검색 후 GPS에 가장 가까운 후보 선택
    if (jibun.isNotEmpty) {
      final byJibun = await _closestGeocode(
        query: jibun,
        latitude: latitude,
        longitude: longitude,
      );
      if (byJibun != null) {
        // 후보에 도로명이 있으면 그걸 우선
        final candidateRoad = byJibun.roadAddress?.trim() ?? '';
        if (candidateRoad.isNotEmpty) return byJibun;
        if (road.isNotEmpty) {
          return KakaoPlaceResult(
            address: byJibun.address,
            roadAddress: road,
            placeName: byJibun.placeName,
            buildingName: byJibun.buildingName ?? reverse.buildingName,
            zonecode: byJibun.zonecode ?? reverse.zonecode,
            latitude: byJibun.latitude,
            longitude: byJibun.longitude,
          );
        }
        return byJibun;
      }
    }

    // 3) 역지오코딩에 도로명만 있는 경우 그대로 (도로명 우선)
    if (road.isNotEmpty) return reverse;
    return null;
  }

  Future<KakaoPlaceResult?> _closestGeocode({
    required String query,
    required double latitude,
    required double longitude,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    var results = await _kakaoApi.searchAddress(trimmed);
    if (results.isEmpty) {
      results = await _kakaoApi.searchKeyword(trimmed);
    }
    if (results.isEmpty) return null;

    KakaoPlaceResult? best;
    var bestMeters = double.infinity;
    for (final r in results) {
      final d = Geolocator.distanceBetween(
        latitude,
        longitude,
        r.latitude,
        r.longitude,
      );
      if (d < bestMeters) {
        bestMeters = d;
        best = r;
      }
    }
    return best;
  }

  Future<Position> _resolveCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('기기 위치 서비스가 꺼져 있습니다. 설정에서 위치를 켜주세요.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('위치 권한이 거부되었습니다.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        '위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 위치 권한을 허용해주세요.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      throw Exception('위치 확인 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  String? get _addressForRoom {
    final fromField = _addressController.text.trim();
    if (fromField.isNotEmpty) return fromField;
    final title = _selectedPlaceName?.trim();
    final addr = _selectedAddress?.trim() ?? '';
    if (title != null && title.isNotEmpty) {
      if (addr.isEmpty || addr == title) return title;
      return '$addr ($title)';
    }
    return addr.isNotEmpty ? addr : null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주소 검색 또는 현재 위치로 매장 위치를 선택해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _submitGuard.run(() async {
      if (!mounted) return;
      setState(() => _submitting = true);
      try {
        final room = MockStore.instance.createRoom(
          name: _nameController.text,
          latitude: _latitude!,
          longitude: _longitude!,
          address: _addressForRoom,
          geofenceRadiusMeters: _geofenceRadius,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${room.name}」 방이 생성되었습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(room);
      } on RoomLimitExceededException catch (e) {
        if (!mounted) return;
        PremiumRoomLimitDialog.show(context, exception: e);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('방 생성 실패: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loadingGps || _resolvingPostcode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('방 만들기'),
      ),
      body: ColoredBox(
        color: Colors.white,
        child: Form(
          key: _formKey,
          child: ScrollablePageBody(
            top: false,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '무료 플랜: 최대 ${AppConstants.freeMaxOwnedRooms}개 '
                  '(현재 $_ownedCount/${AppConstants.freeMaxOwnedRooms})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FormField<String>(
                  validator: (_) {
                    final v = _nameController.text;
                    return (v.trim().isEmpty) ? '매장 이름을 입력하세요' : null;
                  },
                  builder: (field) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppBorderedField(
                          height: _controlHeight,
                          child: Center(
                            child: TextField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.none,
                              keyboardType: TextInputType.text,
                              autocorrect: AppTextInputDefaults.autocorrect,
                              enableSuggestions:
                                  AppTextInputDefaults.enableSuggestions,
                              spellCheckConfiguration:
                                  AppTextInputDefaults.spellCheckConfiguration,
                              smartDashesType:
                                  AppTextInputDefaults.smartDashesType,
                              smartQuotesType:
                                  AppTextInputDefaults.smartQuotesType,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF191F28),
                                decoration: TextDecoration.none,
                              ),
                              decoration: _fieldDecoration('매장 이름'),
                              onChanged: (value) {
                                // 한글 조합 중 FormField 리빌드 금지
                                if (AppTextInputDefaults.isComposing(
                                  _nameController,
                                )) {
                                  return;
                                }
                                field.didChange(value);
                                if (field.hasError) field.validate();
                              },
                            ),
                          ),
                        ),
                        if (field.hasError && field.errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              field.errorText!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  '매장 주소',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '주소 검색으로 기본 주소(도로명·지번)만 등록합니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                AppBorderedField(
                  height: _controlHeight,
                  child: Center(
                    child: TextField(
                      controller: _addressController,
                      readOnly: true,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191F28),
                        decoration: TextDecoration.none,
                      ),
                      decoration: _fieldDecoration('주소를 검색해 선택하세요'),
                      onTap: busy || _submitting ? null : _openPostcodeSearch,
                    ),
                  ),
                ),
                if (_searchError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      _searchError!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _shadowButton(
                        onPressed:
                            busy || _submitting ? null : _openPostcodeSearch,
                        child: _resolvingPostcode
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Text('주소 검색'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _shadowButton(
                        onPressed:
                            busy || _submitting ? null : _useCurrentLocation,
                        child: _loadingGps
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Text('현재 위치(GPS)'),
                      ),
                    ),
                  ],
                ),
                if (_latitude != null &&
                    _longitude != null &&
                    _addressController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SelectedAddressCard(
                    placeName: _selectedPlaceName,
                    address: _addressController.text.trim(),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  '출퇴근 허용 반경',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '직원이 이 반경 안에서만 출퇴근할 수 있어요.\n'
                  '허용 반경은 설정에서 변경할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final r in _radii) ...[
                      if (r != _radii.first) const SizedBox(width: 8),
                      Expanded(
                        child: AppSelectChip(
                          label: '${r.toStringAsFixed(0)}m',
                          selected: _geofenceRadius == r,
                          expand: true,
                          onTap: _submitting
                              ? null
                              : () => setState(() => _geofenceRadius = r),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                StickyActionButton(
                  label: '방 생성',
                  variant: StickyActionVariant.filled,
                  onPressed: _submitting || busy ? null : _submit,
                  isLoading: _submitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 선택된 위치 카드 — 장소명 + 도로명 (좌표 비표시)
class _SelectedAddressCard extends StatelessWidget {
  const _SelectedAddressCard({
    required this.placeName,
    required this.address,
  });

  final String? placeName;
  final String address;

  @override
  Widget build(BuildContext context) {
    final title = placeName?.trim();
    final hasTitle = title != null && title.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppDecorations.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Text(
                  '선택된 위치',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4E5968),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📍', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasTitle) ...[
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF191F28),
                                    letterSpacing: -0.3,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (address.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            address,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF8B95A1),
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ] else
                        Text(
                          address.trim().isNotEmpty
                              ? address
                              : '위치가 선택되었습니다',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF191F28),
                                  ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
