import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'photos.dart';

/// Kész háttértémák a programokhoz: színátmenet és egy halvány minta-emoji.
class BackgroundTheme {
  const BackgroundTheme(this.key, this.label, this.emoji, this.colors);

  final String key;
  final String label;
  final String emoji;
  final List<Color> colors;
}

const backgroundThemes = [
  BackgroundTheme('party', 'Buli', '🎉', [Color(0xFF7B2FF7), Color(0xFFF107A3)]),
  BackgroundTheme('beach', 'Strand', '🏖️', [Color(0xFF00B4DB), Color(0xFFFFD86F)]),
  BackgroundTheme('night', 'Este', '🌙', [Color(0xFF141E30), Color(0xFF243B55)]),
  BackgroundTheme('forest', 'Erdő', '🌲', [Color(0xFF134E5E), Color(0xFF71B280)]),
  BackgroundTheme('sunset', 'Naplemente', '🌅', [Color(0xFFFF512F), Color(0xFFF09819)]),
  BackgroundTheme('snow', 'Tél', '❄️', [Color(0xFF83A4D4), Color(0xFFB6FBFF)]),
  BackgroundTheme('food', 'Kaja', '🍕', [Color(0xFFE53935), Color(0xFFFFA000)]),
  BackgroundTheme('sport', 'Sport', '⚽', [Color(0xFF11998E), Color(0xFF38EF7D)]),
];

BackgroundTheme? themeFor(String? key) => backgroundThemes.where((t) => t.key == key).firstOrNull;

/// Saját háttérfotó: legfeljebb 1000 px széles JPEG, hogy a program adataival együtt
/// gyorsan menjen a felhőbe és a meghívottakhoz is.
class EventBackgrounds {
  static Future<String?> pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1200, maxHeight: 1200);
    if (picked == null) return null;
    return encode(await picked.readAsBytes());
  }

  static String? encode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final resized = decoded.width > 1000 ? img.copyResize(decoded, width: 1000) : decoded;
    return base64Encode(img.encodeJpg(resized, quality: 70));
  }
}

/// Program fejléc a háttérrel (téma vagy saját fotó), sötétítve, hogy a szöveg olvasható legyen.
class EventBackdrop extends StatelessWidget {
  const EventBackdrop({super.key, this.theme, this.image, required this.child, this.radius = 24});

  final String? theme;
  final String? image;
  final Widget child;
  final double radius;

  bool get hasBackground => image != null || themeFor(theme) != null;

  @override
  Widget build(BuildContext context) {
    final t = themeFor(theme);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: image != null
                ? Image.memory(TagImages.decode(image!), fit: BoxFit.cover, gaplessPlayback: true)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: t?.colors ?? const [Color(0xFF6D5BD6), Color(0xFFFF9A8B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: t == null
                        ? null
                        : Align(
                            alignment: const Alignment(0.95, 0.2),
                            child: Opacity(opacity: 0.25, child: Text(t.emoji, style: const TextStyle(fontSize: 110))),
                          ),
                  ),
          ),
          // Alul sötétebb, hogy a fehér szöveg mindenhol olvasható legyen.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
