import 'dart:async';

import 'package:flutter/material.dart';

import '../services/maps_service.dart';
import 'map_preview.dart';

/// Address locator field: free-text input with debounced address suggestions
/// from the backend `/api/v1/search/places` proxy and a live map preview that
/// appears once the user picks a suggestion.
///
/// Uses a [TextFormField] when [inForm] is true (so enclosing `Form`
/// validators still run), otherwise a plain [TextField]. Falls back to a bare
/// text input when maps are disabled or search is unavailable.
class PlaceSearchField extends StatefulWidget {
  const PlaceSearchField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.textInputAction,
    this.inForm = false,
    this.showMap = true,
    this.autoValidateMode,
    this.onLocationChanged,
    this.service,
    this.height = 160,
  });

  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final bool inForm;
  final bool showMap;
  final AutovalidateMode? autoValidateMode;
  final ValueChanged<PlaceSuggestion?>? onLocationChanged;
  final MapsService? service;
  final double height;

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  late final MapsService _service;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _open = false;
  bool _configLoaded = false;
  MapConfig _config = const MapConfig();
  PlaceSuggestion? _pick;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MapsService();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureConfig() async {
    if (_configLoaded) return;
    _config = await _service.fetchConfig();
    if (mounted) {
      setState(() => _configLoaded = true);
      _search(immediate: true);
    }
  }

  void _onFieldChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _clearPick();
    }
    _search(immediate: false);
  }

  void _search({required bool immediate}) {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _open = false;
        _searching = false;
      });
      return;
    }
    _ensureConfig();
    void run() async {
      if (!mounted) return;
      setState(() => _searching = true);
      final results = await _service.searchPlaces(query);
      if (!mounted) return;
      if (_controller.text.trim() != query) return;
      setState(() {
        _searching = false;
        _suggestions = results;
        _open = results.isNotEmpty;
      });
    }

    if (immediate) {
      run();
    } else {
      _debounce = Timer(const Duration(milliseconds: 350), run);
    }
  }

  void _select(PlaceSuggestion s) {
    _debounce?.cancel();
    _focusNode.unfocus();
    setState(() {
      _pick = s;
      _suggestions = const [];
      _open = false;
    });
    _controller.text = s.label;
    widget.onLocationChanged?.call(s);
  }

  void _clearPick() {
    if (_pick == null) return;
    setState(() => _pick = null);
    widget.onLocationChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (_open) _buildSuggestions(),
        if (_pick != null && widget.showMap)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: MapPreview(
              config: _config,
              latitude: _pick!.latitude,
              longitude: _pick!.longitude,
              height: widget.height,
              placeholder: const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  Widget _buildField() {
    final decoration = InputDecoration(
      labelText: widget.labelText,
      hintText: widget.hintText,
      prefixIcon: widget.prefixIcon,
    );
    if (widget.inForm) {
      return TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        validator: widget.validator,
        textInputAction: widget.textInputAction,
        autovalidateMode: widget.autoValidateMode,
        onChanged: _onFieldChanged,
        decoration: decoration,
      );
    }
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textInputAction: widget.textInputAction,
      onChanged: _onFieldChanged,
      decoration: decoration,
    );
  }

  Widget _buildSuggestions() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final s in _suggestions)
            InkWell(
              onTap: () => _select(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}