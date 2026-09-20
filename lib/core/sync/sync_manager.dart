/// Offline-first synchronization manager.
///
/// Keeps local cache of tickets in SharedPreferences and manages a queue
/// of offline operations to be synced when internet is available.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../features/tickets/data/ticket_datasource.dart';
import '../../features/tickets/data/ticket_model.dart';
import '../../features/tickets/domain/ticket_entity.dart';

enum SyncStatus {
  synced,
  syncing,
  offline,
}

class SyncManager {
  SyncManager(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyLocalTickets = 'local_cached_tickets_v1';
  static const String _keyPendingCreates = 'pending_sync_creates_v1';
  static const String _keyPendingStatusUpdates = 'pending_sync_status_updates_v1';

  final ValueNotifier<SyncStatus> statusNotifier =
      ValueNotifier<SyncStatus>(SyncStatus.synced);
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  void init() {
    _updatePendingCount();
  }

  void _updatePendingCount() {
    final creates = _getPendingCreates().length;
    final updates = _getPendingStatusUpdates().length;
    final total = creates + updates;
    pendingCountNotifier.value = total;
    if (total > 0 && statusNotifier.value != SyncStatus.syncing) {
      statusNotifier.value = SyncStatus.offline;
    } else if (total == 0) {
      statusNotifier.value = SyncStatus.synced;
    }
  }

  // ── Local Cache ─────────────────────────────────────────────────────────────

  Future<void> cacheTickets(List<TicketEntity> tickets) async {
    try {
      final jsonList = tickets
          .map((t) => TicketModel.fromEntity(t).toMap())
          .toList();
      await _prefs.setString(_keyLocalTickets, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error caching tickets locally: $e');
    }
  }

  List<TicketEntity> getCachedTickets() {
    try {
      final raw = _prefs.getString(_keyLocalTickets);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((m) => TicketModel.fromMap(m as Map<String, dynamic>).toEntity())
          .toList();
    } catch (e) {
      debugPrint('Error loading cached tickets: $e');
      return [];
    }
  }

  // ── Pending Queue ───────────────────────────────────────────────────────────

  Future<void> enqueueCreateTicket(TicketEntity ticket) async {
    final current = _getPendingCreates();
    current.removeWhere((m) => m['id'] == ticket.id);
    current.add(TicketModel.fromEntity(ticket).toMap());
    await _prefs.setString(_keyPendingCreates, jsonEncode(current));

    // Also update local cache immediately
    final cached = getCachedTickets();
    cached.removeWhere((t) => t.id == ticket.id);
    cached.insert(0, ticket);
    await cacheTickets(cached);

    _updatePendingCount();
  }

  Future<void> enqueueStatusUpdate(
    String ticketId,
    TicketStatus status, {
    String? note,
  }) async {
    final current = _getPendingStatusUpdates();
    current.add({
      'ticketId': ticketId,
      'status': status.name,
      'note': note,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _prefs.setString(_keyPendingStatusUpdates, jsonEncode(current));

    // Update locally cached ticket
    final cached = getCachedTickets();
    final idx = cached.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      final old = cached[idx];
      final newHistory = [
        ...old.statusHistory,
        StatusHistoryEntry(
          status: status,
          timestamp: DateTime.now(),
          note: note,
        ),
      ];
      cached[idx] = old.copyWith(
        status: status,
        statusHistory: newHistory,
      );
      await cacheTickets(cached);
    }

    _updatePendingCount();
  }

  List<Map<String, dynamic>> _getPendingCreates() {
    try {
      final raw = _prefs.getString(_keyPendingCreates);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _getPendingStatusUpdates() {
    try {
      final raw = _prefs.getString(_keyPendingStatusUpdates);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  // ── Synchronization Execution ───────────────────────────────────────────────

  Future<bool> syncPending(TicketDataSource remoteDataSource) async {
    final creates = _getPendingCreates();
    final updates = _getPendingStatusUpdates();

    if (creates.isEmpty && updates.isEmpty) {
      statusNotifier.value = SyncStatus.synced;
      pendingCountNotifier.value = 0;
      return true;
    }

    statusNotifier.value = SyncStatus.syncing;

    try {
      // 1. Process pending creations
      final remainingCreates = <Map<String, dynamic>>[];
      for (final map in creates) {
        try {
          final ticket = TicketModel.fromMap(map).toEntity();
          await remoteDataSource.createTicket(ticket);
        } catch (e) {
          debugPrint('Sync create failed for ${map["id"]}: $e');
          remainingCreates.add(map);
        }
      }
      await _prefs.setString(_keyPendingCreates, jsonEncode(remainingCreates));

      // 2. Process pending status updates
      final remainingUpdates = <Map<String, dynamic>>[];
      for (final map in updates) {
        try {
          final ticketId = map['ticketId'] as String;
          final statusName = map['status'] as String;
          final status = TicketStatus.values.firstWhere(
            (s) => s.name == statusName,
            orElse: () => TicketStatus.inDiagnosis,
          );
          final note = map['note'] as String?;
          await remoteDataSource.updateTicketStatus(ticketId, status, note: note);
        } catch (e) {
          debugPrint('Sync status update failed: $e');
          remainingUpdates.add(map);
        }
      }
      await _prefs.setString(
          _keyPendingStatusUpdates, jsonEncode(remainingUpdates));

      _updatePendingCount();

      if (remainingCreates.isEmpty && remainingUpdates.isEmpty) {
        statusNotifier.value = SyncStatus.synced;
        return true;
      } else {
        statusNotifier.value = SyncStatus.offline;
        return false;
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      statusNotifier.value = SyncStatus.offline;
      return false;
    }
  }
}
