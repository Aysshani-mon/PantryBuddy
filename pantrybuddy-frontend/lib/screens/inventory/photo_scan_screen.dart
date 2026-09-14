import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/recognition_candidate.dart';
import '../../state/app_state.dart';

/// User Story 4.3 — capture or pick a photo of a food item, send it to the
/// backend (which forwards to the private SigLIP recognition service), and
/// let the user pick from the returned candidates. Pops with the chosen
/// [RecognitionCandidate] so the caller (Add Item screen) can pre-fill its
/// form — nothing is saved here, matching the same review-before-commit
/// pattern as barcode scanning (AC 4.4).
class PhotoScanScreen extends StatefulWidget {
  const PhotoScanScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<PhotoScanScreen> createState() => _PhotoScanScreenState();
}

class _PhotoScanScreenState extends State<PhotoScanScreen> {
  Uint8List? _imageBytes;
  bool _busy = false;
  String? _error;
  List<RecognitionCandidate> _candidates = [];

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    // maxWidth/imageQuality do the compression for us — no separate image
    // library needed, and keeps the upload well under the backend's size
    // limit without the user having to think about it.
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 768,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _candidates = [];
      _error = null;
    });
    await _recognize(bytes);
  }

  Future<void> _recognize(Uint8List bytes) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final candidates = await widget.appState.recognitionRepo.recognizeImage(bytes);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _candidates = candidates;
        if (candidates.isEmpty) {
          _error = 'No confident match found — you can still enter the item manually.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Recognition failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan photo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_imageBytes!, height: 220, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.photo_camera_outlined, size: 48, color: Colors.grey.shade400),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose from gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Colors.orange.shade800)),
                ),
              if (_candidates.isNotEmpty) ...[
                const Text('Is this what you scanned?', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: _candidates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = _candidates[i];
                      return Card(
                        child: ListTile(
                          title: Text(c.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${c.categoryName} · matched "${c.matchedKeyword}"'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pop(c),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Enter item manually instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
