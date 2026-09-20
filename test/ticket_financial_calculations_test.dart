import 'package:flutter_test/flutter_test.dart';
import 'package:tarmim/core/constants/app_constants.dart';
import 'package:tarmim/features/tickets/domain/ticket_entity.dart';
import 'package:tarmim/features/tickets/data/ticket_model.dart';

void main() {
  group('Ticket Financial Calculations & Spare Parts Profit Tests', () {
    test('Pure labor repair without spare parts', () {
      final ticket = TicketEntity(
        id: 't-1',
        ticketNumber: '1001',
        customerName: 'أحمد علي',
        customerPhone: '01012345678',
        deviceType: DeviceType.mobile,
        deviceModel: 'iPhone 13',
        issueDescription: 'تغيير سوكت شحن',
        status: TicketStatus.delivered,
        statusHistory: const [],
        estimatedCost: 350.0,
        deposit: 50.0,
        partsCost: 0.0,
        partsWholesaleCost: 0.0,
        createdAt: DateTime.now(),
      );

      expect(ticket.laborCost, 350.0);
      expect(ticket.partsProfit, 0.0);
      expect(ticket.netProfit, 350.0);
      expect(ticket.remainingAmount, 300.0);
    });

    test('Repair with spare parts earning profit (wholesale < customer price)', () {
      // Example: Screen repair
      // Customer pays: 1500 total (Screen 900, Labor 600)
      // Workshop wholesale cost for screen: 650
      // Technician parts profit: 900 - 650 = 250
      // Net workshop profit: Labor (600) + Parts Profit (250) = 850
      final ticket = TicketEntity(
        id: 't-2',
        ticketNumber: '1002',
        customerName: 'محمود حسن',
        customerPhone: '01198765432',
        deviceType: DeviceType.mobile,
        deviceModel: 'Samsung A54',
        issueDescription: 'شاشة مكسورة',
        status: TicketStatus.waitingForPart,
        statusHistory: const [],
        estimatedCost: 1500.0,
        deposit: 200.0,
        partsCost: 900.0,
        partsWholesaleCost: 650.0,
        partsDescription: 'شاشة OLED أصلية',
        createdAt: DateTime.now(),
      );

      expect(ticket.laborCost, 600.0); // 1500 - 900
      expect(ticket.partsProfit, 250.0); // 900 - 650
      expect(ticket.netProfit, 850.0); // 600 labor + 250 parts profit
      expect(ticket.remainingAmount, 1300.0); // 1500 - 200 deposit
    });

    test('Repair with spare parts sold at cost (zero parts profit)', () {
      final ticket = TicketEntity(
        id: 't-3',
        ticketNumber: '1003',
        customerName: 'كريم',
        customerPhone: '01234567890',
        deviceType: DeviceType.laptop,
        deviceModel: 'Dell Inspiron',
        issueDescription: 'بطارية تالفة',
        status: TicketStatus.readyForPickup,
        statusHistory: const [],
        estimatedCost: 1200.0,
        deposit: 0.0,
        partsCost: 800.0,
        partsWholesaleCost: 800.0,
        partsDescription: 'بطارية أصلية',
        createdAt: DateTime.now(),
      );

      expect(ticket.laborCost, 400.0);
      expect(ticket.partsProfit, 0.0);
      expect(ticket.netProfit, 400.0);
      expect(ticket.remainingAmount, 1200.0);
    });

    test('TicketModel JSON serialization preserves partsWholesaleCost', () {
      final model = TicketModel(
        id: 't-4',
        ticketNumber: '1004',
        customerName: 'سارة',
        customerPhone: '01000000000',
        deviceType: DeviceType.mobile,
        deviceModel: 'Xiaomi 12',
        issueDescription: 'كاميرا',
        status: TicketStatus.inDiagnosis,
        statusHistory: const [],
        estimatedCost: 950.0,
        partsCost: 550.0,
        partsWholesaleCost: 350.0,
        partsDescription: 'عدسة كاميرا خلفية',
        deposit: 100.0,
        createdAt: DateTime(2026, 9, 1),
      );

      final json = model.toJson();
      expect(json['partsWholesaleCost'], 350.0);

      final reconstructed = TicketModel.fromJson(json, 't-4');
      expect(reconstructed.partsWholesaleCost, 350.0);
      expect(reconstructed.partsCost, 550.0);
      expect(reconstructed.partsProfit, 200.0);
      expect(reconstructed.laborCost, 400.0);
      expect(reconstructed.netProfit, 600.0); // 400 labor + 200 parts profit

      // Also verify snake_case deserialization
      final snakeJson = {
        'parts_cost': 550.0,
        'parts_wholesale_cost': 350.0,
        'estimatedCost': 950.0,
      };
      final fromSnake = TicketModel.fromJson(snakeJson, 't-4b');
      expect(fromSnake.partsWholesaleCost, 350.0);
      expect(fromSnake.partsProfit, 200.0);
    });

    test('copyWith updates partsWholesaleCost cleanly', () {
      final ticket = TicketEntity(
        id: 't-5',
        ticketNumber: '1005',
        customerName: 'طارق',
        customerPhone: '01500000000',
        deviceType: DeviceType.other,
        deviceModel: 'iPad Air',
        issueDescription: 'تغيير تاتش',
        status: TicketStatus.inDiagnosis,
        statusHistory: const [],
        estimatedCost: 700.0,
        partsCost: 400.0,
        partsWholesaleCost: 0.0,
        deposit: 0.0,
        createdAt: DateTime.now(),
      );

      final updated = ticket.copyWith(
        partsWholesaleCost: 280.0,
      );

      expect(updated.partsWholesaleCost, 280.0);
      expect(updated.partsProfit, 120.0); // 400 - 280
      expect(updated.laborCost, 300.0); // 700 - 400
      expect(updated.netProfit, 420.0); // 300 labor + 120 parts profit
    });
  });
}
