import 'dart:async';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_tray/system_tray.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(900, 650);
    win.minSize = initialSize;
    win.maxSize = initialSize;
    win.alignment = Alignment.center;
    win.title = 'my timer';
    win.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Timer? _timer;
  late int _currentSeconds;
  bool isActive = false;
  int _currentCompleteCount = 0;
  late SharedPreferences prefs;
  int _notificationId = 1;

  static const int timerDefaultTime = 25 * 60;
  static const String completeCountKey = 'completeCount';

  final AppWindow _appWindow = AppWindow();
  final SystemTray _systemTray = SystemTray();
  final Menu _menuMain = Menu();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    initTimer();
    initSystemTray();
    initializeNotifications(_notificationsPlugin);
    requestPermissions(_notificationsPlugin);
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  void initTimer() async {
    // 初期時間
    _currentSeconds = timerDefaultTime;

    // 完了回数
    final p = await SharedPreferences.getInstance();
    prefs = p;
    final completeCount = prefs.getInt(completeCountKey) ?? 0;
    _currentCompleteCount = completeCount;
    setState(() {});
  }

  Future<void> initSystemTray() async {
    await _systemTray.initSystemTray(iconPath: 'assets/watanabe.jpeg');
    _systemTray.setTitle('25:00');

    _systemTray.registerSystemTrayEventHandler((eventName) {
      debugPrint('eventName: $eventName}');
      if (eventName == kSystemTrayEventClick) {
        _systemTray.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        _appWindow.show();
      }
    });
  }

  Future<void> initializeNotifications(
      FlutterLocalNotificationsPlugin plugin) async {
    const DarwinInitializationSettings initSettingsMacOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(macOS: initSettingsMacOS);
    await plugin.initialize(initializationSettings);
  }

  Future<void> requestPermissions(
      FlutterLocalNotificationsPlugin plugin) async {
    await plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: false,
          sound: false,
        );
  }

  void startTimer() async {
    setState(() {
      isActive = true;
    });

    await _notificationsPlugin.cancelAll();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) async {
        if (_currentSeconds < 1) {
          timer.cancel();
          isActive = false;
          await addCount();
          resetTimer();
          setState(() {});
          await notification();
        } else {
          setState(() {
            _currentSeconds = _currentSeconds - 1;
          });
          _systemTray.setTitle((int leftSeconds) {
            final minutes =
                (leftSeconds / 60).floor().toString().padLeft(2, '0');
            final seconds =
                (leftSeconds % 60).floor().toString().padLeft(2, '0');
            return '$minutes:$seconds';
          }(_currentSeconds));
        }
      },
    );
  }

  Future<void> addCount() async {
    _currentCompleteCount = _currentCompleteCount + 1;
    await prefs.setInt(completeCountKey, _currentCompleteCount);
  }

  void stopTimer() {
    _timer?.cancel();
    setState(() {
      isActive = false;
    });
  }

  void resetTimer() {
    _timer?.cancel();
    setState(() {
      _currentSeconds = 1500;
    });
  }

  Future<void> add() async {
    setState(() {
      _currentSeconds = _currentSeconds + 60;
    });
  }

  Future<void> notification() async {
    const title = 'ポモドーロ完了！';
    var body = 'current complete count is $_currentCompleteCount!!!';
    const notificationDetails =
        NotificationDetails(macOS: DarwinNotificationDetails());
    await _notificationsPlugin.show(
        _notificationId, title, body, notificationDetails);
    _notificationId = _notificationId + 1;
  }

  void minus() async {
    setState(() {
      _currentSeconds = _currentSeconds - 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              (int leftSeconds) {
                final minutes =
                    (leftSeconds / 60).floor().toString().padLeft(2, '0');
                final seconds =
                    (leftSeconds % 60).floor().toString().padLeft(2, '0');
                return '$minutes:$seconds';
              }(_currentSeconds),
              style: Theme.of(context)
                  .textTheme
                  .headline4!
                  .copyWith(fontSize: 180),
            ),
            Text('達成回数${_currentCompleteCount.toString()}回！'),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          isActive
              ? FloatingActionButton(
                  onPressed: stopTimer,
                  tooltip: 'stop',
                  child: const Icon(Icons.stop),
                )
              : FloatingActionButton(
                  onPressed: startTimer,
                  tooltip: 'start',
                  child: const Icon(Icons.play_arrow),
                ),
          const SizedBox(
            height: 10,
          ),
          FloatingActionButton(
            onPressed: resetTimer,
            tooltip: 'reset',
            child: const Icon(Icons.restart_alt_outlined),
          ),
          const SizedBox(
            height: 10,
          ),
          FloatingActionButton(
            onPressed: add,
            tooltip: 'add',
            child: const Icon(Icons.add),
          ),
          const SizedBox(
            height: 10,
          ),
          FloatingActionButton(
            onPressed: minus,
            tooltip: 'minus',
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
