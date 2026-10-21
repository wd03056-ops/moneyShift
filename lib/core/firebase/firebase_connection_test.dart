import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_paths.dart';

/// 앱 기동 시 Firestore `connection_test` 에 임시 문서를 써 통신을 검증한다.
class FirebaseConnectionTest {
  FirebaseConnectionTest._();

  /// 성공 시 true. 실패해도 앱 실행은 막지 않는다.
  static Future<bool> run({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) async {
    if (!kDebugMode) return true;

    final projectId = Firebase.app().options.projectId;
    debugPrint('[Firebase][ConnectionTest] start projectId=$projectId');

    try {
      final firebaseAuth = auth ?? FirebaseAuth.instance;
      // Anonymous Auth 미설정(CONFIGURATION_NOT_FOUND)이어도 프로브는 계속
      try {
        if (firebaseAuth.currentUser == null) {
          debugPrint(
            '[Firebase][ConnectionTest] signing in anonymously for rules',
          );
          await firebaseAuth.signInAnonymously();
        }
      } catch (e) {
        debugPrint(
          '[Firebase][ConnectionTest] anon auth skipped: $e',
        );
      }
      debugPrint(
        '[Firebase][ConnectionTest] authUid=${firebaseAuth.currentUser?.uid}',
      );

      final db = firestore ?? FirebaseFirestore.instance;
      // test_ 접두사: Auth 없이도 Rules 에서 허용
      final ref =
          db.collection(FirestorePaths.connectionTest).doc('test_connection_probe');
      final payload = <String, dynamic>{
        'ok': true,
        'projectId': projectId,
        'platform': defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
        'clientAt': DateTime.now().toUtc().toIso8601String(),
        'message': 'Money Shift Firestore connection probe',
      };

      await ref.set(payload);
      final snap = await ref.get();
      if (!snap.exists) {
        debugPrint(
          '[Firebase][ConnectionTest] FAIL: write succeeded but read empty '
          'path=${ref.path}',
        );
        return false;
      }

      debugPrint(
        '[Firebase][ConnectionTest] OK path=${ref.path} '
        'data=${snap.data()}',
      );

      // 프로브 문서 정리 (실패해도 무시)
      try {
        await ref.delete();
        debugPrint('[Firebase][ConnectionTest] probe doc deleted');
      } catch (e) {
        debugPrint('[Firebase][ConnectionTest] probe delete skipped: $e');
      }
      return true;
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[Firebase][ConnectionTest] FAIL code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('[Firebase][ConnectionTest] stack: $st');
      return false;
    } catch (e, st) {
      debugPrint('[Firebase][ConnectionTest] FAIL error=$e');
      debugPrint('[Firebase][ConnectionTest] stack: $st');
      return false;
    }
  }
}
