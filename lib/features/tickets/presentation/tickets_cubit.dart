/// Tickets Cubit — manages the home screen ticket list state.
///
/// No business logic in widgets. All filtering, searching, and status
/// updates are dispatched as methods on this Cubit.
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/ticket_entity.dart';
import '../domain/ticket_repository.dart';
import '../../../core/constants/app_constants.dart';
import 'tickets_state.dart';

/// Manages state for the home screen ticket list.
class TicketsCubit extends Cubit<TicketsState> {
  TicketsCubit(this._repository) : super(const TicketsInitial());

  final TicketRepository _repository;
  StreamSubscription<List<TicketEntity>>? _subscription;
  String? _currentShopId;
  String? _currentBranchId;

  String? get activeBranchId => _currentBranchId;

  /// Starts watching all tickets (live updates) for current shop and branch.
  Future<void> loadTickets({String? shopId, String? branchId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isOwner = prefs.getBool('is_shop_owner') ?? true;
      _currentShopId = shopId ?? _currentShopId ?? prefs.getString(AppConstants.prefShopId);

      if (!isOwner) {
        // Sub-branch is strictly locked to its own assigned branchId!
        _currentBranchId = prefs.getString('current_branch_id') ?? 'main';
      } else {
        _currentBranchId = branchId ?? _currentBranchId ?? prefs.getString('current_branch_id');
      }
    } catch (_) {}

    emit(const TicketsLoading());
    _subscription?.cancel();
    _subscription = _repository.watchTickets(
      shopId: _currentShopId,
      branchId: _currentBranchId,
    ).listen(
      (tickets) {
        final current = state;
        emit(TicketsLoaded(
          allTickets: tickets,
          selectedFilter:
              current is TicketsLoaded ? current.selectedFilter : 0,
          searchQuery:
              current is TicketsLoaded ? current.searchQuery : '',
          activeBranchId: _currentBranchId,
        ));
      },
      onError: (e) => emit(TicketsError(e.toString())),
    );
  }

  /// Switches active branch filter and reloads tickets.
  Future<void> switchBranch(String? branchId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isOwner = prefs.getBool('is_shop_owner') ?? true;
      if (!isOwner) {
        // Sub-branch staff cannot switch branches!
        return;
      }
    } catch (_) {}
    _currentBranchId = (branchId == null || branchId == 'all') ? null : branchId;
    loadTickets(branchId: _currentBranchId);
  }

  /// Changes the active status filter chip.
  void selectFilter(int index) {
    final current = state;
    if (current is TicketsLoaded) {
      emit(current.copyWith(selectedFilter: index));
    }
  }

  /// Updates the search query.
  void search(String query) {
    final current = state;
    if (current is TicketsLoaded) {
      emit(current.copyWith(searchQuery: query));
    }
  }

  /// Updates a ticket's status.
  Future<void> updateStatus(
    String ticketId,
    TicketStatus newStatus, {
    String? note,
  }) async {
    await _repository.updateTicketStatus(ticketId, newStatus, note: note);
  }

  /// Creates a new ticket.
  Future<TicketEntity> createTicket(TicketEntity ticket) async {
    return _repository.createTicket(ticket);
  }

  /// Sets a device type filter (null = show all).
  void setDeviceTypeFilter(DeviceType? type) {
    final current = state;
    if (current is TicketsLoaded) {
      if (type == null) {
        emit(current.copyWith(clearDeviceTypeFilter: true));
      } else {
        emit(current.copyWith(deviceTypeFilter: type));
      }
    }
  }

  /// Sets sort order.
  void setSortOrder({required bool newestFirst}) {
    final current = state;
    if (current is TicketsLoaded) {
      emit(current.copyWith(sortNewestFirst: newestFirst));
    }
  }

  /// Resets all advanced filters (device type, sort) to defaults.
  void clearFilters() {
    final current = state;
    if (current is TicketsLoaded) {
      emit(current.copyWith(
        clearDeviceTypeFilter: true,
        sortNewestFirst: true,
      ));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
