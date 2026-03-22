import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

/// Opens the native image cropper after a photo is picked.
/// Returns the cropped file path, or null if cancelled.
Future<String?> cropPhoto(String sourcePath, {BuildContext? context}) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Adjust Photo',
        toolbarColor: const Color(0xFF111C2D),
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: const Color(0xFFFF6B9D),
        backgroundColor: Colors.black,
        hideBottomControls: false,
        showCropGrid: false,
        aspectRatioPresets: [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9,
        ],
        initAspectRatio: CropAspectRatioPreset.original,
        lockAspectRatio: false,
      ),
      IOSUiSettings(
        title: 'Adjust Photo',
        aspectRatioPresets: [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio4x3,
        ],
      ),
    ],
  );
  return cropped?.path;
}
