import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';

class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.radius = 17});
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(usernameProvider).value;
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.tertiaryContainer,
      foregroundColor: scheme.onTertiaryContainer,
      child: name == null || name.isEmpty
          ? Icon(Icons.person, size: radius)
          : Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.9,
              ),
            ),
    );
  }
}

class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Profile',
    onPressed: () => context.push('/profile'),
    icon: const UserAvatar(),
  );
}
