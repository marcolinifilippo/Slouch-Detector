class PostureResponse {
  final bool isSlouching;
  final String message;

  PostureResponse({required this.isSlouching, required this.message});

  // Maps the JSON received from Flask to our Dart object
  factory PostureResponse.fromJson(Map<String, dynamic> json) {
    return PostureResponse(
      isSlouching: json['is_slouching'] ?? false,
      // Default message if the server sends nothing
      message: json['message'] ?? 'No data received', 
    );
  }
}
