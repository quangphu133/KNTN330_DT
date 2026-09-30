import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_messenger.dart';
import 'core/theme.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(const ProviderScope(child: HuitApp()));
}

class HuitApp extends ConsumerWidget {
  const HuitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'HUIT',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: HuitTheme.light,
      routerConfig: router,
    );
  }
}
