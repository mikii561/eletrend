import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Széles képernyőn (pl. böngészőben) telefon méretű keretbe teszi az appot,
/// hogy ugyanúgy nézzen ki, mint a telefonon. Telefonon nem csinál semmit.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const _phoneSize = Size(400, 860);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < 600) return child;

    final height = math.min(_phoneSize.height, media.size.height - 48);
    final size = Size(_phoneSize.width, height);

    return ColoredBox(
      color: const Color(0xFF1E1B2E),
      child: Center(
        child: Container(
          width: size.width + 16,
          height: size.height + 16,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(52),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 20))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: MediaQuery(
              data: media.copyWith(
                size: size,
                padding: const EdgeInsets.only(top: 24),
                viewPadding: const EdgeInsets.only(top: 24),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
