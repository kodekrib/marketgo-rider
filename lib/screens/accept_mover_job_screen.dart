import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart';
import '../services/mover_service.dart';

/// Accept a moving job by quoting your price and per-packer fee.
class AcceptMoverJobScreen extends StatefulWidget {
  const AcceptMoverJobScreen({
    super.key,
    required this.service,
    required this.job,
    required this.onAccepted,
  });

  final MoverService service;
  final MoverJob job;
  final VoidCallback onAccepted;

  @override
  State<AcceptMoverJobScreen> createState() => _AcceptMoverJobScreenState();
}

class _AcceptMoverJobScreenState extends State<AcceptMoverJobScreen> {
  late final TextEditingController _price;
  late final TextEditingController _packerPrice;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: '30000');
    _packerPrice = TextEditingController(
        text: widget.job.packerPrice > 0 ? '${widget.job.packerPrice}' : '5000');
  }

  @override
  void dispose() {
    _price.dispose();
    _packerPrice.dispose();
    super.dispose();
  }

  double get _quote => double.tryParse(_price.text) ?? 0;
  double get _packer => double.tryParse(_packerPrice.text) ?? 0;

  double get _estimatedPackerFee => widget.job.extraPackers * _packer;
  double get _estimatedPlatformFee => (_quote + _estimatedPackerFee) * 0.08;
  double get _estimatedTotal => _quote + _estimatedPackerFee + _estimatedPlatformFee;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_quote <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Enter a quote above ${RiderApp.currencySymbol}0.'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    final token = AuthSession.instance.accessToken ?? '';
    if (token == 'demo.access') {
      widget.onAccepted();
      Navigator.of(context).pop();
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.service.accept(token, widget.job.id,
          price: _quote, packerPrice: _packer);
      if (!mounted) return;
      widget.onAccepted();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not accept: $e'),
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quote this move')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _JobHeader(job: widget.job),
              const SizedBox(height: 24),
              Text('Your quote',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quote price (${RiderApp.currencySymbol})',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _packerPrice,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Packer price per person (${RiderApp.currencySymbol})',
                  prefixIcon: const Icon(Icons.groups_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.job.extraPackers > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'This move requests ${widget.job.extraPackers} '
                  'extra packer(s). One is included free.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 24),
              _Breakdown(
                mover: _quote,
                packers: _estimatedPackerFee,
                platform: _estimatedPlatformFee,
                total: _estimatedTotal,
                platformRate: '8%',
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
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobHeader extends StatelessWidget {
  const _JobHeader({required this.job});

  final MoverJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RiderApp.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trip_origin_rounded,
                  color: RiderApp.brandGreenDark, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(job.pickupAddress,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.only(left: 9),
            height: 18,
            width: 2,
            color: const Color(0xFFE2E5EA),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(job.deliveryAddress,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _Chip(
                  icon: Icons.sailing_outlined,
                  label: moverVehicleLabel(job.vehicleType)),
              _Chip(
                  icon: Icons.inventory_2_outlined,
                  label: '${job.itemCount} items'),
              _Chip(
                  icon: Icons.groups_outlined,
                  label: '${job.extraPackers} extra packers'),
            ],
          ),
          const SizedBox(height: 10),
          Text('Customer: ${job.customerName}',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
          if (job.description.isNotEmpty)
            Text(job.description,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RiderApp.brandGreenLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: RiderApp.brandGreenDark),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.mover,
    required this.packers,
    required this.platform,
    required this.total,
    required this.platformRate,
  });

  final double mover;
  final double packers;
  final double platform;
  final double total;
  final String platformRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _line('Your mover fee', _naira(mover)),
          _line('Packers + platform fee',
              '${_naira(packers)} + ${_naira(platform)}'),
          const Divider(height: 18),
          Row(
            children: [
              const Text('Customer pays',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Text(_naira(total),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5B616A))),
          const Spacer(),
          Text(amount,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
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