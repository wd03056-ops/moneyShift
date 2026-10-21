import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

/// Linux 전용 구현 스텁 (모바일 빌드에서는 사용되지 않음)
class GeolocatorLinux extends GeolocatorPlatform {
  static void registerWith() {}
}
