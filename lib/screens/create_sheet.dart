import 'package:flutter/material.dart';

import '../theme.dart';
import 'challenges_screen.dart';
import 'event_editor.dart';
import 'google_calendar_screen.dart';
import 'find_time_screen.dart';
import 'habit_editor.dart';
import 'task_editor.dart';

/// A „Létrehozás” gomb menüje: minden új dolog egy helyről.
Future<void> showCreateSheet(BuildContext context) {
  final navigator = Navigator.of(context);
  void open(Widget page) => navigator.push(MaterialPageRoute(builder: (_) => page));
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      Widget item(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) => ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withValues(alpha: AppColors.dark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(Space.radiusSmall),
          ),
          child: Icon(icon, color: color ?? AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        onTap: () {
          navigator.pop();
          onTap();
        },
      );
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(
                Icons.event_outlined,
                'Bejegyzés',
                'Saját program, időpont, emlékeztető',
                () => open(const EventEditor()),
              ),
              item(
                Icons.add_task,
                'Feladat',
                'Teendő határidővel, beosztható a naptárba',
                () => showTaskEditor(navigator.context, due: DateTime.now()),
              ),
              item(
                Icons.celebration_outlined,
                'Közös program',
                'Barátok meghívása, visszajelzés, hozzászólások',
                () => open(const EventEditor(social: true)),
              ),
              item(
                Icons.event_available_outlined,
                'Közös időpont keresése',
                'Mikor ér rá mindenki?',
                () => open(const FindTimeScreen()),
              ),
              item(
                Icons.flag_outlined,
                'Cél',
                'Pl. hetente 3× edzés, napi 20 oldal',
                () => showHabitEditor(navigator.context),
              ),
              item(
                Icons.emoji_events_outlined,
                'Kihívás',
                'Közös cél a barátaiddal',
                () => open(const ChallengesScreen()),
              ),
              item(
                Icons.add_link,
                'Google Naptár hozzáadása',
                'Az eseményeid átjönnek ide is',
                () => open(const GoogleCalendarScreen()),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
