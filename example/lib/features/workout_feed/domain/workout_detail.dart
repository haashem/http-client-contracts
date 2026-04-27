class WorkoutDetail {
  const WorkoutDetail({
    required this.id,
    required this.name,
    required this.minutes,
    required this.description,
    required this.coverImageUrl,
    required this.titleImageUrl,
  });

  final int id;
  final String name;
  final int minutes;
  final String description;
  final String coverImageUrl;
  final String titleImageUrl;

  factory WorkoutDetail.fromJson(Map<String, Object?> json) {
    return WorkoutDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      minutes: json['minutes'] as int,
      description: json['description'] as String,
      coverImageUrl: json['coverImageUrl'] as String,
      titleImageUrl: json['titleImageUrl'] as String,
    );
  }
}
