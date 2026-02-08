import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermHelper {
  PermHelper._();

  static Future<bool> isGrantedPermWritePhotos() async {
    if (Platform.isIOS) {
      // final status = await Permission.photosAddOnly.status;
      // if (!status.isGranted) {
      //   final status = await Permission.photosAddOnly.request();
      //   return status.isGranted;
      // }
      return true;
    }

    if (Platform.isAndroid) {
      return isGrantedPermAndroidWriteExternalStorage();
    }

    return false;
  }

  static Future<bool> isGrantedPermWriteExternalStorage() async {
    if (Platform.isIOS) {
      return true;
    }

    if (Platform.isAndroid) {
      return isGrantedPermAndroidWriteExternalStorage();
    }

    return false;
  }

  static Future<bool> isGrantedPermAndroidWriteExternalStorage() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt > 28) {
      return true;
    }

    final status = await Permission.storage.status;
    if (status.isGranted) {
      return true;
    }

    return await Permission.storage.request().isGranted;
  }
}
