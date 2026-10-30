import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

/// Budapest, ha még nincs kiválasztott hely.
const defaultCenter = LatLng(47.4979, 19.0402);

const _userAgent = 'hu.eletrend.eletrend';

TileLayer osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: _userAgent,
    );

Marker pinMarker(LatLng point) => Marker(
      point: point,
      width: 48,
      height: 48,
      alignment: Alignment.topCenter,
      child: Icon(Icons.location_on, size: 48, color: AppColors.accent, shadows: [
        Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
      ]),
    );

/// Kis, nem görgethető térképkép egy ponttal (pl. program részleteinél).
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.point, this.height = 160, this.onTap});

  final LatLng point;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey(point),
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                osmTiles(),
                MarkerLayer(markers: [pinMarker(point)]),
              ],
            ),
            if (onTap != null) Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: onTap))),
          ],
        ),
      ),
    );
  }
}
