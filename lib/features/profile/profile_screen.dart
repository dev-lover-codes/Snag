import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/env.dart';
import '../common/common_widgets.dart';
import 'profile_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message:
          'Your items stay safe in the cloud. Everything cached on this '
          'device — items, drafts and files — will be removed.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _loggingOut = true);
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseProvider).auth.currentUser;
    final username = ref.watch(usernameProvider);
    final count = ref.watch(allItemsProvider).value?.length ?? 0;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          const Center(child: UserAvatar(radius: 44)),
          const SizedBox(height: 12),
          Center(
            child: username.when(
              data: (u) => Text(
                u == null ? '—' : '@$u',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              loading: () => const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => const Text('—'),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '$count saved item${count == 1 ? '' : 's'}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('Username'),
            subtitle: Text(username.value ?? '—'),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Email'),
            subtitle: Text(user?.email ?? '—'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App version'),
            subtitle: Text('Snag ${Env.appVersion}'),
          ),
          const Divider(height: 32),
          ListTile(
            leading: _loggingOut
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.logout, color: scheme.error),
            title: Text('Log out', style: TextStyle(color: scheme.error)),
            onTap: _loggingOut ? null : _logout,
          ),
        ],
      ),
    );
  }
}
