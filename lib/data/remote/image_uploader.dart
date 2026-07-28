import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Minimum source size enforced so photos read cleanly on the sales app's
/// full-screen 16:9 slideshow instead of looking stretched or pixelated.
const _minWidth = 1920;
const _minHeight = 1200;

class ImagePickResult {
  const ImagePickResult({this.bytes, this.error});

  /// Null if the user cancelled the picker (no error) or the pick/crop
  /// failed validation (see [error]).
  final Uint8List? bytes;
  final String? error;

  bool get wasCancelled => bytes == null && error == null;
}

/// Picks, validates, and uploads photos for both product and employee
/// records — the same 16:9/1920x1200 quality bar applies to anything shown
/// full-screen in the sales app, so this isn't product-specific.
class ImageUploader {
  ImageUploader({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<ImagePickResult> pickImage() async {
    debugPrint('ImageUploader.pickImage: opening gallery image picker');
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      debugPrint('ImageUploader.pickImage: picker cancelled');
      return const ImagePickResult();
    }

    var bytes = await File(pickedFile.path).readAsBytes();
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      debugPrint('ImageUploader.pickImage: decoded image is invalid');
      return const ImagePickResult(error: "That file isn't a valid image.");
    }

    final pickedAspectRatio = decoded.width / decoded.height;
    final needsCrop =
        decoded.width < _minWidth || decoded.height < _minHeight || (pickedAspectRatio - (16 / 9)).abs() > 0.01;
    debugPrint(
        'ImageUploader.pickImage: picked image width=${decoded.width} height=${decoded.height} needsCrop=$needsCrop');
    if (needsCrop) {
      debugPrint('ImageUploader.pickImage: launching cropper for 16:9 crop');
      final cropped = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true,
          ),
          IOSUiSettings(aspectRatioLockEnabled: true),
        ],
      );
      if (cropped == null) {
        debugPrint('ImageUploader.pickImage: cropper cancelled');
        return const ImagePickResult(error: 'Image cropping was canceled.');
      }
      bytes = await File(cropped.path).readAsBytes();
      decoded = img.decodeImage(bytes);
      final aspectRatio = decoded == null ? 0.0 : decoded.width / decoded.height;
      if (decoded == null || (aspectRatio - (16 / 9)).abs() > 0.01) {
        debugPrint('ImageUploader.pickImage: cropped image failed validation');
        return const ImagePickResult(error: 'Cropped image must be 16:9 and at least 1920x1200.');
      }
    }

    debugPrint('ImageUploader.pickImage: image ready, byteLength=${bytes.length}');
    return ImagePickResult(bytes: bytes);
  }

  Future<String> upload(Uint8List bytes, {required String folder}) async {
    final filename = '${const Uuid().v4()}.jpg';
    debugPrint('ImageUploader.upload: uploading to folder=$folder filename=$filename byteLength=${bytes.length}');
    final ref = _storage.ref().child(folder).child(filename);
    await ref.putData(bytes);
    final url = await ref.getDownloadURL();
    debugPrint('ImageUploader.upload: upload succeeded folder=$folder filename=$filename');
    return url;
  }
}
