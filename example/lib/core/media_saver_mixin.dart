import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'utils.dart';

/// Mixin providing common state and methods for media saving tabs
mixin MediaSaverStateMixin<T extends StatefulWidget> on State<T> {
  bool isLoading = false;
  String? savedFilePath;
  double progress = 0.0;
  int mediaSize = 0;
}
