import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../services/api_service.dart';
import '../services/notification_service.dart';

/// This class manages the state of the application (Business Logic).
/// It extends [ChangeNotifier] so that any Widget listening to it
/// will rebuild whenever we call [notifyListeners()].
class MonitorProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  // State variables
  bool _isMonitoring = false;
  bool _isConnected = false;
  bool _isSlouching = false;
  String _statusMessage = "Ready";
  
  Timer? _timer;
  Process? _pythonProcess;

  // We use a cooldown to prevent spamming notifications every second.
  DateTime? _lastNotificationTime;
  final Duration _notificationCooldown = const Duration(seconds: 10);

  // Getters allow widgets to read the state but not modify it directly.
  bool get isMonitoring => _isMonitoring;
  bool get isConnected => _isConnected;
  bool get isSlouching => _isSlouching;
  String get statusMessage => _statusMessage;

  MonitorProvider() {
    _notificationService.init();
  }

  /// Starts the Python backend process.
  /// We need to find the correct path to the python executable dynamically
  /// because it might be different on every computer.
  Future<void> _startPythonServer() async {
    if (_pythonProcess != null) return;

    try {
      // Directory.current gives us the root of the project in debug mode.
      final String projectRoot = Directory.current.path;
      final String backendDir = p.join(projectRoot, 'python_backend');
      final String scriptPath = p.join(backendDir, 'backend.py');
      
      // Try to find the virtual environment python first
      String pythonExec = p.join(backendDir, 'venv', 'bin', 'python');
      if (!File(pythonExec).existsSync()) {
        print("Venv python not found, trying system python3");
        pythonExec = 'python3'; 
      }

      print("Launching Python: $pythonExec $scriptPath");

      // Process.start runs the command in the background
      _pythonProcess = await Process.start(
        pythonExec,
        [scriptPath],
        runInShell: false,
        workingDirectory: backendDir,
        environment: {
          'OPENCV_AVFOUNDATION_SKIP_AUTH': '1',
        },
      );

      // Listen to the output of the python script for debugging
      _pythonProcess!.stdout.transform(const SystemEncoding().decoder).listen((data) {
        if (kDebugMode) print("[PYTHON]: $data");
      });
      _pythonProcess!.stderr.transform(const SystemEncoding().decoder).listen((data) {
        if (kDebugMode) print("[PYTHON ERR]: $data");
      });

      // Wait a second to let the server start up
      await Future.delayed(const Duration(seconds: 1));

    } catch (e) {
      print("ERROR PYTHON LAUNCH: $e");
      _statusMessage = "Error launching backend";
      notifyListeners();
    }
  }

  void _stopPythonServer() {
    if (_pythonProcess != null) {
      print("Stopping Python backend...");
      _pythonProcess!.kill();
      _pythonProcess = null;
    }
  }

  /// Main action called by the UI to start/stop monitoring.
  Future<void> toggleMonitoring() async {
    _isMonitoring = !_isMonitoring;

    if (_isMonitoring) {
      _statusMessage = "Starting camera...";
      notifyListeners(); // Update UI immediately
      
      await _startPythonServer();
      _startLoop();
    } else {
      _stopLoop();
      _stopPythonServer();
      _statusMessage = "Ready";
    }
    notifyListeners();
  }

  void _stopLoop() {
    _timer?.cancel();
    _isSlouching = false;
    _isConnected = false;
    notifyListeners();
  }

  /// Starts a periodic timer that checks the posture status every second.
  void _startLoop() {
    _statusMessage = "Connecting...";
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // Ask the API Service for the current status
      final result = await _apiService.checkPosture();

      if (result == null) {
        // If result is null, the server is likely down or not ready
        _isConnected = false;
        _statusMessage = "Waiting for backend...";
      } else {
        _isConnected = true;
        _isSlouching = result.isSlouching;
        _statusMessage = result.message;

        if (_isSlouching) {
          _triggerNotification();
        }
      }
      // Notify listeners to update the UI with the new data
      notifyListeners();
    });
  }

  void _triggerNotification() {
    final DateTime now = DateTime.now();
    // Check if enough time has passed since the last notification
    if (_lastNotificationTime == null ||
        now.difference(_lastNotificationTime!) > _notificationCooldown) {
      _notificationService.showSlouchNotification();
      _lastNotificationTime = now;
    }
  }

  @override
  void dispose() {
    _stopPythonServer();
    super.dispose();
  }
}
