/// Concrete ticket repository implementation (data layer).
///
/// Implements [TicketRepository] by delegating to [TicketDataSource].
/// Isolates the domain from data source specifics.
import '../domain/ticket_entity.dart';
import '../domain/ticket_repository.dart';
import '../../../core/constants/app_constants.dart';
import 'ticket_datasource.dart';

/// Implementation of [TicketRepository] backed by a [TicketDataSource].
class TicketRepositoryImpl implements TicketRepository {
  const TicketRepositoryImpl(this._dataSource);

  final TicketDataSource _dataSource;

  @override
  Stream<List<TicketEntity>> watchTickets({
    TicketStatus? statusFilter,
    String? shopId,
    String? branchId,
  }) {
    return _dataSource.watchTickets(
      statusFilter: statusFilter,
      shopId: shopId,
      branchId: branchId,
    );
  }

  @override
  Future<TicketEntity?> getTicket(String id) {
    return _dataSource.getTicket(id);
  }

  @override
  Future<TicketEntity> createTicket(TicketEntity ticket) {
    return _dataSource.createTicket(ticket);
  }

  @override
  Future<void> updateTicketStatus(
    String ticketId,
    TicketStatus newStatus, {
    String? note,
  }) {
    return _dataSource.updateTicketStatus(ticketId, newStatus, note: note);
  }

  @override
  Future<void> updateTicket(TicketEntity ticket) {
    return _dataSource.updateTicket(ticket);
  }

  @override
  Future<void> deleteTicket(String ticketId) {
    return _dataSource.deleteTicket(ticketId);
  }

  @override
  Future<List<TicketEntity>> getTicketsByCustomer(String customerPhone) {
    return _dataSource.getTicketsByCustomer(customerPhone);
  }
}
