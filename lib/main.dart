import 'package:flutter/material.dart';

import 'services/app_store.dart';
import 'services/listen_controller.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  final controller = ListenController(store);
  runApp(EarSightApp(store: store, controller: controller));
}

class EarSightApp extends StatelessWidget {
  const EarSightApp({super.key, required this.store, required this.controller});

  final AppStore store;
  final ListenController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0));
    return MaterialApp(
      title: 'EarSight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
      ),
      home: HomeScreen(store: store, controller: controller),
    );
  }
}
