import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_detail_screen.dart';
import 'package:skill_link/screens/splash_screen/splash_screen.dart';
import 'package:skill_link/screens/worker_screens/Chat/WorkerChatDetailScreen.dart';
import 'package:skill_link/screens/worker_screens/Map/worker_job_detail.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
  'chat_messages',
  'Chat Messages',
  description: 'Notifications for new chat messages',
  importance: Importance.high,
);

const AndroidNotificationChannel jobChannel = AndroidNotificationChannel(
  'job_alerts',
  'Job Alerts',
  description: 'Notifications for new and direct jobs',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint('Background notification received');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  @override
  void dispose() {
    _authSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    await _initializeLocalNotifications();
    await _initializeFirebaseNotifications();
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final String? payload = response.payload;

        if (payload == null || payload.isEmpty) return;

        try {
          final dynamic decodedPayload = jsonDecode(payload);

          if (decodedPayload is! Map) {
            debugPrint('Invalid notification payload: $decodedPayload');
            return;
          }

          final Map<String, dynamic> data = Map<String, dynamic>.from(
            decodedPayload,
          );

          await _handleNotificationData(data);
        } catch (error, stackTrace) {
          debugPrint('Notification payload error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      },
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(chatChannel);

    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(jobChannel);
  }

  Future<void> _initializeFirebaseNotifications() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    final NotificationSettings permissionSettings = await messaging
        .requestPermission(alert: true, badge: true, sound: true);

    debugPrint(
      'Notification permission: '
      '${permissionSettings.authorizationStatus}',
    );

    // Current logged-in user ke liye token save karega.
    final String? initialToken = await messaging.getToken();

    debugPrint('FCM Token: $initialToken');

    if (initialToken != null && initialToken.isNotEmpty) {
      await _saveTokenToFirestore(initialToken);
    }

    // Login ke baad dobara token save karega.
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) async {
      if (user == null) {
        debugPrint('No logged-in user for FCM token.');
        return;
      }

      try {
        final String? token = await messaging.getToken();

        if (token != null && token.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'fcmToken': token,
                'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          debugPrint('FCM token saved after login.');
        }
      } catch (error, stackTrace) {
        debugPrint('FCM token login save error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });

    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((
      String newToken,
    ) async {
      await _saveTokenToFirestore(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Foreground notification received');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');

      final RemoteNotification? notification = message.notification;

      if (notification == null) {
        debugPrint('Foreground message does not contain notification payload.');
        return;
      }

      final String type = message.data['type']?.toString() ?? '';

      final bool isJobNotification =
          type == 'job' ||
          type == 'direct_job' ||
          type == 'job_status' ||
          type == 'review';

      await localNotifications.show(
        id: message.hashCode,
        title:
            notification.title ??
            (isJobNotification ? 'Job update' : 'New message'),
        body:
            notification.body ??
            (isJobNotification
                ? 'Your job has been updated.'
                : 'You received a new message'),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            isJobNotification ? 'job_alerts' : 'chat_messages',
            isJobNotification ? 'Job Alerts' : 'Chat Messages',
            channelDescription: isJobNotification
                ? 'Notifications for jobs and job updates'
                : 'Notifications for new chat messages',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('Background notification tapped');
      debugPrint('Data: ${message.data}');

      await _handleNotificationTap(message);
    });

    final RemoteMessage? initialMessage = await messaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('App opened from terminated notification');
      debugPrint('Data: ${initialMessage.data}');

      await Future.delayed(const Duration(seconds: 2));
      await _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('FCM token not saved because user is not logged in.');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('FCM token saved successfully');
    } catch (error, stackTrace) {
      debugPrint('FCM token saving error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    await _handleNotificationData(message.data);
  }

  Future<void> _handleNotificationData(Map<String, dynamic> data) async {
    final String type = data['type']?.toString().trim() ?? '';

    if (type == 'chat') {
      await _openChatFromData(data);
      return;
    }

    if (type == 'job' || type == 'direct_job') {
      await _openJobFromData(data);
      return;
    }

    if (type == 'job_status') {
      debugPrint('Job status notification tapped: ${data['requestId']}');

      // Customer request detail screen navigation yahan add hogi.
      return;
    }

    if (type == 'review') {
      debugPrint('Review notification tapped: ${data['reviewId']}');

      // Worker reviews/profile screen navigation yahan add hogi.
      return;
    }

    debugPrint('Unsupported notification type: $type');
  }

  Future<void> _openJobFromData(Map<String, dynamic> data) async {
    final String requestId = data['requestId']?.toString().trim() ?? '';

    if (requestId.isEmpty) {
      debugPrint('Job requestId is missing: $data');
      return;
    }

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      await Future.delayed(const Duration(seconds: 2));
      currentUser = FirebaseAuth.instance.currentUser;
    }

    if (currentUser == null) {
      debugPrint('User is not logged in. Job cannot be opened.');
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> requestSnapshot =
          await FirebaseFirestore.instance
              .collection('requests')
              .doc(requestId)
              .get();

      if (!requestSnapshot.exists) {
        debugPrint('Job request not found: $requestId');
        return;
      }

      final Map<String, dynamic> requestData =
          requestSnapshot.data() ?? <String, dynamic>{};

      final String title =
          requestData['title']?.toString().trim() ?? 'Service request';
      final String category =
          requestData['category']?.toString().trim() ?? 'Service';
      final String location =
          requestData['location']?.toString().trim() ?? 'Location unavailable';
      final String urgency =
          requestData['urgency']?.toString().trim() ?? 'Normal';
      final String rawBudget =
          requestData['budget']?.toString().trim() ?? 'Not specified';
      final String distance =
          requestData['distance']?.toString().trim() ?? 'Nearby';

      final String budget = rawBudget.toLowerCase().startsWith('rs')
          ? rawBudget
          : 'Rs. $rawBudget';

      await _navigateWhenReady(
        WorkerJobDetailScreen(
          requestId: requestId,
          title: title,
          category: category,
          location: location,
          distance: distance,
          budget: budget,
          urgency: urgency,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Job navigation error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _openChatFromData(Map<String, dynamic> data) async {
    final String type = data['type']?.toString().trim() ?? '';

    final String chatId = data['chatId']?.toString().trim() ?? '';

    if (type != 'chat' || chatId.isEmpty) {
      debugPrint('Invalid chat notification data: $data');
      return;
    }

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      debugPrint('User is not logged in yet. Waiting for auth...');

      await Future.delayed(const Duration(seconds: 2));

      currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        debugPrint('User is still not logged in. Chat cannot be opened.');
        return;
      }
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> chatSnapshot =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();

      if (!chatSnapshot.exists) {
        debugPrint('Chat document not found: $chatId');
        return;
      }

      final Map<String, dynamic> chatData =
          chatSnapshot.data() ?? <String, dynamic>{};

      final String customerId = chatData['customerId']?.toString().trim() ?? '';

      final String workerId = chatData['workerId']?.toString().trim() ?? '';

      final String service =
          chatData['service']?.toString().trim() ??
          chatData['workerSkill']?.toString().trim() ??
          'Service';

      if (customerId.isEmpty || workerId.isEmpty) {
        debugPrint(
          'customerId or workerId is missing in chat document: $chatData',
        );
        return;
      }

      if (currentUser.uid == workerId) {
        await _openWorkerChat(
          chatId: chatId,
          customerId: customerId,
          service: service,
        );
        return;
      }

      if (currentUser.uid == customerId) {
        await _openCustomerChat(
          chatId: chatId,
          workerId: workerId,
          service: service,
        );
        return;
      }

      debugPrint(
        'Current user ${currentUser.uid} '
        'is not a participant of chat $chatId.',
      );
    } catch (error, stackTrace) {
      debugPrint('Chat navigation error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _openWorkerChat({
    required String chatId,
    required String customerId,
    required String service,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> customerSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();

    final Map<String, dynamic> customerData =
        customerSnapshot.data() ?? <String, dynamic>{};

    final String customerName =
        customerData['name']?.toString().trim() ??
        customerData['fullName']?.toString().trim() ??
        'Customer';

    await _navigateWhenReady(
      WorkerChatDetailScreen(
        chatId: chatId,
        customerId: customerId,
        customerName: customerName.isEmpty ? 'Customer' : customerName,
        service: service,
      ),
    );
  }

  Future<void> _openCustomerChat({
    required String chatId,
    required String workerId,
    required String service,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> workerSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(workerId)
            .get();

    final Map<String, dynamic> workerData =
        workerSnapshot.data() ?? <String, dynamic>{};

    final String workerName =
        workerData['name']?.toString().trim() ??
        workerData['fullName']?.toString().trim() ??
        'Worker';

    final String workerSkill =
        workerData['skill']?.toString().trim() ??
        workerData['service']?.toString().trim() ??
        workerData['category']?.toString().trim() ??
        service;

    final String? workerPhone =
        workerData['phone']?.toString().trim() ??
        workerData['phoneNumber']?.toString().trim();

    final String? workerImageUrl =
        workerData['profileImageUrl']?.toString().trim() ??
        workerData['photoUrl']?.toString().trim();

    await _navigateWhenReady(
      ChatDetailScreen(
        chatId: chatId,
        workerId: workerId,
        workerName: workerName.isEmpty ? 'Worker' : workerName,
        workerSkill: workerSkill.isEmpty ? service : workerSkill,
        workerPhone: workerPhone?.isEmpty == true ? null : workerPhone,
        workerImageUrl: workerImageUrl?.isEmpty == true ? null : workerImageUrl,
      ),
    );
  }

  Future<void> _navigateWhenReady(Widget screen) async {
    for (int attempt = 0; attempt < 15; attempt++) {
      final NavigatorState? navigator = navigatorKey.currentState;

      if (navigator != null && navigator.mounted) {
        await navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
        return;
      }

      await Future.delayed(const Duration(milliseconds: 400));
    }

    debugPrint('Navigator was not ready for notification navigation.');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'SkillLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: MyApp.analytics),
      ],
    );
  }
}
