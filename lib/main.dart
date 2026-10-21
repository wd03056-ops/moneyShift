import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'core/config/dev_auth_config.dart';
import 'core/config/kakao_config.dart';
import 'core/deeplink/invite_deep_link_service.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/navigation/app_navigation.dart';
import 'core/navigation/app_navigator.dart';
import 'core/navigation/app_route_names.dart';
import 'core/security/secure_log.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/time/kst_date_time.dart';
import 'features/auth/data/auth_integration_service.dart';
import 'features/auth/data/kakao_auth_service.dart';
import 'features/auth/data/mock_auth_service.dart';
import 'features/auth/presentation/auth_home_gate.dart';
import 'features/rooms/presentation/join_room_screen.dart';
import 'mock/app_listenables.dart';
import 'mock/mock_session.dart';
import 'mock/mock_store.dart';
import 'features/notifications/data/notification_preference_store.dart';
import 'services/fcm_service.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DevAuthConfig.logStatus();

  await KakaoSdk.init(
    nativeAppKey: KakaoConfig.nativeAppKey,
  );
  if (kDebugMode) {
    await KakaoAuthService.printDebugKeyHash();
  }

  try {
    await FirebaseBootstrap.init(runConnectionTest: true);
  } catch (e, st) {
    SecureLog.d('[main] FirebaseBootstrap failed (app continues): $e');
    SecureLog.d('$st');
  }

  await Hive.initFlutter();
  await initializeDateFormatting('ko_KR');

  SecureLog.d('[KST] ${KstDateTime.debugSummary()}');

  MockStore.instance.ensureDemoWorkspace();
  await InviteDeepLinkService.instance.start();

  // 사용자별 푸시 수신 허용 설정 로드
  await NotificationPreferenceStore.instance.ensureLoaded();
  await LocalNotificationService.instance.init();

  // FCM 포그라운드/오픈 핸들러 (토큰 바인딩은 로그인 시 bindUser)
  await FcmService.instance.ensureHandlers();
  // 앱 시작 시 시스템 알림 권한 상태 확인 (강제 요청은 로그인/토글 시)
  if (FirebaseBootstrap.isInitialized) {
    final status = await FcmService.instance.checkPermissionStatus();
    SecureLog.d('[main] notification permission=$status');
  }

  // 개발용: Mock 인증이면 사장 UID 로 자동 로그인 + Firestore upsert/시드
  // (릴리즈에서는 DevAuthConfig.isMockAuthEnabled == false)
  if (DevAuthConfig.isMockAuthEnabled && DevAuthConfig.autoSignInOnLaunch) {
    try {
      final result = await AuthIntegrationService.instance.signIn(
        persona: MockAuthPersona.owner,
      );
      MockSession.instance.loginAs(result.mockUser);
      SecureLog.d(
        '[main] Mock auto-login OK uid=${result.mockUser.uid}',
      );
    } catch (e, st) {
      SecureLog.d('[main] Mock auto-login failed (앱은 로그인 화면으로): $e');
      SecureLog.d('$st');
    }
  }

  runApp(const MoneyShiftApp());
}

class MoneyShiftApp extends StatefulWidget {
  const MoneyShiftApp({super.key});

  @override
  State<MoneyShiftApp> createState() => _MoneyShiftAppState();
}

class _MoneyShiftAppState extends State<MoneyShiftApp> {
  static const Color _charcoal = Color(0xFF212529);
  static const Color _border = Color(0xFFE5E8EB);

  StreamSubscription<String>? _inviteSub;
  bool? _wasLoggedIn;
  bool _openingJoin = false;

  static ButtonStyle get _noFillButton => ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        foregroundColor: const WidgetStatePropertyAll(_charcoal),
        elevation: const WidgetStatePropertyAll(2),
        shadowColor: const WidgetStatePropertyAll(Color(0x14000000)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(
          BorderSide(color: _border, width: 1),
        ),
      );

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = MockSession.instance.isLoggedIn;
    _inviteSub =
        InviteDeepLinkService.instance.inviteCodes.listen(_onInviteCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (MockSession.instance.isLoggedIn) {
        _consumePendingInvite();
      }
    });
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
  }

  Future<void> _onInviteCode(String code) async {
    if (!MockSession.instance.isLoggedIn) return;
    await _openJoin(code);
  }

  Future<void> _consumePendingInvite() async {
    final code = await InviteDeepLinkService.instance.takePendingCode();
    if (code == null || !mounted) return;
    await _openJoin(code);
  }

  Future<void> _openJoin(String code) async {
    if (_openingJoin) return;
    _openingJoin = true;
    try {
      // 홈이 붙은 뒤 push
      await Future<void>.delayed(Duration.zero);
      final nav = appNavigatorKey.currentState;
      if (nav == null || !mounted) return;
      await AppNavigation.pushSingleTop(
        name: AppRouteNames.joinRoom,
        builder: (_) => JoinRoomScreen(initialCode: code),
      );
    } finally {
      _openingJoin = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppListenables.sessionAndStore,
      builder: (context, _) {
        final session = MockSession.instance;
        final loggedIn = session.isLoggedIn;
        final readyForHome = loggedIn && !session.needsProfileSetup;

        if (_wasLoggedIn == false && readyForHome) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _consumePendingInvite();
          });
        }
        _wasLoggedIn = readyForHome;

        final base = AppTheme.light;
        final theme = base.copyWith(
          scaffoldBackgroundColor: Colors.white,
          canvasColor: Colors.white,
          colorScheme: base.colorScheme.copyWith(
            primary: _charcoal,
            secondary: _charcoal,
            onPrimary: _charcoal,
            onSecondary: _charcoal,
            surface: Colors.white,
            surfaceTint: Colors.transparent,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(style: _noFillButton),
          filledButtonTheme: FilledButtonThemeData(style: _noFillButton),
          outlinedButtonTheme: OutlinedButtonThemeData(style: _noFillButton),
        );

        // MaterialApp 에 ValueKey 를 붙이지 않음 —
        // 로그인/로그아웃 시 전체 트리 dispose → _dependents 깨짐 방지.
        // 화면 분기는 AuthHomeGate 가 담당.
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Money Shift',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          theme: theme,
          locale: const Locale('ko', 'KR'),
          supportedLocales: const [
            Locale('ko', 'KR'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return ColoredBox(
              color: Colors.white,
              child: MediaQuery(
                data: media.copyWith(
                  textScaler: media.textScaler.clamp(
                    minScaleFactor: 0.9,
                    maxScaleFactor: 1.2,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const AuthHomeGate(),
        );
      },
    );
  }
}
