import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // Appointments
  CollectionReference<Map<String, dynamic>> get appointments =>
      _db.collection('appointments');
  // Users
  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> addAppointment(Map<String, dynamic> data) async {
    await appointments.add(data);
  }

  Future<void> updateAppointment(String id, Map<String, dynamic> data) async {
    await appointments.doc(id).update(data);
  }

  Future<void> deleteAppointment(String id) async {
    await appointments.doc(id).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAppointments(
      {String? userId}) {
    Query<Map<String, dynamic>> query = appointments.orderBy('dateTime');
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    return query.snapshots();
  }

  // Users helpers
  Future<void> upsertUser(String uid, Map<String, dynamic> data) async {
    await userDoc(uid).set(data, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUser(String uid) {
    return userDoc(uid).snapshots();
  }
}
