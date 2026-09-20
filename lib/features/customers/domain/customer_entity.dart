/// Customer entity — pure domain object.
class CustomerEntity {
  const CustomerEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.totalTransactions = 0,
    this.ticketCount = 0,
    this.attendanceRate = 100,
    this.internalNote,
    this.isLoyal = false,
  });

  final String id;
  final String name;
  final String phone;
  final double totalTransactions;
  final int ticketCount;
  final int attendanceRate; // 0-100 %
  final String? internalNote;
  final bool isLoyal;
}
