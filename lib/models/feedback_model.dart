import 'package:hive/hive.dart';

part 'feedback_model.g.dart';

@HiveType(typeId: 1)
class FeedbackModel extends HiveObject {
  @HiveField(0)
  String service;

  @HiveField(1)
  double rating;

  @HiveField(2)
  String comment;

  @HiveField(3)
  DateTime timestamp;

  @HiveField(4)
  String feedback;

  FeedbackModel({
    required this.service,
    required this.rating,
    required this.comment,
    required this.timestamp,
    required this.feedback,
  });
}
