import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monitor_provider.dart';

/// The main screen of the app.
/// It is a [StatefulWidget] because it needs to manage its own local state,
/// specifically the `_showCamera` toggle.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Local state: determines if the camera feed is visible or hidden.
  bool _showCamera = false;

  @override
  Widget build(BuildContext context) {
    // Access the MonitorProvider to listen for changes.
    // 'context.watch' (or Provider.of) makes this widget rebuild when notifyListeners() is called.
    final MonitorProvider provider = Provider.of<MonitorProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Slouch Detector"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Expanded takes up all available remaining space
            Expanded(
              child: StatusDisplay(
                showCamera: _showCamera,
                provider: provider,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              provider.statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(provider),
              ),
            ),
            const SizedBox(height: 30),
            ControlPanel(
              isMonitoring: provider.isMonitoring,
              showCamera: _showCamera,
              onCameraToggle: (bool val) {
                // setState tells Flutter to rebuild this widget with the new value
                setState(() => _showCamera = val);
              },
              onMonitoringToggle: () => provider.toggleMonitoring(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(MonitorProvider provider) {
    if (!provider.isMonitoring) return Colors.grey;
    if (!provider.isConnected) return Colors.orange;
    if (provider.isSlouching) return Colors.red;
    return Colors.green;
  }
}

/// A separate widget for the status display (Icon or Camera).
/// Extracting widgets makes the code cleaner and easier to read.
class StatusDisplay extends StatelessWidget {
  final bool showCamera;
  final MonitorProvider provider;

  const StatusDisplay({
    super.key,
    required this.showCamera,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = _getColor();
    
    if (showCamera) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: provider.isConnected
              ? const SafeCameraViewer()
              : const Center(
                  child: Text("Waiting for signal...",
                      style: TextStyle(color: Colors.white)),
                ),
        ),
      );
    }

    return Center(
      child: Container(
        height: 200,
        width: 200,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 5),
        ),
        child: Icon(_getIcon(), size: 100, color: color),
      ),
    );
  }

  Color _getColor() {
    if (!provider.isMonitoring) return Colors.grey;
    if (!provider.isConnected) return Colors.orange;
    if (provider.isSlouching) return Colors.red;
    return Colors.green;
  }

  IconData _getIcon() {
    if (!provider.isMonitoring) return Icons.power_settings_new;
    if (!provider.isConnected) return Icons.wifi_off;
    if (provider.isSlouching) return Icons.warning_amber_rounded;
    return Icons.check_circle;
  }
}

class ControlPanel extends StatelessWidget {
  final bool isMonitoring;
  final bool showCamera;
  final ValueChanged<bool> onCameraToggle;
  final VoidCallback onMonitoringToggle;

  const ControlPanel({
    super.key,
    required this.isMonitoring,
    required this.showCamera,
    required this.onCameraToggle,
    required this.onMonitoringToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isMonitoring)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Show camera feed", style: TextStyle(fontSize: 16)),
                Switch(
                  value: showCamera,
                  activeColor: Colors.blue,
                  onChanged: onCameraToggle,
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isMonitoring ? Colors.redAccent : Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: onMonitoringToggle,
            icon: Icon(isMonitoring ? Icons.stop : Icons.play_arrow),
            label: Text(isMonitoring ? "STOP" : "START"),
          ),
        ),
      ],
    );
  }
}

/// A widget to display the camera feed safely.
/// It uses a timer to force the image to refresh.
class SafeCameraViewer extends StatefulWidget {
  const SafeCameraViewer({super.key});

  @override
  State<SafeCameraViewer> createState() => _SafeCameraViewerState();
}

class _SafeCameraViewerState extends State<SafeCameraViewer> {
  int _timestamp = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // We refresh the image 10 times a second (every 100ms).
    // This creates a video effect from static images.
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _timestamp = DateTime.now().millisecondsSinceEpoch;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We add a timestamp to the URL to trick the browser/app into thinking
    // it's a new image every time. Otherwise, it would cache the first image.
    final String url = "http://127.0.0.1:5001/current_frame?t=$_timestamp";

    return Image.network(
      url,
      fit: BoxFit.contain,
      gaplessPlayback: true, // Prevents flickering when the image updates
      errorBuilder: (context, error, stackTrace) {
        return const Center(
            child: Icon(Icons.broken_image, color: Colors.grey));
      },
    );
  }
}
