import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../data/restaurant_repository.dart';

class MenuScanScreen extends ConsumerStatefulWidget {
  final String? restaurantId;
  const MenuScanScreen({super.key, this.restaurantId});

  @override
  ConsumerState<MenuScanScreen> createState() => _MenuScanScreenState();
}

class _MenuScanScreenState extends ConsumerState<MenuScanScreen> {
  bool _processing = false;
  bool _finishing = false;
  final List<String> _scannedPages = [];

  Future<void> _runOcr(List<XFile> files) async {
    final recognizer = TextRecognizer();
    try {
      for (final file in files) {
        final result = await recognizer.processImage(
          InputImage.fromFilePath(file.path),
        );
        if (result.text.trim().isNotEmpty) {
          _scannedPages.add(result.text);
        }
      }
    } finally {
      recognizer.close();
    }
  }

  Future<void> _captureAndScan() async {
    setState(() => _processing = true);
    try {
      final xfile = await ImagePicker().pickImage(source: ImageSource.camera);
      if (xfile == null) return;
      await _runOcr([xfile]);
      if (mounted) setState(() {});
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _processing = true);
    try {
      final files = await ImagePicker().pickMultiImage();
      if (files.isEmpty) return;
      await _runOcr(files);
      if (mounted) setState(() {});
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          apiErrorMessage(e),
          style: const TextStyle(color: AppColors.primaryText),
        ),
        backgroundColor: AppColors.elevated,
      ),
    );
  }

  Future<void> _done() async {
    if (_scannedPages.isEmpty) return;
    setState(() => _finishing = true);

    final combinedText = _scannedPages.join('\n\n');

    List<ParsedDishItem>? parsedDishes;
    if (widget.restaurantId != null && widget.restaurantId!.isNotEmpty) {
      try {
        parsedDishes = await ref
            .read(restaurantRepositoryProvider)
            .parseOcr(
              rawText: combinedText,
              restaurantId: widget.restaurantId!,
            );
      } catch (e) {
        debugPrint('OCR parse API failed, using heuristic fallback: $e');
      }
    }

    if (mounted) {
      setState(() => _finishing = false);
      context.push(
        '/scan/results',
        extra: {
          'rawText': combinedText,
          'restaurantId': widget.restaurantId,
          'parsedDishes': parsedDishes,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _scannedPages.length;
    final hasPages = pageCount > 0;
    final busy = _processing || _finishing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Dark viewfinder background
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 280,
                    height: 360,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.7),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        hasPages
                            ? '$pageCount page${pageCount == 1 ? '' : 's'} scanned'
                            : 'Point at a menu',
                        style: TextStyle(
                          color: AppColors.accent.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    hasPages
                        ? 'Scan another page or tap Done'
                        : 'Scan a physical menu or pick images from gallery',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Text(
                      'Scan Menu',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Done button — appears after first scan
                  if (hasPages) ...[
                    GestureDetector(
                      onTap: busy ? null : _done,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: busy ? AppColors.mutedText : AppColors.accent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: _finishing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Done',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Camera + gallery row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Gallery button
                        GestureDetector(
                          onTap: busy ? null : _pickFromGallery,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: busy
                                  ? Colors.white12
                                  : Colors.white.withValues(alpha: 0.15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.photo_library_outlined,
                              color: busy
                                  ? Colors.white24
                                  : Colors.white.withValues(alpha: 0.8),
                              size: 22,
                            ),
                          ),
                        ),

                        // Camera capture button
                        GestureDetector(
                          onTap: busy ? null : _captureAndScan,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: busy
                                  ? AppColors.mutedText
                                  : (hasPages
                                        ? Colors.white24
                                        : AppColors.accent),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 3,
                              ),
                            ),
                            child: _processing
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                    size: 28,
                                  ),
                          ),
                        ),

                        // Spacer to keep camera centered
                        const SizedBox(width: 52),
                      ],
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
}
