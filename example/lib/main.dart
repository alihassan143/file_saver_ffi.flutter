import 'package:file_saver_ffi/file_saver_ffi.dart';
import 'package:flutter/material.dart';

import 'screens/screens.dart';

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
      home: const FileSaverDemoPage(),
    );
  }
}

class FileSaverDemoPage extends StatelessWidget {
  const FileSaverDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('File Saver FFI Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.memory), text: 'Save Bytes'),
              Tab(icon: Icon(Icons.file_open), text: 'Save File'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SaveBytesScreen(),
            SaveFileScreen(),
          ],
        ),
      ),
    );
  }
}
