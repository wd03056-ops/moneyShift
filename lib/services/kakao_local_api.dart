import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/kakao_api_config.dart';

/// 카카오 로컬 API — 주소 검색 / 좌표↔주소 변환
class KakaoLocalApi {
  KakaoLocalApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 주소 → 좌표 (주소 검색)
  /// GET /v2/local/search/address.json
  Future<List<KakaoPlaceResult>> searchAddress(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(
      '${KakaoApiConfig.baseUrl}/v2/local/search/address.json',
    ).replace(queryParameters: {'query': trimmed});

    final response = await _client.get(
      uri,
      headers: KakaoApiConfig.authHeaders,
    );

    if (response.statusCode != 200) {
      throw KakaoApiException(
        '주소 검색 실패 (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = json['documents'] as List<dynamic>? ?? const [];
    return documents
        .map((e) => KakaoPlaceResult.fromAddressDocument(
              e as Map<String, dynamic>,
            ))
        .where((e) => e.latitude != 0 || e.longitude != 0)
        .toList();
  }

  /// 키워드(상호명 등) → 좌표
  /// GET /v2/local/search/keyword.json
  Future<List<KakaoPlaceResult>> searchKeyword(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(
      '${KakaoApiConfig.baseUrl}/v2/local/search/keyword.json',
    ).replace(queryParameters: {'query': trimmed});

    final response = await _client.get(
      uri,
      headers: KakaoApiConfig.authHeaders,
    );

    if (response.statusCode != 200) {
      throw KakaoApiException(
        '키워드 검색 실패 (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = json['documents'] as List<dynamic>? ?? const [];
    return documents
        .map((e) => KakaoPlaceResult.fromKeywordDocument(
              e as Map<String, dynamic>,
            ))
        .where((e) => e.latitude != 0 || e.longitude != 0)
        .toList();
  }

  /// 좌표 → 주소
  /// GET /v2/local/geo/coord2address.json
  Future<KakaoPlaceResult?> coordToAddress({
    required double longitude,
    required double latitude,
  }) async {
    final uri = Uri.parse(
      '${KakaoApiConfig.baseUrl}/v2/local/geo/coord2address.json',
    ).replace(queryParameters: {
      'x': longitude.toString(),
      'y': latitude.toString(),
    });

    final response = await _client.get(
      uri,
      headers: KakaoApiConfig.authHeaders,
    );

    if (response.statusCode != 200) {
      throw KakaoApiException(
        '좌표→주소 변환 실패 (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = json['documents'] as List<dynamic>? ?? const [];
    if (documents.isEmpty) return null;

    return KakaoPlaceResult.fromCoord2AddressDocument(
      documents.first as Map<String, dynamic>,
      longitude: longitude,
      latitude: latitude,
    );
  }

  void dispose() => _client.close();
}

class KakaoPlaceResult {
  const KakaoPlaceResult({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.roadAddress,
    this.placeName,
    this.buildingName,
  });

  final String address;
  final String? roadAddress;

  /// 키워드 검색 상호·장소명 (예: 시흥시청)
  final String? placeName;

  /// 도로명 주소의 건물명
  final String? buildingName;

  final double latitude;
  final double longitude;

  /// UI 강조 타이틀 — 장소명 > 건물명
  String? get titleName {
    final place = placeName?.trim();
    if (place != null && place.isNotEmpty) return place;
    final building = buildingName?.trim();
    if (building != null && building.isNotEmpty) return building;
    return null;
  }

  /// 도로명 우선 본문 주소
  String get primaryAddress {
    final road = roadAddress?.trim();
    if (road != null && road.isNotEmpty) return road;
    return address.trim();
  }

  /// Firestore/방 생성용 표시 문자열
  String get displayLabel {
    final title = titleName;
    final addr = primaryAddress;
    if (title != null && title.isNotEmpty) {
      if (addr.isEmpty || addr == title) return title;
      return '$title · $addr';
    }
    return addr;
  }

  factory KakaoPlaceResult.fromAddressDocument(Map<String, dynamic> doc) {
    final address = doc['address'] as Map<String, dynamic>?;
    final road = doc['road_address'] as Map<String, dynamic>?;
    final x = double.tryParse('${doc['x']}') ?? 0;
    final y = double.tryParse('${doc['y']}') ?? 0;
    final building = road?['building_name'] as String?;
    return KakaoPlaceResult(
      address: address?['address_name'] as String? ??
          doc['address_name'] as String? ??
          '',
      roadAddress: road?['address_name'] as String?,
      buildingName: (building != null && building.trim().isNotEmpty)
          ? building.trim()
          : null,
      latitude: y,
      longitude: x,
    );
  }

  factory KakaoPlaceResult.fromKeywordDocument(Map<String, dynamic> doc) {
    final x = double.tryParse('${doc['x']}') ?? 0;
    final y = double.tryParse('${doc['y']}') ?? 0;
    final place = doc['place_name'] as String?;
    return KakaoPlaceResult(
      address: doc['address_name'] as String? ?? '',
      roadAddress: doc['road_address_name'] as String?,
      placeName: (place != null && place.trim().isNotEmpty) ? place.trim() : null,
      latitude: y,
      longitude: x,
    );
  }

  factory KakaoPlaceResult.fromCoord2AddressDocument(
    Map<String, dynamic> doc, {
    required double longitude,
    required double latitude,
  }) {
    final address = doc['address'] as Map<String, dynamic>?;
    final road = doc['road_address'] as Map<String, dynamic>?;
    final building = road?['building_name'] as String?;
    return KakaoPlaceResult(
      address: address?['address_name'] as String? ?? '',
      roadAddress: road?['address_name'] as String?,
      buildingName: (building != null && building.trim().isNotEmpty)
          ? building.trim()
          : null,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class KakaoApiException implements Exception {
  KakaoApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
