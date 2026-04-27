class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.minutes,
    required this.thumbnailImageUrl,
    required this.videoDownloadUrl,
  });

  final int id;
  final String name;
  final int minutes;
  final String thumbnailImageUrl;
  final String videoDownloadUrl;

  factory Workout.fromJson(Map<String, Object?> json) {
    final id = json['id'] as int;
    return Workout(
      id: id,
      name: json['name'] as String,
      minutes: json['minutes'] as int,
      thumbnailImageUrl:
          (json['thumbnailImageUrl'] as String?) ??
          '/assets/workouts/$id/cover.png',
      videoDownloadUrl:
          (json['videoDownloadUrl'] as String?) ??
          '/assets/workouts/$id/video.bin',
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'minutes': minutes,
      'thumbnailImageUrl': thumbnailImageUrl,
      'videoDownloadUrl': videoDownloadUrl,
    };
  }
}
