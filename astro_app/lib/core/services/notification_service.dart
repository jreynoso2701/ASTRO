import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:astro/core/constants/fcm_config.dart';

/// Servicio de Firebase Cloud Messaging.
///
/// Gestiona:
/// - Solicitar permiso de notificaciones.
/// - Obtener y refrescar FCM tokens.
/// - Guardar tokens en Firestore (`users/{uid}.fcmTokens`).
/// - Manejo de notificaciones en primer plano.
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Inicializa FCM: permiso + token + listener de refresh.
  ///
  /// Llama a este método después de que el usuario se autentique.
  Future<void> initialize(String uid) async {
    // 0. Crear canal de notificación en Android (requerido API 26+)
    if (!kIsWeb && Platform.isAndroid) {
      await _createAndroidChannel();
    }

    // 0b. En iOS, permitir que las notificaciones se muestren como banner
    // incluso cuando la app está en primer plano.
    if (!kIsWeb && Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // 1. Solicitar permiso (Android 13+ y web lo requieren)
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 2. Obtener token actual
    String? token;
    if (kIsWeb) {
      // Web necesita la VAPID key del proyecto Firebase.
      final vapid = fcmVapidKey.isNotEmpty && fcmVapidKey != 'PENDING_VAPID_KEY'
          ? fcmVapidKey
          : null;
      token = await _messaging.getToken(vapidKey: vapid);
    } else {
      token = await _messaging.getToken();
    }

    if (token != null) {
      await _saveToken(uid, token);
    }

    // 3. Escuchar refrescos del token
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(uid, newToken);
    });

    // 4. Configurar handler de mensajes en primer plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  /// Guarda el token en el array `fcmTokens` del usuario (sin duplicar).
  /// Usa set+merge para no fallar si el documento aún no existe (race
  /// condition durante el registro).
  Future<void> _saveToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  /// Remueve el token actual del usuario (al cerrar sesión).
  Future<void> removeToken(String uid) async {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    try {
      String? token;
      if (kIsWeb) {
        token = await _messaging.getToken(vapidKey: null);
      } else {
        token = await _messaging.getToken();
      }

      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (_) {
      // El documento puede haber sido eliminado (account deletion).
    }
  }

  /// Handler de mensajes recibidos en primer plano.
  /// Los push ya aparecen como notificación del SO en background/terminated.
  void _handleForegroundMessage(RemoteMessage message) {
    // En foreground, Firebase no muestra la notificación automáticamente.
    // Se puede usar flutter_local_notifications para mostrarla,
    // pero por ahora el inbox in-app captura todo vía Firestore.
    // Si en el futuro se quiere un banner overlay, se integra aquí.
  }

  /// Crea el canal de notificaciones en Android (API 26+).
  /// Debe coincidir con el `default_notification_channel_id` del AndroidManifest
  /// y el `channelId` enviado desde Cloud Functions.
  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      'astro_default',
      'Notificaciones ASTRO',
      description: 'Canal principal de notificaciones de ASTRO.',
      importance: Importance.high,
    );
    final flnPlugin = FlutterLocalNotificationsPlugin();
    await flnPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Libera recursos.
  void dispose() {
    _tokenRefreshSub?.cancel();
  }
}

/// Handler para mensajes en background/terminated.
/// Debe ser una función top-level (no un método de clase).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op por ahora. El inbox in-app se actualiza vía Firestore.
  // Este handler solo es necesario para que Firebase no lance excepciones.
}
