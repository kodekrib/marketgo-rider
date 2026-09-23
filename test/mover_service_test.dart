import 'package:flutter_test/flutter_test.dart';

import 'package:rider/services/mover_service.dart';

void main() {
  group('MoverJob', () {
    test('parses a rider job payload', () {
      final job = MoverJob.fromJson({
        'id': 42,
        'customer_id': 7,
        'rider_id': null,
        'vehicle_type': 'van',
        'pickup_address': 'A',
        'delivery_address': 'B',
        'description': 'Furniture',
        'item_count': 3,
        'extra_pickers': 1,
        'packer_price': 4000,
        'quoted_price': 0,
        'status': 'pending',
        'customer_name': 'Ada',
        'created_at': '2026-09-12T09:15:00Z',
      });

      expect(job.id, 42);
      expect(job.customerId, 7);
      expect(job.isActive, isTrue);
      expect(job.nextStatus, 'en_route');
      expect(job.extraPackers, 1);
    });

    test('walks the mover lifecycle and finishes inactive on delivered', () {
      var status = 'pending';
      final job = () => MoverJob.fromJson({'id': 1, 'status': status});

      expect(job().nextStatus, 'en_route');
      status = 'en_route';
      expect(job().nextStatus, 'arrived');
      status = 'arrived';
      expect(job().nextStatus, 'loading');
      status = 'loading';
      expect(job().nextStatus, 'in_transit');
      status = 'in_transit';
      expect(job().nextStatus, 'delivered');
      status = 'delivered';
      expect(job().isActive, isFalse);
      expect(job().nextStatus, isNull);
    });
  });

  group('MoverService demo data', () {
    test('demoJobs map to MoverJob with an active pending job', () {
      final jobs = MoverService.demoJobs();
      expect(jobs, hasLength(1));
      expect(jobs.first.status, 'pending');
      expect(jobs.first.isActive, isTrue);
      expect(jobs.first.customerName, 'Ada Obi');
    });

    test('demoVehicles include a pickup truck and a van', () {
      final vehicles = MoverService.demoVehicles();
      expect(vehicles, hasLength(2));
      expect(vehicles.first.vehicleType, 'pickup_truck');
      expect(vehicles.last.vehicleType, 'van');
    });
  });
}