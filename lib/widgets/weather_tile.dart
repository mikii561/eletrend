import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../weather.dart';

/// Időjárás a program idejére, ha a helyszín ismert és nincs túl messze az időpont.
class WeatherTile extends StatefulWidget {
  const WeatherTile({super.key, required this.lat, required this.lng, required this.at});

  final double lat;
  final double lng;
  final DateTime at;

  @override
  State<WeatherTile> createState() => _WeatherTileState();
}

class _WeatherTileState extends State<WeatherTile> {
  late final Future<Forecast?> _forecast = Forecast.fetch(widget.lat, widget.lng, widget.at);

  @override
  Widget build(BuildContext context) {
    if (!Forecast.available(widget.at)) return const SizedBox.shrink();
    return FutureBuilder<Forecast?>(
      future: _forecast,
      builder: (context, snap) {
        final f = snap.data;
        if (f == null) return const SizedBox.shrink();
        return ListTile(
          leading: Text(f.emoji, style: const TextStyle(fontSize: 26)),
          title: Text(f.text, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Előrejelzés: ${DateFormat('EEEE HH:mm', 'hu').format(widget.at)}'),
        );
      },
    );
  }
}
