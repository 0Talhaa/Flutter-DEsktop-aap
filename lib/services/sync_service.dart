// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/note.dart';
// import 'database_helper.dart';

// class SyncService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   Future<void> syncToFirebase() async {
//     final notes = await DatabaseHelper.instance.getAllNotes();

//     final batch = _firestore.batch();
//     final collectionRef = _firestore.collection('notes');

//     for (var note in notes) {
//       final docRef = collectionRef.doc();
//       batch.set(docRef, {
//         'title': note.title,
//         'content': note.content,
//         'createdAt': note.createdAt.toIso8601String(),
//         'localId': note.id,
//       });
//     }

//     await batch.commit();
//   }
// }