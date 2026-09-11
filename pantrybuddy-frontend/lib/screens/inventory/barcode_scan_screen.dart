import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/scanned_product.dart';
import '../../services/product_lookup_service.dart';

/// User Story 4.1 — scans a product barcode and looks it up against Open
/// Food Facts. Pops with a [ScannedProduct] on success so the caller (Add
/// Item screen) can pre-fill its form — the user still reviews/edits
/// everything there before it's saved (AC 4.4). Pops with null if the
/// user backs out or chooses to enter the item manually instead.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  // Restricted to linear product-barcode formats only — packaging often
  // has a separate marketing QR code (recipes/brand site) right next to
  // the real barcode, and without this the scanner can grab that instead
  // (confirmed happening during testing: it decoded a QR code URL rather
  // than a barcode number).
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      // Deliberately no ITF — deprecated in this mobile_scanner version,
      // and it's mostly used for case/carton-level barcodes rather than
      // retail packaging anyway.
    ],
  );
  final _manualCodeController = TextEditingController();

  bool _busy = false; // true while a detected code is being looked up
  bool _showManualEntry = false;
  String? _statusMessage;

  // Debug instrumentation — temporary, remove once scanning is confirmed
  // working reliably. Lets us tell "camera + detector never actually ran a
  // frame" apart from "it's running but not finding anything in frame",
  // which look identical to the user otherwise (camera on, nothing happens
  // either way).
  int _framesAnalyzed = 0;
  String? _engineError;

  @override
  void dispose() {
    _controller.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    setState(() => _framesAnalyzed++);
    if (_busy) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    await _lookUp(code);
  }

  Future<void> _lookUp(String barcode) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    await _controller.stop();

    try {
      final product = await ProductLookupService.lookup(barcode);
      if (!mounted) return;
      if (product == null) {
        setState(() {
          _busy = false;
          _statusMessage = 'No match found for barcode $barcode — try again, or enter the item manually.';
        });
        await _controller.start();
        return;
      }
      Navigator.of(context).pop(product);
    } on ProductLookupException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusMessage = e.message;
      });
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: [
          IconButton(
            tooltip: 'Enter barcode manually',
            icon: Icon(_showManualEntry ? Icons.camera_alt_outlined : Icons.keyboard_outlined),
            onPressed: () => setState(() => _showManualEntry = !_showManualEntry),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!_showManualEntry)
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        // Surfaces camera/permission/detector init failures
                        // that would otherwise fail silently.
                        final message = error.errorDetails?.message ?? error.errorCode.name;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _engineError = message);
                        });
                        return Container(
                          color: Colors.black87,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Camera error (${error.errorCode.name}): $message',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    )
                  else
                    _buildManualEntry(),
                  if (!_showManualEntry) _buildScanOverlay(),
                  if (!_showManualEntry)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _engineError != null
                              ? 'Detector error: $_engineError'
                              : _framesAnalyzed == 0
                                  ? 'Starting scanner... (if this never changes, the detector isn\'t initializing)'
                                  : 'Scanning — $_framesAnalyzed frame(s) analyzed, no barcode found yet',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  if (_busy)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade800, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_statusMessage!,
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Enter item manually instead'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 260,
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2.5),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildManualEntry() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Camera not working? Type the barcode number printed under it instead.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manualCodeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Barcode number'),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) _lookUp(value.trim());
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () {
                      final value = _manualCodeController.text.trim();
                      if (value.isNotEmpty) _lookUp(value);
                    },
              child: const Text('Look up'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
