import 'package:local_notifier/local_notifier.dart';

class NotificationService {
  
  Future<void> init() async {
    // Basic setup for the notifier
    await localNotifier.setup(
      appName: 'Slouch Detector',
      shortcutPolicy: ShortcutPolicy.requireCreate, // Needed for Windows
    );
  }

  void showSlouchNotification() {
    LocalNotification notification = LocalNotification(
      title: "⚠️ Posture Alert",
      body: "You are slouching! Please sit up straight.",
      silent: false, // Set to true if you don't want sound
    );
    
    // Fire the notification
    notification.show();
  }
}
