import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/room_exceptions.dart';
import '../../../core/permissions/location_disclosure.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../services/kakao_local_api.dart';
import '../widgets/premium_room_limit_dialog.dart';

/// 방 만들기 — 순백 배경 + 차콜(#212529) 버튼 하드코딩
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  static const Color _charcoal = Color(0xFF212529);

  /// 검색 버튼·입력 카드 공통 높이
  static const double _controlHeight = 52;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _kakaoApi = KakaoLocalApi();

  double? _latitude;
  double? _longitude;
  String? _selectedAddress;
  String? _selectedPlaceName;
  List<KakaoPlaceResult> _searchResults = const [];
  bool _searching = false;
  bool _loadingGps = false;
  bool _submitting = false;
  String? _searchError;

  /// 래퍼가 테두리·그림자를 담당 → 버튼 자체 보더는 없음
  ButtonStyle get _flatButtonStyle => ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: const WidgetStatePropertyAll(_charcoal),
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

  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchError = '검색할 주소를 입력하세요.');
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _searchResults = const [];
    });

    try {
      var results = await _kakaoApi.searchAddress(query);
      if (results.isEmpty) {
        results = await _kakaoApi.searchKeyword(query);
      }
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        if (results.isEmpty) {
          _searchError = '검색 결과가 없습니다.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    final disclosed = await LocationDisclosure.ensureAccepted(context);
    if (!disclosed || !mounted) return;

    setState(() {
      _loadingGps = true;
      _searchError = null;
      _searchResults = const [];
    });

    try {
      final position = await _resolveCurrentPosition();
      final place = await _kakaoApi.coordToAddress(
        longitude: position.longitude,
        latitude: position.latitude,
      );

      if (!mounted) return;

      if (place == null ||
          (place.address.isEmpty && (place.roadAddress?.isEmpty ?? true))) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _selectedAddress = '현재 위치 (주소 미확인)';
          _selectedPlaceName = '현재 위치';
          _addressController.text = '현재 위치';
          _searchError = '주소 변환 결과가 없습니다. 검색으로 주소를 선택해 주세요.';
        });
        return;
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _selectedAddress = place.primaryAddress;
        _selectedPlaceName = place.titleName;
        _addressController.text = place.primaryAddress;
        _searchError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치 주소를 불러왔습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('현재 위치 가져오기 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
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

  void _selectPlace(KakaoPlaceResult place) {
    setState(() {
      _latitude = place.latitude;
      _longitude = place.longitude;
      _selectedAddress = place.primaryAddress;
      _selectedPlaceName = place.titleName;
      _addressController.text = place.primaryAddress;
      _searchResults = const [];
      _searchError = null;
    });
  }

  String? get _addressForRoom {
    final title = _selectedPlaceName?.trim();
    final addr = _selectedAddress?.trim() ?? '';
    if (title != null && title.isNotEmpty) {
      if (addr.isEmpty || addr == title) return title;
      return '$title · $addr';
    }
    return addr.isNotEmpty ? addr : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소 검색 또는 현재 위치로 매장 위치를 선택해주세요.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final room = MockStore.instance.createRoom(
        name: _nameController.text,
        latitude: _latitude!,
        longitude: _longitude!,
        address: _addressForRoom,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${room.name}」 방이 생성되었습니다.')),
      );
      Navigator.of(context).pop(room);
    } on RoomLimitExceededException catch (e) {
      PremiumRoomLimitDialog.show(context, exception: e);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('방 생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _searching || _loadingGps;

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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF191F28),
                              ),
                              decoration: _fieldDecoration('매장 이름'),
                              onChanged: (value) {
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
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AppBorderedField(
                        height: _controlHeight,
                        child: Center(
                          child: TextField(
                            controller: _addressController,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF191F28),
                            ),
                            decoration: _fieldDecoration('주소 또는 장소명'),
                            textInputAction: TextInputAction.search,
                            onSubmitted:
                                busy ? null : (_) => _searchAddress(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _shadowButton(
                      onPressed: busy ? null : _searchAddress,
                      child: _searching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _charcoal,
                              ),
                            )
                          : const Text('검색'),
                    ),
                  ],
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
                SizedBox(
                  width: double.infinity,
                  child: _shadowButton(
                    onPressed: busy ? null : _useCurrentLocation,
                    child: _loadingGps
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _charcoal,
                            ),
                          )
                        : const Text('현재 위치(GPS)'),
                  ),
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '검색 결과',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4E5968),
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._searchResults.map(
                    (place) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AddressResultCard(
                        place: place,
                        onTap: () => _selectPlace(place),
                      ),
                    ),
                  ),
                ],
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 16),
                  _SelectedAddressCard(
                    placeName: _selectedPlaceName,
                    address: _selectedAddress ?? '',
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _shadowButton(
                    onPressed: _submitting || busy ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _charcoal,
                            ),
                          )
                        : const Text('방 생성'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 검색 결과 카드 — 장소명 강조 + 도로명 (좌표 비표시)
class _AddressResultCard extends StatelessWidget {
  const _AddressResultCard({
    required this.place,
    required this.onTap,
  });

  final KakaoPlaceResult place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = place.titleName;
    final address = place.primaryAddress;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: AppDecorations.borderedSurface(radius: 14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 22,
                    color: Color(0xFF212529),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) ...[
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF191F28),
                                    letterSpacing: -0.2,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            address,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF8B95A1),
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ] else
                        Text(
                          address.isNotEmpty ? address : '주소 정보 없음',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF191F28),
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8B95A1),
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
      decoration: AppDecorations.borderedSurface(radius: 14).copyWith(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: const Color(0xFF212529), width: 1.2),
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
