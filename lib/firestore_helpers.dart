import 'package:cloud_firestore/cloud_firestore.dart';

/// Deletes a client and all their sessions (cascade delete).
/// Use this from any screen (clients_page, dashboard, etc.) when deleting a client
/// so that sessions are always removed too.
Future<void> deleteClientAndSessions(DocumentSnapshot client) async {
  final clientId = client.id;
  final sessionsSnapshot = await FirebaseFirestore.instance
      .collection('sessions')
      .where('clientId', isEqualTo: clientId)
      .get();
  const batchLimit = 500; // Firestore batch limit
  final docs = sessionsSnapshot.docs;
  for (var i = 0; i < docs.length; i += batchLimit) {
    final batch = FirebaseFirestore.instance.batch();
    final chunk = docs.skip(i).take(batchLimit);
    for (final doc in chunk) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
  await client.reference.delete();
}
