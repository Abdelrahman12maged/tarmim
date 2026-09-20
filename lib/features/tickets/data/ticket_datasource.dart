/// Mock local data source for tickets.
///
/// Provides realistic sample data so the app runs without a Firebase connection.
/// Replace with [FirebaseTicketDataSource] when Firebase is configured.
import '../domain/ticket_entity.dart';
import '../../../core/constants/app_constants.dart';
import 'dart:async';

/// Abstract contract for ticket data sources.
abstract class TicketDataSource {
  Stream<List<TicketEntity>> watchTickets({
    TicketStatus? statusFilter,
    String? shopId,
    String? branchId,
  });
  Future<TicketEntity?> getTicket(String id);
  Future<TicketEntity> createTicket(TicketEntity ticket);
  Future<void> updateTicketStatus(String id, TicketStatus status, {String? note});
  Future<void> updateTicket(TicketEntity ticket);
  Future<void> deleteTicket(String id);
  Future<List<TicketEntity>> getTicketsByCustomer(String phone);
}

/// In-memory mock data source with realistic Arabic content.
class MockTicketDataSource implements TicketDataSource {
  MockTicketDataSource() {
    _tickets = _buildSampleTickets();
    _controller = StreamController<List<TicketEntity>>.broadcast();
    _notifyListeners();
  }

  late List<TicketEntity> _tickets;
  late StreamController<List<TicketEntity>> _controller;

