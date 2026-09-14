import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/food_item.dart';
import '../../models/receipt_item_draft.dart';
import '../../services/browser_ocr_service.dart';
import '../../services/category_defaults_service.dart';
import '../../state/app_state.dart';
import '../../utils/date_format.dart';
import '../../utils/unit_options.dart';

enum _Stage { capture, working, review, submitting }

/// Receipt scanning — currently scoped to Jaya Grocer's receipt layout
/// only (see backend recognition.js for the parser this depends on).
/// Flow: capture photo -> browser-side OCR -> backend parses lines into
/// draft items -> this screen shows an editable review list -> user
/// confirms/edits/deselects each line -> "Add N items" commits them.
/// Nothing is saved to inventory before that final confirmation.
class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  _Stage _stage = _Stage.capture;
  String? _error;
  List<ReceiptItemDraft> _drafts = [];

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _error = null;
      _stage = _Stage.working;
    });
    await _runPipeline(bytes);
  }

  Future<void> _runPipeline(Uint8List bytes) async {
    try {
      final rawText = await BrowserOcrService.recognizeText(bytes);
      final drafts = await widget.appState.recognitionRepo.recognizeReceipt(rawText);
      if (!mounted) return;
      if (drafts.isEmpty) {
        setState(() {
          _stage = _Stage.capture;
          _error = 'Couldn\'t find any items on this receipt. Make sure the photo is clear and try again, or enter items manually.';
        });
        return;
      }
      // Pre-fill a sensible storage-location guess per category, same
      // helper used by barcode scanning — still fully editable below.
      for (final d in drafts) {
        d.storageLocation = CategoryDefaultsService.suggestLocation(d.category);
      }
      setState(() {
        _drafts = drafts;
        _stage = _Stage.review;
      });
    } on BrowserOcrException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.capture;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.capture;
        _error = 'Something went wrong reading this receipt: $e';
      });
    }
  }

  Future<void> _submit() async {
    final toAdd = _drafts.where((d) => d.included).toList();
    if (toAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one item to add.')));
      return;
    }
    final missing = toAdd.where((d) => d.category == null || d.storageLocation == null || d.useByDate == null).toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${missing.length} item(s) still need a category, storage location, or use-by date.')),
      );
      return;
    }

    setState(() => _stage = _Stage.submitting);
    var succeeded = 0;
    final failures = <String>[];
    for (final d in toAdd) {
      try {
        final result = await widget.appState.addItem(
          name: d.name,
          quantity: d.quantity,
          unit: d.unit,
          location: d.storageLocation!,
          category: d.category!,
          useByDate: d.useByDate!,
          price: d.totalPrice,
        );
        if (result != null) {
          succeeded++;
        } else {
          failures.add(d.name);
        }
      } catch (e) {
        failures.add(d.name);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        failures.isEmpty
            ? 'Added $succeeded item${succeeded == 1 ? '' : 's'} from the receipt.'
            : 'Added $succeeded item(s); ${failures.length} failed: ${failures.join(', ')}.',
      )),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan receipt')),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.capture => _buildCaptureView(),
          _Stage.working => const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reading receipt...'),
              ]),
            )),
          _Stage.review => _buildReviewView(),
          _Stage.submitting => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _buildCaptureView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 8),
          Text('Currently works with Jaya Grocer receipts only.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from gallery'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewView() {
    final includedCount = _drafts.where((d) => d.included).length;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('Check each item below — edit anything that\'s wrong, untick anything to skip.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            itemCount: _drafts.length,
            itemBuilder: (context, i) => _buildDraftCard(_drafts[i]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: _submit,
            child: Text('Add $includedCount item${includedCount == 1 ? '' : 's'} to inventory'),
          ),
        ),
      ],
    );
  }

  Widget _buildDraftCard(ReceiptItemDraft draft) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: draft.included,
                  onChanged: (v) => setState(() => draft.included = v ?? true),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.name,
                    decoration: const InputDecoration(labelText: 'Item name', isDense: true),
                    onChanged: (v) => draft.name = v,
                  ),
                ),
              ],
            ),
            if (!draft.matched)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 14, color: Colors.orange.shade800),
                    const SizedBox(width: 4),
                    Text('Not recognized — please pick a category', style: TextStyle(color: Colors.orange.shade800, fontSize: 11.5)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: _formatQty(draft.quantity),
                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) => draft.quantity = double.tryParse(v) ?? draft.quantity,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: kUnitOptions.contains(draft.unit) ? draft.unit : kUnitOptions.first,
                          decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                          items: kUnitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) => setState(() => draft.unit = v ?? draft.unit),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: draft.totalPrice.toStringAsFixed(2),
                          decoration: const InputDecoration(labelText: 'Price (RM)', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) => draft.totalPrice = double.tryParse(v) ?? draft.totalPrice,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ProductCategory>(
                          initialValue: draft.category,
                          decoration: const InputDecoration(labelText: 'Category', isDense: true),
                          hint: const Text('Select'),
                          items: ProductCategory.values
                              .map((c) => DropdownMenuItem(value: c, child: Text(c.label, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            draft.category = v;
                            draft.storageLocation ??= CategoryDefaultsService.suggestLocation(v);
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<StorageLocation>(
                          initialValue: draft.storageLocation,
                          decoration: const InputDecoration(labelText: 'Storage', isDense: true),
                          hint: const Text('Select'),
                          items: StorageLocation.values
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                              .toList(),
                          onChanged: (v) => setState(() => draft.storageLocation = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: draft.useByDate ?? DateTime.now().add(const Duration(days: 5)),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setState(() => draft.useByDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Use-by date', isDense: true),
                      child: Text(draft.useByDate == null ? 'Tap to set' : formatLongDate(draft.useByDate!)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
