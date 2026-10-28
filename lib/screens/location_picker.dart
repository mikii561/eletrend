import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../geocoding.dart';
import '../theme.dart';
import '../widgets/map_view.dart';

/// Teljes képernyős térkép: kereséssel vagy koppintással lehet helyet választani.
/// Visszatérési értéke a kiválasztott [Place].
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, this.initial});

  final Place? initial;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _map = MapController();
  final _search = TextEditingController();
  late Place? _picked = widget.initial;
  List<Place> _results = [];
  bool _loading = false;
  int _reverseToken = 0;

  Future<void> _runSearch(String q) async {
    if (q.trim().length < 3) return;
    setState(() => _loading = true);
    try {
      final results = await Geocoding.search(q.trim());
      if (mounted) setState(() => _results = results);
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectResult(Place p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _picked = p;
      _results = [];
    });
    _map.move(p.point, 16);
  }

  Future<void> _onMapTap(LatLng point) async {
    FocusScope.of(context).unfocus();
    final token = ++_reverseToken;
    setState(() {
      _results = [];
      _picked = Place(name: 'Cím keresése…', point: point);
    });
    String? name;
    try {
      name = await Geocoding.reverse(point);
    } catch (_) {
      _showError();
    }
    // Ha közben máshova koppintott, a régi választ eldobjuk.
    if (!mounted || token != _reverseToken) return;
    setState(() => _picked = Place(name: name ?? 'Kiválasztott hely', point: point));
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nem sikerült elérni a térképszolgáltatást. Van internet?')),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: picked?.point ?? defaultCenter,
              initialZoom: picked == null ? 12 : 16,
              onTap: (_, point) => _onMapTap(point),
            ),
            children: [
              osmTiles(),
              if (picked != null) MarkerLayer(markers: [pinMarker(picked.point)]),
              const SimpleAttributionWidget(source: Text('OpenStreetMap')),
            ],
          ),

          // Keresősáv
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Material(
                    elevation: 4,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                        Expanded(
                          child: TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _runSearch,
                            decoration: const InputDecoration(
                              hintText: 'Hely vagy cím keresése',
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        _loading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : IconButton(icon: const Icon(Icons.search), onPressed: () => _runSearch(_search.text)),
                      ],
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Card(
                      margin: const EdgeInsets.only(top: 8),
                      elevation: 4,
                      shadowColor: Colors.black26,
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            for (final r in _results)
                              ListTile(
                                leading: const Icon(Icons.place_outlined),
                                title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                onTap: () => _selectResult(r),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Kiválasztott hely
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: Material(
                elevation: 6,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(24),
                color: AppColors.card,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: picked == null
                      ? Row(
                          children: [
                            Icon(Icons.touch_app_outlined, color: AppColors.textMuted),
                            SizedBox(width: 12),
                            Expanded(child: Text('Keress rá egy helyre, vagy koppints a térképre.')),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: AppColors.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(picked.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.titleMedium),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, picked),
                              child: const Text('Ez lesz a helyszín'),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
