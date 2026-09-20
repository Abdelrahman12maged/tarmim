/// Abstract repository interface for tickets — domain layer.
///
/// No implementation details; only defines the contract.
/// Data layer provides the concrete implementation.
import 'ticket_entity.dart';
import '../../../core/constants/app_constants.dart';

/// Contract for all ticket data operations.
abstract class TicketRepository {
  /// Returns a live stream of all tickets for the current shop and branch.
  Stream<List<TicketEntity>> watchTickets({
    TicketStatus? statusFilter,
    String? shopId,
    String? branchId,
  });

  /// Fetches a single ticket by its [id].
  Future<TicketEntity?> getTicket(String id);

  /// Creates a new ticket and returns the created entity.
  Future<TicketEntity> createTicket(TicketEntity ticket);

  /// Updates a ticket's status and appends a history entry.
  Future<void> updateTicketStatus(
    String ticketId,
    TicketStatus newStatus, {
    String? note,
  });

  /// Updates all mutable fields of a ticket.
  Future<void> updateTicket(TicketEntity ticket);

  /// Deletes a ticket permanently.
  Future<void> deleteTicket(String ticketId);

  /// Returns all tickets for a given customer phone.
  Future<List<TicketEntity>> getTicketsByCustomer(String customerPhone);
}
