import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart';
import '../services/mover_service.dart';

/// Manage the rider's registered heavy-moving vehicles.
class MoverVehiclesScreen extends StatefulWidget {
  const MoverVehiclesScreen({super.key, required this.service});

  final MoverService service;

  @override
  State<MoverVehiclesScreen> createState() => _MoverVehiclesScreenState();
}

class _MoverVehiclesScreenState extends State<MoverVehiclesScreen> {
  List<MoverVehicle>? _vehicles;
  bool _loading = false;

  bool get _live =>
      AuthSession.instance.isAuthenticated &&
      AuthSession.instance.accessToken != 'demo.access';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.instance.accessToken;
    if (!_live) {
      setState(() => _vehicles = MoverService.demoVehicles());
      return;
    }
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final vs = await widget.service.vehicles(token);
      if (!mounted) return;
      setState(() {
        _vehicles = vs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => _AddVehicleScreen(service: widget.service)));
    if (created == true) _load();
  }

  Future<void> _delete(MoverVehicle v) async {
    final token = AuthSession.instance.accessToken;
    if (!_live || token == null) {
      setState(() => _vehicles?.removeWhere((x) => x.id == v.id));
      return;
    }
    try {
      await widget.service.deleteVehicle(token, v.id);
      if (!mounted) return;
      setState(() => _vehicles?.removeWhere((x) => x.id == v.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not delete: $e'),
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = _vehicles;
    return Scaffold(
      appBar: AppBar(title: const Text('My vehicles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: RiderApp.brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add vehicle'),
      ),
      body: _loading && vehicles == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: [
                if (vehicles == null || vehicles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 80),
                    child: Column(
                      children: [
                        const Icon(Icons.fire_truck_outlined,
                            size: 48, color: Color(0xFF9AA1AA)),
                        const SizedBox(height: 16),
                        Text('No vehicles registered',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                            'Add a pickup truck, van, mini truck or lorry to '
                            'start receiving moving jobs.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )
                else
                  for (final v in vehicles) _VehicleCard(vehicle: v, onDelete: () => _delete(v)),
                const SizedBox(height: 12),
                Text(
                  'Registered vehicles appear on your mover profile. '
                  'Packers earn a fee for each move you bring along.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onDelete});

  final MoverVehicle vehicle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RiderApp.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: RiderApp.brandGreenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fire_truck_outlined,
                    color: RiderApp.brandGreenDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.vehicleLabel,
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (vehicle.color.isNotEmpty)
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color:
                                  _parseColor(vehicle.color) ?? RiderApp.ink,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFE2E5EA)),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            ([
                              if (vehicle.registrationNumber.isNotEmpty)
                                vehicle.registrationNumber,
                              if (vehicle.capacity.isNotEmpty)
                                vehicle.capacity,
                            ]).join(' · '),
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete vehicle?'),
                    content: Text(
                        '${vehicle.vehicleLabel} '
                        '${vehicle.registrationNumber} will be removed from your mover profile.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Keep'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete',
                            style: TextStyle(color: Color(0xFFDC2626))),
                      ),
                    ],
                  ),
                ).then((ok) {
                  if (ok == true) onDelete();
                }),
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFDC2626), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _tag(Icons.groups_outlined,
                  'Packer fee ${_naira(vehicle.packerPrice)}/person'),
              if (vehicle.maxPackers > 0)
                _tag(Icons.groups,
                    'Up to ${vehicle.maxPackers} packers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: RiderApp.brandGreenLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: RiderApp.brandGreenDark),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AddVehicleScreen extends StatefulWidget {
  const _AddVehicleScreen({required this.service});

  final MoverService service;

  @override
  State<_AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<_AddVehicleScreen> {
  static const _colors = [
    '#111418',
    '#2563EB',
    '#16A34A',
    '#DC2626',
    '#D97706',
    '#7C3AED',
  ];

  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _regController = TextEditingController();
  final _capacityController = TextEditingController();
  final _packerController = TextEditingController(text: '5000');
  List<String> _vehicleTypes = moverVehicleTypes;
  String _vehicleType = 'pickup_truck';
  String _color = _colors.first;
  int _maxPackers = 2;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    final token = AuthSession.instance.accessToken;
    if (token == null || token == 'demo.access') return;
    try {
      final types = await widget.service.vehicleTypes(token);
      if (!mounted || types.isEmpty) return;
      setState(() {
        _vehicleTypes = types.map((t) => t.name).toList();
        if (!_vehicleTypes.contains(_vehicleType)) {
          _vehicleType = _vehicleTypes.first;
        }
      });
    } catch (_) {
      // Fall back to the built-in list.
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _regController.dispose();
    _capacityController.dispose();
    _packerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = AuthSession.instance.accessToken ?? '';
    if (_regController.text.trim().isEmpty) {
      _snack('Enter the registration number.');
      return;
    }
    if (token == 'demo.access') {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.service.createVehicle(
        token,
        vehicleType: _vehicleType,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        color: _color,
        registrationNumber: _regController.text.trim(),
        capacity: _capacityController.text.trim(),
        packerPrice: double.tryParse(_packerController.text) ?? 0,
        maxPackers: _maxPackers,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('Could not add vehicle: $e');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add vehicle')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Vehicle type',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _vehicleTypes.map((t) {
                  final selected = _vehicleType == t;
                  return InkWell(
                    onTap: () => setState(() => _vehicleType = t),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? RiderApp.brandGreen : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? RiderApp.brandGreen
                              : const Color(0xFFE2E5EA),
                        ),
                      ),
                      child: Text(
                        moverVehicleLabel(t),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color:
                              selected ? Colors.white : RiderApp.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _brandController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  hintText: 'e.g. Toyota',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _modelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Model (optional)',
                  hintText: 'e.g. Hilux / Hiace',
                  prefixIcon: Icon(Icons.car_rental_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _regController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Registration number',
                  hintText: 'e.g. LAG-560-JKK',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Text('Colour',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: _colors.map((c) {
                  final selected = _color == c;
                  final parsed = _parseColor(c) ?? RiderApp.ink;
                  return InkWell(
                    onTap: () => setState(() => _color = c),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: parsed,
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: selected ? 3 : 1,
                          color: selected
                              ? RiderApp.brandGreenDark
                              : const Color(0xFFE2E5EA),
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Capacity (optional)',
                  hintText: 'e.g. 2 tons / 12 chairs',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _packerController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Packer fee per person (${RiderApp.currencySymbol})',
                  prefixIcon: const Icon(Icons.groups_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Max extra packers',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15)),
                  ),
                  _StepBtn(
                    icon: Icons.remove_rounded,
                    enabled: _maxPackers > 0,
                    onTap: () => setState(() => _maxPackers--),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('$_maxPackers',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  _StepBtn(
                    icon: Icons.add_rounded,
                    enabled: _maxPackers < 20,
                    onTap: () => setState(() => _maxPackers++),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.6, color: Colors.white),
                        )
                      : const Text('Save vehicle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color? _parseColor(String hex) {
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  final code = int.tryParse(value, radix: 16);
  if (code == null) return null;
  return Color(code);
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? RiderApp.brandGreenLight
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 19,
            color: enabled ? RiderApp.brandGreenDark : const Color(0xFFC9CDD4)),
      ),
    );
  }
}

String _naira(double value) {
  final n = value.round().toString();
  final formatted = n.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '${RiderApp.currencySymbol}$formatted';
}