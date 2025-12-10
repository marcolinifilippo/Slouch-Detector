import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/posture_response.dart';

/// This service handles all communication with the Python backend.
/// It acts as a bridge between the Flutter app and the Flask server.
class ApiService {
  // Localhost address for the Python/Flask server
  final String _baseUrl = 'http://127.0.0.1:5001/status';

  /// Asks the backend for the current posture status.
  /// Returns a PostureResponse object if successful, or null if there's an error.
  Future<PostureResponse?> checkPosture() async {
    try {
      // We use 'await' because http.get takes some time to complete.
      // While it waits, the app doesn't freeze.
      final http.Response response = await http.get(Uri.parse(_baseUrl));
      
      // Status code 200 means "OK" (Success).
      if (response.statusCode == 200) {
        // We decode the JSON string into a Map (Key-Value pairs)
        final Map<String, dynamic> data = jsonDecode(response.body);
        // Then we convert that Map into our Dart object
        return PostureResponse.fromJson(data);
      }
    } catch (e) {
      // If the server is down, this block will catch the error.
      // We print it to the console for debugging.
      print("Connection error: $e");
    }
    // Return null if server is down or unreachable
    return null;
  }
}
