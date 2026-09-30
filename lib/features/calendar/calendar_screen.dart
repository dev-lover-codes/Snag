import 'package:flutter/material.dart';

import '../common/common_widgets.dart';
import '../profile/profile_avatar.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Calendar'),
      actions: const [ProfileAvatarButton(), SizedBox(width: 8)],
    ),
    body: const ComingSoon(
      icon: Icons.event_outlined,
      message: 'Plan your events and get reminders here.',
    ),
  );
}
