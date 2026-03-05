import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  FirebaseFirestore get db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get colleges => db.collection('colleges');
  CollectionReference<Map<String, dynamic>> get admins => db.collection('admins');
  CollectionReference<Map<String, dynamic>> get hostels => db.collection('hostels');
  CollectionReference<Map<String, dynamic>> get wardens => db.collection('wardens');
  CollectionReference<Map<String, dynamic>> get students => db.collection('students');
  CollectionReference<Map<String, dynamic>> get complaints => db.collection('complaints');
  CollectionReference<Map<String, dynamic>> get complaintHistory => db.collection('complaint_history');
  CollectionReference<Map<String, dynamic>> get attendance => db.collection('attendance');
  CollectionReference<Map<String, dynamic>> get notices => db.collection('notices');
  CollectionReference<Map<String, dynamic>> get outpasses => db.collection('outpasses');
  CollectionReference<Map<String, dynamic>> get deviceTokens => db.collection('device_tokens');
}
