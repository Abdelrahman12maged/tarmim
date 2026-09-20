/// Tickets Cubit state definitions.
import 'package:equatable/equatable.dart';
import '../domain/ticket_entity.dart';
import '../../../core/constants/app_constants.dart';

/// Base state class for the tickets list feature.
abstract class TicketsState extends Equatable {
  const TicketsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded.
class TicketsInitial extends TicketsState {
  const TicketsInitial();
}

/// Loading tickets from the data source.
class TicketsLoading extends TicketsState {
  const TicketsLoading();
}

/// Tickets successfully loaded.
class TicketsLoaded extends TicketsState {
  const TicketsLoaded({
    required this.allTickets,
    required this.selectedFilter,
    required this.searchQuery,
    this.deviceTypeFilter,
    this.sortNewestFirst = true,
    this.activeBranchId,
  });

  final List<TicketEntity> allTickets;
  final int selectedFilter; // 0=all active, 1=ready, 2=diagnosis, 3=waiting, 4=delivered, 5=cancelled
  final String searchQuery;
  final DeviceType? deviceTypeFilter;
  final bool sortNewestFirst;
  final String? activeBranchId;

  /// Filtered and searched list for display.
  List<TicketEntity> get displayTickets {
    var list = List<TicketEntity>.from(allTickets);

    // Apply status filter
    if (selectedFilter == 0) {
      // Tab 0 focuses on active tickets in workshop; search still checks all tickets
      if (searchQuery.isEmpty) {
        list = list.where((t) => !t.status.isCompleted).toList();
      }
    } else if (selectedFilter == 1) {
      list = list.where((t) => t.status == TicketStatus.readyForPickup).toList();
    } else if (selectedFilter == 2) {
      list = list.where((t) => t.status == TicketStatus.inDiagnosis).toList();
    } else if (selectedFilter == 3) {
      list = list.where((t) => t.status == TicketStatus.waitingForPart).toList();
    } else if (selectedFilter == 4) {
      list = list.where((t) => t.status == TicketStatus.delivered).toList();
    } else if (selectedFilter == 5) {
      list = list.where((t) => t.status == TicketStatus.cancelled).toList();
    }

    // Apply device type filter
    if (deviceTypeFilter != null) {
      list = list.where((t) => t.deviceType == deviceTypeFilter).toList();
    }

    // Apply search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((t) {
        return t.customerName.toLowerCase().contains(q) ||
            t.deviceModel.toLowerCase().contains(q) ||
            t.ticketNumber.toLowerCase().contains(q) ||
            t.customerPhone.contains(q);
      }).toList();
    }

    // Sort
    list.sort((a, b) => sortNewestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));

    return list;
  }

  /// Total active tickets (neither delivered nor cancelled).
  int get totalActive =>
      allTickets.where((t) => !t.status.isCompleted).length;

  /// Count of tickets in each status.
  int countForStatus(TicketStatus status) =>
      allTickets.where((t) => t.status == status).length;

  TicketsLoaded copyWith({
    List<TicketEntity>? allTickets,
    int? selectedFilter,
    String? searchQuery,
    DeviceType? deviceTypeFilter,
    bool? clearDeviceTypeFilter,
    bool? sortNewestFirst,
    String? activeBranchId,
  }) {
    return TicketsLoaded(
      allTickets: allTickets ?? this.allTickets,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      deviceTypeFilter: clearDeviceTypeFilter == true
          ? null
          : (deviceTypeFilter ?? this.deviceTypeFilter),
      sortNewestFirst: sortNewestFirst ?? this.sortNewestFirst,
      activeBranchId: activeBranchId ?? this.activeBranchId,
    );
  }

  @override
  List<Object?> get props =>
      [allTickets, selectedFilter, searchQuery, deviceTypeFilter, sortNewestFirst, activeBranchId];
}

/// Error loading tickets.
class TicketsError extends TicketsState {
  const TicketsError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
