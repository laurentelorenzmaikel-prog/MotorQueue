import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 2)
class UserModel extends HiveObject {
  @HiveField(0)
  String username;

  @HiveField(1)
  String password;

  @HiveField(2)
  String role; // 'admin' or 'user'

  UserModel({
    required this.username,
    required this.password,
    required this.role,
  });
}
