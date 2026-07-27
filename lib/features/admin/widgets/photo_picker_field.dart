import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/error/user_facing_error.dart';
import '../../../data/remote/image_uploader.dart';

/// Pick, validate, and upload a photo, showing a live preview throughout.
/// Uploads immediately on pick (matching how this worked before the merge)
/// rather than deferring to the form's Save button — simpler state to
/// reason about, at the cost of an orphaned Storage file if the form is
/// abandoned after a successful pick.
class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    super.key,
    required this.folder,
    required this.onUploaded,
    this.initialImageUrl,
    this.label = 'Pick Image',
  });

  final String folder;
  final String? initialImageUrl;
  final String label;
  final ValueChanged<String> onUploaded;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  final _uploader = ImageUploader();
  Uint8List? _previewBytes;
  bool _uploading = false;
  String? _error;

  Future<void> _pick() async {
    final result = await _uploader.pickImage();
    if (!mounted) return;

    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    if (result.wasCancelled) return;

    setState(() {
      _previewBytes = result.bytes;
      _error = null;
      _uploading = true;
    });

    try {
      final url = await _uploader.upload(result.bytes!, folder: widget.folder);
      if (!mounted) return;
      widget.onUploaded(url);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Failed to upload image: ${UserFacingError.describe(error)}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_previewBytes != null)
          Image.memory(_previewBytes!, height: 120, fit: BoxFit.cover)
        else if (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty)
          CachedNetworkImage(imageUrl: widget.initialImageUrl!, height: 120, fit: BoxFit.cover)
        else
          const Text('No image selected.'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _uploading ? null : _pick,
          icon: _uploading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image),
          label: Text(widget.label),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