  void _notifyListeners() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_tickets));
    }
  }

  @override
  Stream<List<TicketEntity>> watchTickets({
    TicketStatus? statusFilter,
    String? shopId,
    String? branchId,
  }) {
    final stream = _controller.stream;
    return stream.map((list) {
      var filtered = list;
      if (statusFilter != null) {
        filtered = filtered.where((t) => t.status == statusFilter).toList();
      }
      if (shopId != null && shopId.isNotEmpty) {
        filtered = filtered.where((t) => t.shopId == null || t.shopId == shopId).toList();
      }
      if (branchId != null && branchId.isNotEmpty && branchId != 'all') {
        filtered = filtered.where((t) => t.branchId == branchId).toList();
      }
      return filtered;
    });
  }

  @override
  Future<TicketEntity?> getTicket(String id) async {
    final clean = id.replaceAll('#', '').trim().toLowerCase();
    try {
      return _tickets.firstWhere((t) {
        final tNum = t.ticketNumber.replaceAll('#', '').trim().toLowerCase();
        return t.id.toLowerCase() == clean ||
            tNum == clean ||
            tNum == 'tr-$clean' ||
            'tr-$tNum' == clean;
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TicketEntity> createTicket(TicketEntity ticket) async {
    final newId = 'ticket_${DateTime.now().millisecondsSinceEpoch}';
    final ticketNumber = 'TR-${4000 + _tickets.length + 1}';
    final newTicket = ticket.copyWith(id: newId, ticketNumber: ticketNumber);
    _tickets = [newTicket, ..._tickets];
    _notifyListeners();
    return newTicket;
  }

  @override
  Future<void> updateTicketStatus(
    String id,
    TicketStatus status, {
    String? note,
  }) async {
    final index = _tickets.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final ticket = _tickets[index];
    final newEntry = StatusHistoryEntry(
      status: status,
      timestamp: DateTime.now(),
      note: note,
    );
    final updated = ticket.copyWith(
      status: status,
      statusHistory: [newEntry, ...ticket.statusHistory],
    );
    _tickets = [..._tickets]..[index] = updated;
    _notifyListeners();
  }

  @override
  Future<void> updateTicket(TicketEntity ticket) async {
    final index = _tickets.indexWhere((t) => t.id == ticket.id);
    if (index == -1) return;
    _tickets = [..._tickets]..[index] = ticket;
    _notifyListeners();
  }

  @override
  Future<void> deleteTicket(String id) async {
    _tickets = _tickets.where((t) => t.id != id).toList();
    _notifyListeners();
  }

  @override
  Future<List<TicketEntity>> getTicketsByCustomer(String phone) async {
    return _tickets.where((t) => t.customerPhone == phone).toList();
  }

  List<TicketEntity> _buildSampleTickets() {
    final now = DateTime.now();
    return [
      TicketEntity(
        id: 'ticket_1',
        ticketNumber: 'TR-8812',
        customerName: 'عبد الرحمن السعيد',
        customerPhone: '01023456789',
        deviceType: DeviceType.watch,
        deviceModel: 'ساعة رولكس أوتوماتيك Datejust',
        issueDescription: 'ضبط العقارب والميزان واستبدال الزنبرك - ميناء أزرق بحري أصلي وضبط العزل',
        estimatedCost: 600,
        deposit: 150,
        status: TicketStatus.readyForPickup,
        statusHistory: [
          StatusHistoryEntry(
            status: TicketStatus.readyForPickup,
            timestamp: now,
            note: 'تم ضبط ميزان الحركة وإجراء فحص ضغط الهواء لعزل الماء بنجاح تام.',
          ),
          StatusHistoryEntry(
            status: TicketStatus.waitingForPart,
            timestamp: now.subtract(const Duration(hours: 10)),
            note: 'طلب جوان إغلاق أصلي للتاج الخلفي وتجهيز الترس الثالث من المخزن المركزي.',
          ),
          StatusHistoryEntry(
            status: TicketStatus.inDiagnosis,
            timestamp: now.subtract(const Duration(hours: 24)),
            note: 'استلام وتسجيل الغرض في الورشة، معاينة الخدوش الخارجية، واستلام عربون 150 ج.م.',
          ),
        ],
        partsCost: 200,
        createdAt: now.subtract(const Duration(days: 2)),
        shelfLocation: 'رف A-04',
        serialNumber: 'RX-938210',
        sendWhatsAppLink: true,
        shopName: AppConstants.defaultShopName,
        shopPhone: AppConstants.defaultShopPhone,
        shopAddress: AppConstants.defaultShopAddress,
      ),
      TicketEntity(
        id: 'ticket_2',
        ticketNumber: 'TR-8815',
        customerName: 'مريم خليل',
        customerPhone: '01145678900',
        deviceType: DeviceType.mobile,
        deviceModel: 'آيفون 13 برو - رمادي فلكي',
        issueDescription: 'كسر الشاشة الخارجية وفحص استجابة اللمس OLED',
        estimatedCost: 1800,
        deposit: 0,
        partsCost: 1100,
        status: TicketStatus.inDiagnosis,
        statusHistory: [
          StatusHistoryEntry(
            status: TicketStatus.inDiagnosis,
            timestamp: now.subtract(const Duration(hours: 2)),
            note: 'استلام الجهاز وبدء الفحص.',
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 2)),
        technicianName: 'طاولة الفني سامي',
        sendWhatsAppLink: false,
        shopName: AppConstants.defaultShopName,
        shopPhone: AppConstants.defaultShopPhone,
        shopAddress: AppConstants.defaultShopAddress,
      ),
      TicketEntity(
        id: 'ticket_3',
        ticketNumber: 'TR-8809',
        customerName: 'د. طارق يوسف',
        customerPhone: '01233445566',
        deviceType: DeviceType.home,
        deviceModel: 'ميكروويف باناسونيك 32 لتر',
        issueDescription: 'انقطاع التشغيل التلقائي - مطلوب ترانزستور عالي الجهد',
        estimatedCost: 650,
        deposit: 0,
        partsCost: 250,
        status: TicketStatus.waitingForPart,
        statusHistory: [
          StatusHistoryEntry(
            status: TicketStatus.waitingForPart,
            timestamp: now.subtract(const Duration(days: 1)),
            note: 'طلب الترانزستور من المورد.',
          ),
          StatusHistoryEntry(
            status: TicketStatus.inDiagnosis,
            timestamp: now.subtract(const Duration(days: 3)),
            note: 'فحص أولي واكتشاف العطل.',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 3)),
        sendWhatsAppLink: true,
        shopName: AppConstants.defaultShopName,
        shopPhone: AppConstants.defaultShopPhone,
        shopAddress: AppConstants.defaultShopAddress,
      ),
      TicketEntity(
        id: 'ticket_4',
        ticketNumber: 'TR-8804',
        customerName: 'هاني مسعود',
        customerPhone: '01099887766',
        deviceType: DeviceType.laptop,
        deviceModel: 'لابتوب ديل XPS 15 (9500)',
        issueDescription: 'إعادة لحام مسار Charging IC وتنظيف مروحة التبريد',
        estimatedCost: 1200,
        deposit: 250,
        partsCost: 400,
        status: TicketStatus.readyForPickup,
        statusHistory: [
          StatusHistoryEntry(
            status: TicketStatus.readyForPickup,
            timestamp: now.subtract(const Duration(hours: 1)),
            note: 'تم الإصلاح والتنظيف.',
          ),
          StatusHistoryEntry(
            status: TicketStatus.inDiagnosis,
            timestamp: now.subtract(const Duration(days: 1)),
            note: 'استلام الجهاز.',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 1)),
        shelfLocation: 'رف C-12',
        sendWhatsAppLink: true,
        shopName: AppConstants.defaultShopName,
        shopPhone: AppConstants.defaultShopPhone,
        shopAddress: AppConstants.defaultShopAddress,
      ),
      TicketEntity(
        id: 'ticket_5',
        ticketNumber: 'TR-3410',
        customerName: 'عبد الرحمن السعيد',
        customerPhone: '0102345678',
        deviceType: DeviceType.mobile,
        deviceModel: 'موبايل سامسونج S22 Ultra',
        issueDescription: 'استبدال مدخل الشحن السريع الأصلي Type-C وفحص مسار الشحن.',
        estimatedCost: 650,
        deposit: 650,
        partsCost: 220,
        status: TicketStatus.delivered,
        statusHistory: [
          StatusHistoryEntry(
            status: TicketStatus.delivered,
            timestamp: now.subtract(const Duration(days: 20)),
            note: 'تم التسليم.',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 25)),
        sendWhatsAppLink: true,
        shopName: AppConstants.defaultShopName,
        shopPhone: AppConstants.defaultShopPhone,
        shopAddress: AppConstants.defaultShopAddress,
      ),
    ];
  }
}
