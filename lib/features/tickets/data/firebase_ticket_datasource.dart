/// Firestore data source for tickets.
///
/// Handles real-time synchronization with Cloud Firestore.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/ticket_entity.dart';
import '../../../core/constants/app_constants.dart';
import 'ticket_datasource.dart';
import 'ticket_model.dart';

/// Concrete implementation of [TicketDataSource] using Cloud Firestore.
class FirebaseTicketDataSource implements TicketDataSource {
  FirebaseTicketDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ticketsCollection =>
      _firestore.collection('tickets');

  CollectionReference<Map<String, dynamic>> get _publicTrackingCollection =>
      _firestore.collection('public_tracking');

  /// Synchronizes a sanitized public tracking document in /public_tracking/{ticketNumber}.
  /// This protects workshop business secrets (no wholesale part costs, no technician profit notes).
  Future<void> _syncPublicTracking(TicketModel model) async {
    try {
      if (model.ticketNumber.isEmpty) return;
      await _publicTrackingCollection.doc(model.ticketNumber).set({
        'ticketNumber': model.ticketNumber,
        'customerName': model.customerName,
        'customerPhone': model.customerPhone,
        'deviceType': model.deviceType.name,
        'deviceModel': model.deviceModel,
        'issueDescription': model.issueDescription,
        'estimatedCost': model.estimatedCost,
        'deposit': model.deposit,
        'status': model.status.value,
        'statusHistory': model.statusHistory.map((e) => {
              'status': e.status.value,
              'timestamp': e.timestamp.toIso8601String(),
              'note': e.note,
              'technicianName': e.technicianName,
            }).toList(),
        'createdAt': model.createdAt.toIso8601String(),
        'imageUrl': model.imageUrl,
        'images': model.images,
        'afterRepairImages': model.afterRepairImages,
        'sendWhatsAppLink': model.sendWhatsAppLink,
        'shopId': model.shopId,
        'shopName': model.shopName,
        'shopPhone': model.shopPhone,
        'shopAddress': model.shopAddress,
        'branchId': model.branchId,
        'branchName': model.branchName,
      }, SetOptions(merge: true));
    } catch (e) {
      // Non-blocking sync
    }
  }

  @override
  Stream<List<TicketEntity>> watchTickets({
    TicketStatus? statusFilter,
    String? shopId,
    String? branchId,
  }) {
    Query<Map<String, dynamic>> query = _ticketsCollection;

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }

    return query.snapshots().map((snapshot) {
      var list = snapshot.docs.map((doc) {
        return TicketModel.fromJson(doc.data(), doc.id);
      }).toList();

      // Multi-tenant isolation:
      if (shopId != null && shopId.isNotEmpty) {
        list = list.where((t) {
          // If ticket has a shopId, it must match current shop
          if (t.shopId != null && t.shopId!.isNotEmpty) {
            return t.shopId == shopId;
          }
          // Legacy ticket backwards compatibility (assigned to default shop)
          return true;
        }).toList();
      }

      // Branch isolation:
      if (branchId != null && branchId.isNotEmpty && branchId != 'all') {
        list = list.where((t) => t.branchId == branchId).toList();
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<TicketEntity?> getTicket(String id) async {
    final clean = id.replaceAll('#', '').trim();
    if (clean.isEmpty) return null;

    // 1. Try public tracking collection first (sanitized for customer tracking)
    try {
      final pubDoc = await _publicTrackingCollection.doc(clean).get();
      if (pubDoc.exists && pubDoc.data() != null) {
        return TicketModel.fromJson(pubDoc.data()!, pubDoc.id);
      }
      if (!clean.toUpperCase().startsWith('TR-')) {
        final pubWithPrefix = await _publicTrackingCollection.doc('TR-$clean').get();
        if (pubWithPrefix.exists && pubWithPrefix.data() != null) {
          return TicketModel.fromJson(pubWithPrefix.data()!, pubWithPrefix.id);
        }
      }
    } catch (_) {}

    // 2. Check direct Firestore document ID in internal collection
    try {
      final doc = await _ticketsCollection.doc(clean).get();
      if (doc.exists && doc.data() != null) {
        return TicketModel.fromJson(doc.data()!, doc.id);
      }
    } catch (_) {}

    // 3. Check ticketNumber in internal collection
    try {
      final query = await _ticketsCollection
          .where('ticketNumber', isEqualTo: clean)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final d = query.docs.first;
        return TicketModel.fromJson(d.data(), d.id);
      }

      if (!clean.toUpperCase().startsWith('TR-')) {
        final queryWithPrefix = await _ticketsCollection
            .where('ticketNumber', isEqualTo: 'TR-$clean')
            .limit(1)
            .get();
        if (queryWithPrefix.docs.isNotEmpty) {
          final d = queryWithPrefix.docs.first;
          return TicketModel.fromJson(d.data(), d.id);
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<TicketEntity> createTicket(TicketEntity ticket) async {
    final docRef = _ticketsCollection.doc();
    final newId = docRef.id;

    final ticketNumber = ticket.ticketNumber.isNotEmpty
        ? ticket.ticketNumber
        : 'TR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final toSave = ticket.copyWith(
      id: newId,
      ticketNumber: ticketNumber,
    );
    final model = TicketModel.fromEntity(toSave);

    await docRef.set(model.toJson());
    await _syncPublicTracking(model);
    return model;
  }

  @override
  Future<void> updateTicketStatus(
    String id,
    TicketStatus status, {
    String? note,
  }) async {
    final newEntry = {
      'status': status.value,
      'timestamp': DateTime.now().toIso8601String(),
      'note': note,
    };

    await _ticketsCollection.doc(id).update({
      'status': status.value,
      'statusHistory': FieldValue.arrayUnion([newEntry]),
    });

    try {
      final doc = await _ticketsCollection.doc(id).get();
      if (doc.exists && doc.data() != null) {
        final model = TicketModel.fromJson(doc.data()!, doc.id);
        await _syncPublicTracking(model);
      }
    } catch (_) {}
  }

  @override
  Future<void> updateTicket(TicketEntity ticket) async {
    final model = TicketModel.fromEntity(ticket);
    await _ticketsCollection.doc(ticket.id).update(model.toJson());
    await _syncPublicTracking(model);
  }

  @override
  Future<void> deleteTicket(String id) async {
    try {
      final doc = await _ticketsCollection.doc(id).get();
      if (doc.exists && doc.data() != null) {
        final ticketNum = doc.data()!['ticketNumber'] as String?;
        if (ticketNum != null && ticketNum.isNotEmpty) {
          await _publicTrackingCollection.doc(ticketNum).delete();
        }
      }
    } catch (_) {}
    await _ticketsCollection.doc(id).delete();
  }

  @override
  Future<List<TicketEntity>> getTicketsByCustomer(String phone) async {
    final query = await _ticketsCollection
        .where('customerPhone', isEqualTo: phone)
        .get();

    final list = query.docs.map((doc) {
      return TicketModel.fromJson(doc.data(), doc.id);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
