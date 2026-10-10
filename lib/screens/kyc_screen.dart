import 'package:flutter/material.dart';

import '../app.dart';
import '../services/auth_service.dart';
import '../services/kyc_service.dart';

/// Complete or view your MarketGO rider verification (KYC).
///
/// Backed by GET/PUT /api/v1/rider/kyc and GET /api/v1/rider/vehicle-types,
/// the same profile the admin reviews in KYCView and that powers the
/// "choose your rider" card (vehicle make/model shown to customers).
class KYCScreen extends StatefulWidget {
  const KYCScreen({super.key, this.service});

  final KYCService? service;

  @override
  State<KYCScreen> createState() => _KYCScreenState();
}

class _KYCScreenState extends State<KYCScreen> {
  late final KYCService _service;

  final _formKey = GlobalKey<FormState>();

  List<RiderVehicleType> _vehicleTypes = const [];
  RiderKYCRecord? _record;
  bool _loading = true;

  bool _saving = false;
  String? _error;

  final _nin = TextEditingController();
  final _license = TextEditingController();
  final _lasrra = TextEditingController();
  final _regNo = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _insurance = TextEditingController();
  final _dob = TextEditingController();
  final _address = TextEditingController();
  int? _vehicleTypeId;

  bool get _live =>
      AuthSession.instance.isAuthenticated &&
      AuthSession.instance.accessToken != 'demo.access';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? KYCService(api: AuthSession.instance.api);
    _load();
  }

  @override
  void dispose() {
    _nin.dispose();
    _license.dispose();
    _lasrra.dispose();
    _regNo.dispose();
    _make.dispose();
    _model.dispose();
    _insurance.dispose();
    _dob.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = AuthSession.instance.accessToken;
    if (!_live || token == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final types = await _service.vehicleTypes(token);
      RiderKYCRecord? record;
      try {
        record = await _service.profile(token);
      } catch (_) {
        // No profile yet is expected on first run.
      }
      if (!mounted) return;
      setState(() {
        _vehicleTypes = types;
        _record = record;
        if (record != null) _populate(record);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _populate(RiderKYCRecord r) {
    _regNo.text = r.vehicleRegNo;
    _make.text = r.vehicleMake;
    _model.text = r.vehicleModel;
    _address.text = r.primaryAddress;
  }

  void _pickType(int? id) {
    setState(() => _vehicleTypeId = id);
  }

  Future<void> _save() async {
    final token = AuthSession.instance.accessToken;
    if (!_live || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sign in to submit your verification.'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.submit(token, {
        'nin': _nin.text.trim(),
        'drivers_license_no': _license.text.trim(),
        'lasrra_permit_no': _lasrra.text.trim(),
        'vehicle_type_id': _vehicleTypeId,
        'vehicle_reg_no': _regNo.text.trim(),
        'vehicle_make': _make.text.trim(),
        'vehicle_model': _model.text.trim(),
        'insurance_no': _insurance.text.trim(),
        'date_of_birth': _dob.text.trim(),
        'address': _address.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Verification submitted. It will be reviewed before '
              'you can accept deliveries.'),
          behavior: SnackBarBehavior.floating));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _StatusBanner(record: _record),
                const SizedBox(height: 16),
                if (_vehicleTypes.isEmpty)
                  const _SectionInfo(
                      text: 'Vehicle categories could not be loaded. '
                          'Check your connection and try again.')
                else ...[
                  for (final t in _vehicleTypes) _vehicleTypeChip(t),
                  const SizedBox(height: 16),
                ],
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: Color(0xFFB91C1C))),
                  ),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _labeled(
                        'NIN number',
                        TextFormField(
                          controller: _nin,
                          keyboardType: TextInputType.number,
                          validator: _required,
                          decoration: _dec('e.g. 12345678901'),
                        ),
                      ),
                      _labeled(
                        "Driver's licence number",
                        TextFormField(
                          controller: _license,
                          validator: _required,
                          decoration: _dec('e.g. ABC1234XYZ'),
                        ),
                      ),
                      _labeled(
                        'LASRRA permit number',
                        TextFormField(
                          controller: _lasrra,
                          validator: _required,
                          decoration: _dec('e.g. LAS-1234-56'),
                        ),
                      ),
                      _labeled(
                        'Vehicle registration number',
                        TextFormField(
                          controller: _regNo,
                          validator: _required,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _dec('e.g. KJA-123XY'),
                        ),
                      ),
                      _labeled(
                        'Vehicle make',
                        TextFormField(
                          controller: _make,
                          validator: _required,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec('e.g. Boxer / Bajaj / Honda'),
                        ),
                      ),
                      _labeled(
                        'Vehicle model',
                        TextFormField(
                          controller: _model,
                          validator: _required,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec('e.g. 150cc / CG125 / RX'),
                        ),
                      ),
                      _labeled(
                        'Insurance number',
                        TextFormField(
                          controller: _insurance,
                          validator: _required,
                          decoration: _dec('e.g. POL-2026-00123'),
                        ),
                      ),
                      _labeled(
                        'Date of birth',
                        TextFormField(
                          controller: _dob,
                          readOnly: true,
                          onTap: _pickDob,
                          decoration: _dec('Tap to pick'),
                        ),
                      ),
                      _labeled(
                        'Home address',
                        TextFormField(
                          controller: _address,
                          validator: _required,
                          minLines: 2,
                          maxLines: 3,
                          decoration: _dec('Street, city, state'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RiderApp.brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Submit verification',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your details are reviewed by the MarketGO team. '
                        'Only verified riders appear as delivery options and '
                        'their vehicle make/model is shown to customers.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: const Color(0xFF9AA1AA)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _vehicleTypeChip(RiderVehicleType t) {
    final selected = _vehicleTypeId == t.id;
    return InkWell(
      onTap: () => _pickType(t.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? RiderApp.brandGreenLight : RiderApp.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? RiderApp.brandGreen : const Color(0xFFE5E7EB),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(_typeIcon(t.name),
                color: selected
                    ? RiderApp.brandGreenDark
                    : const Color(0xFF9AA1AA)),
            const SizedBox(width: 10),
            Text(t.label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? RiderApp.brandGreenDark
                        : Theme.of(context).colorScheme.onSurface)),
            if (selected)
              const Spacer(),
            if (selected)
              Icon(Icons.check_circle, color: RiderApp.brandGreen, size: 20),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String name) {
    switch (name) {
      case 'bike':
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'car':
      case 'sedan':
        return Icons.directions_car;
      case 'van':
        return Icons.local_shipping;
      case 'truck':
      case 'pickup_truck':
      case 'lorry':
        return Icons.fire_truck;
      default:
        return Icons.directions_bike;
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 80, now.month, now.day),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() =>
          _dob.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: RiderApp.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: RiderApp.brandGreen),
        ),
      );

  Widget _labeled(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 6),
          field,
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({this.record});

  final RiderKYCRecord? record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    if (r == null || r.isEmpty) {
      return const _SectionInfo(
        text: 'Complete your verification to start receiving delivery '
            'requests. Customers choose verified riders when sending a parcel.',
      );
    }
    final (Color, IconData, String, String) t;
    if (r.isApproved) {
      t = (const Color(0xFF15803D), Icons.verified, 'Verified',
          'Your profile is approved. You can accept deliveries.');
    } else if (r.isRejected) {
      t = (const Color(0xFFB91C1C), Icons.gpp_bad, 'Rejected',
          'Your verification was rejected. Update your details to re-submit.');
    } else {
      t = (const Color(0xFFB45309), Icons.hourglass_top, 'Under review',
          'Your verification is being reviewed by the MarketGO team.');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.$1.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.$1.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(t.$2, color: t.$1, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.vehicleMake.isEmpty ? '' : '${r.vehicleMake} ${r.vehicleModel} · '}${t.$3}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(t.$4,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionInfo extends StatelessWidget {
  const _SectionInfo({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: RiderApp.brandGreenDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}