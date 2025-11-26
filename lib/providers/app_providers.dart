import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorenz_app/services/auth_service.dart';
import 'package:lorenz_app/services/firestore_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final authStateChangesProvider = StreamProvider((ref) {
  // Use ref.read() to avoid creating circular dependencies
  final auth = ref.read(authServiceProvider);
  return auth.authStateChanges();
});

final userDocStreamProvider = StreamProvider.family((ref, String uid) {
  // Use ref.read() to avoid creating circular dependencies
  final fs = ref.read(firestoreServiceProvider);
  return fs.streamUser(uid);
});
