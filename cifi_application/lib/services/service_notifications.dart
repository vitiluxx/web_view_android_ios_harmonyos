import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../configuration/parametres_application.dart';
import '../noyau/journal.dart';
import '../noyau/service.dart';

/// Point d'entree appele quand une notification push arrive alors que
/// l'application est fermee ou en arriere-plan.
/// Doit rester une fonction de premier niveau : exigence de Firebase.
@pragma('vm:entry-point')
Future<void> traiterMessageEnArrierePlan(RemoteMessage message) async {
  await Firebase.initializeApp();
  Journal.informer('message recu en arriere-plan : ${message.messageId}');
}

/// Notifications push (Firebase) et notifications locales.
///
/// Le service ne sait pas ce que l'interface fera d'un appui sur une
/// notification : il publie l'URL a ouvrir sur [urlDemandee].
class ServiceNotifications extends Service {
  ServiceNotifications(this._fonctionnalites, this._reglages);

  final Fonctionnalites _fonctionnalites;
  final ReglagesNotifications _reglages;

  final ValueNotifier<String?> urlDemandee = ValueNotifier<String?>(null);

  final FlutterLocalNotificationsPlugin _notificationsLocales =
      FlutterLocalNotificationsPlugin();

  bool _firebaseDisponible = false;
  int _compteurIdentifiant = 0;

  @override
  String get nom => 'notifications';

  @override
  bool get estActif => _fonctionnalites.notificationsPush;

  @override
  Future<void> demarrer() async {
    await _preparerNotificationsLocales();
    await _preparerFirebase();
  }

  // ------------------------------------------------------- notifications locales

  Future<void> _preparerNotificationsLocales() async {
    const AndroidInitializationSettings reglagesAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings reglagesApple =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // flutter_local_notifications 22 : les reglages passent par un
    // parametre nomme, et non plus en premiere position.
    await _notificationsLocales.initialize(
      settings: const InitializationSettings(
        android: reglagesAndroid,
        iOS: reglagesApple,
        macOS: reglagesApple,
      ),
      onDidReceiveNotificationResponse: _traiterAppui,
    );

    final AndroidFlutterLocalNotificationsPlugin? greffonAndroid =
        _notificationsLocales
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    if (greffonAndroid != null) {
      await greffonAndroid.createNotificationChannel(
        AndroidNotificationChannel(
          _reglages.canalIdentifiant,
          _reglages.canalLibelle,
          description: _reglages.canalDescription,
          importance: Importance.high,
        ),
      );
      await greffonAndroid.requestNotificationsPermission();
    }

    Journal.informer('notifications locales pretes');
  }

  /// Affiche immediatement une notification produite par l'application
  /// elle-meme (entree dans une zone, telechargement fini, etc.).
  Future<void> afficher({
    required String titre,
    required String corps,
    String? urlAssociee,
  }) async {
    _compteurIdentifiant = (_compteurIdentifiant + 1) % 100000;

    final AndroidNotificationDetails detailsAndroid =
        AndroidNotificationDetails(
      _reglages.canalIdentifiant,
      _reglages.canalLibelle,
      channelDescription: _reglages.canalDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(corps),
    );

    const DarwinNotificationDetails detailsApple = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Tous les parametres sont nommes depuis la version 22.
    await _notificationsLocales.show(
      id: _compteurIdentifiant,
      title: titre,
      body: corps,
      notificationDetails:
          NotificationDetails(android: detailsAndroid, iOS: detailsApple),
      payload: urlAssociee,
    );
  }

  void _traiterAppui(NotificationResponse reponse) {
    final String? charge = reponse.payload;
    if (charge != null && charge.isNotEmpty) {
      urlDemandee.value = charge;
    }
  }

  // ------------------------------------------------------- Firebase

  Future<void> _preparerFirebase() async {
    try {
      await Firebase.initializeApp();
      _firebaseDisponible = true;
    } catch (erreur) {
      Journal.alerter(
        'Firebase non configure : les push distants sont desactives. '
        'Lancez "flutterfire configure" (voir docs/05_fonctionnalites.md). '
        'Detail : $erreur',
      );
      return;
    }

    final FirebaseMessaging messagerie = FirebaseMessaging.instance;

    final NotificationSettings autorisation = await messagerie.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    Journal.informer('autorisation push : ${autorisation.authorizationStatus}');

    await messagerie.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(traiterMessageEnArrierePlan);
    FirebaseMessaging.onMessage.listen(_traiterMessagePremierPlan);
    FirebaseMessaging.onMessageOpenedApp.listen(_traiterOuvertureDepuisMessage);

    final RemoteMessage? messageInitial = await messagerie.getInitialMessage();
    if (messageInitial != null) {
      _traiterOuvertureDepuisMessage(messageInitial);
    }

    try {
      await messagerie.subscribeToTopic(_reglages.sujetDiffusion);
      Journal.informer('abonnement au sujet ${_reglages.sujetDiffusion}');
    } catch (erreur) {
      Journal.alerter('abonnement au sujet impossible : $erreur');
    }

    final String? jeton = await messagerie.getToken();
    Journal.deboguer('jeton push : ${jeton ?? "indisponible"}');
  }

  void _traiterMessagePremierPlan(RemoteMessage message) {
    final RemoteNotification? contenu = message.notification;
    if (contenu == null) {
      return;
    }
    afficher(
      titre: contenu.title ?? _reglages.canalLibelle,
      corps: contenu.body ?? '',
      urlAssociee: message.data['url'] as String?,
    );
  }

  void _traiterOuvertureDepuisMessage(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      urlDemandee.value = url;
    }
  }

  bool get firebaseDisponible => _firebaseDisponible;
}
