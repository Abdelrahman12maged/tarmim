/// Supabase implementation of TicketDataSource.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/ticket_entity.dart';
import 'ticket_datasource.dart';
import 'ticket_model.dart';

class SupabaseTicketDataSource implements TicketDataSource {
  SupabaseTicketDataSource();

  SupabaseClient get _client => SupabaseConfig.client;

  @override
  Stream<List<TicketEntity>> watchTickets({
    TicketStatus? statusFilter,
    String? shopId,
    String? branchId,
  }) {
    // Stream from Supabase 'tickets' table ordered by createdAt desc
    final stream = _client
        .from('tickets')
        .stream(primaryKey: ['id'])
        .order('createdAt', ascending: false)
        .map((rows) => rows
            .map((row) => TicketModel.fromMap(row).toEntity())
            .toList());

    return stream.map((list) {
      return list.where((t) {
        if (shopId != null && shopId.isNotEmpty) {
          if (t.shopId != null && t.shopId != shopId) return false;
        }
        if (branchId != null && branchId.isNotEmpty) {
          if (t.branchId != branchId) return false;
        }
        if (statusFilter != null && t.status != statusFilter) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<TicketEntity?> getTicket(String id) async {
    try {
      final res = await _client
          .from('tickets')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (res == null) return null;
      return TicketModel.fromMap(res).toEntity();
    } catch (e) {
      debugPrint('Supabase getTicket error: $e');
      return null;
    }
  }

  @override
  Future<TicketEntity> createTicket(TicketEntity ticket) async {
    final map = TicketModel.fromEntity(ticket).toMap();
    await _client.from('tickets').insert(map);
    return ticket;
  }

  @override
  Future<void> updateTicketStatus(
    String id,
    TicketStatus status, {
    String? note,
  }) async {
    await _client.from('tickets').update({
      'status': status.name,
      if (note != null) 'internalNotes': note,
      'updatedAt': DateTime.now().toIso8601String(),
    }).eq('id', id);

    // Also record status history
    try {
      await _client.from('status_history').insert({
        'ticketId': id,
        'status': status.name,
        'note': note ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Supabase status_history insert error: $e');
    }
  }

  @override
  Future<void> updateTicket(TicketEntity ticket) async {
    final map = TicketModel.fromEntity(ticket).toMap();
    await _client.from('tickets').update(map).eq('id', ticket.id);
  }

  @override
  Future<void> deleteTicket(String id) async {
    await _client.from('tickets').delete().eq('id', id);
  }

  @override
  Future<List<TicketEntity>> getTicketsByCustomer(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final res = await _client
          .from('tickets')
          .select()
          .eq('customerPhone', cleanPhone)
          .order('createdAt', ascending: false);

      return (res as List<dynamic>)
          .map((m) => TicketModel.fromMap(m as Map<String, dynamic>).toEntity())
          .toList();
    } catch (e) {
      debugPrint('Supabase getTicketsByCustomer error: $e');
      return [];
    }
  }
}
