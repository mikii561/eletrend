import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';

/// Pár cél, amivel könnyű elkezdeni.
const suggestedHabits = [
  '💧 2 liter víz',
  '🚶 10 perc séta',
  '📖 10 perc olvasás',
  '🧘 5 perc meditáció',
  '🍎 Gyümölcs vagy zöldség',
  '😴 Lefekvés éjfél előtt',
  '📵 Telefonmentes este',
  '🏋️ Edzés',
];

/// Bemutató az első indításkor: mit tud az app, és pár ajánlott cél.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  final Set<String> _picked = {suggestedHabits[0], suggestedHabits[1]};

  static const _intro = [
    ('🌿', 'Üdv az Életrendben!', 'Egy helyen a céljaid, a hangulatod és a programjaid a barátaiddal.'),
    (
      '📔',
      'Napló és hangulat',
      'Esténként egy perc: milyen napod volt, és miért vagy hálás. A statisztika megmutatja, mi tesz jót neked.',
    ),
  ];

  void _finish() {
    StoreScope.of(context).finishOnboarding(
      habits: [
        for (final h in suggestedHabits)
          if (_picked.contains(h)) h,
      ],
    );
  }

  void _next() => _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _intro.length;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: last ? null : () => StoreScope.of(context).finishOnboarding(),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: Text(last ? '' : 'Kihagyás'),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final (emoji, title, text) in _intro) _IntroPage(emoji: emoji, title: title, text: text),
                    _HabitPicker(
                      picked: _picked,
                      onToggle: (h) => setState(() => _picked.contains(h) ? _picked.remove(h) : _picked.add(h)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i <= _intro.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                  onPressed: last ? _finish : _next,
                  child: Text(
                    last ? (_picked.isEmpty ? 'Kezdjük!' : 'Kezdjük ${_picked.length} céllal!') : 'Tovább',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.emoji, required this.title, required this.text});

  final String emoji;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    // Alacsony képernyőn görgethető, egyébként középre igazított.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 96)),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitPicker extends StatelessWidget {
  const _HabitPicker({required this.picked, required this.onToggle});

  final Set<String> picked;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            'Mivel kezdenél?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Koppints azokra a célokra, amiket követni szeretnél. Később bármikor módosíthatod.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in suggestedHabits)
                _HabitChip(label: h, selected: picked.contains(h), onTap: () => onToggle(h)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ajánlott cél a színátmenetes háttéren: kiválasztva fehér, egyébként áttetsző.
class _HabitChip extends StatelessWidget {
  const _HabitChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: selected ? 1 : 0.55), width: 1.5),
          ),
          child: Text(
            selected ? '✓ $label' : label,
            style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppColors.primary : Colors.white),
          ),
        ),
      ),
    );
  }
}
