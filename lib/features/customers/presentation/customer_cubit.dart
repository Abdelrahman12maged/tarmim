/// Customer Profile state and Cubit.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/customer_entity.dart';
import '../../tickets/domain/ticket_entity.dart';
import '../../tickets/domain/ticket_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────

abstract class CustomerState extends Equatable {
  const CustomerState();
  @override
  List<Object?> get props => [];
}

class CustomerInitial extends CustomerState {
  const CustomerInitial();
}

class CustomerLoading extends CustomerState {
  const CustomerLoading();
}

class CustomerLoaded extends CustomerState {
  const CustomerLoaded({
    required this.customer,
    required this.tickets,
  });

  final CustomerEntity customer;
  final List<TicketEntity> tickets;

  @override
  List<Object?> get props => [customer, tickets];
}

class CustomerError extends CustomerState {
  const CustomerError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────────────────

class CustomerCubit extends Cubit<CustomerState> {
  CustomerCubit(this._ticketRepository) : super(const CustomerInitial());

  final TicketRepository _ticketRepository;

  Future<void> loadCustomer(String customerPhone) async {
    emit(const CustomerLoading());
    try {
      final tickets =
          await _ticketRepository.getTicketsByCustomer(customerPhone);

      // Derive customer info from tickets
      final name =
          tickets.isNotEmpty ? tickets.first.customerName : 'عميل';
      final totalPaid =
          tickets.fold<double>(0, (sum, t) => sum + t.deposit);
      final customer = CustomerEntity(
        id: customerPhone,
        name: name,
        phone: customerPhone,
        totalTransactions: totalPaid,
        ticketCount: tickets.length,
        attendanceRate: 100,
        internalNote:
            'عميل دقيق ومحترم، يفضل دائماً إبلاغه على الواتساب أو لا يأبل فور الانتهاء من أي مرحلة إصلاح.',
        isLoyal: tickets.length >= 3,
      );

      emit(CustomerLoaded(customer: customer, tickets: tickets));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }
}
