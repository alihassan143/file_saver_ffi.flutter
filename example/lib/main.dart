import 'package:file_saver_ffi/file_saver_ffi.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class AppLifecycleStateObserver extends WidgetsBindingObserver {
  final void Function()? onDetached;

  AppLifecycleStateObserver({this.onDetached});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      onDetached?.call();
    }
  }
}

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.addObserver(
    AppLifecycleStateObserver(onDetached: FileSaver.instance.dispose),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Saver FFI Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
