import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';

class MenuScanScreen extends StatefulWidget {
  final String? restaurantId;
  const MenuScanScreen({super.key, this.restaurantId});

  @override
  State<MenuScanScreen> createState() => _MenuScanScreenState();
}

class _MenuScanScreenState extends State<MenuScanScreen> {
  bool _processing = false;

  Future<void> _captureAndScan() async {
    setState(() => _processing = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera);
      if (xfile == null) {
        setState(() => _processing = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(xfile.path);
      final recognizer = TextRecognizer();
      final result = await recognizer.processImage(inputImage);
      recognizer.close();

      final rawText = result.text;

      if (mounted) {
        context.push(
          '/scan/results',
          extra: {
            'rawText': rawText,
            'restaurantId': widget.restaurantId,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  // Viewfinder frame
                  Container(
                    width: 280,
                    height: 360,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.7),
                          width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Point at a menu',
                        style: TextStyle(
                          color: AppColors.accent.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Scan a physical menu or\ntake a photo of the menu board',
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
                      style:
                          TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            // Capture button
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _processing ? null : _captureAndScan,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _processing
                          ? AppColors.mutedText
                          : AppColors.accent,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 3),
                    ),
                    child: _processing
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.camera_alt,
                            color: Colors.black, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
