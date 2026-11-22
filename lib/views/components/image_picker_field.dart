import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/theme/app_theme.dart';

class ImagePickerField extends StatelessWidget {
  const ImagePickerField({
    super.key,
    required this.label,
    required this.imagePath,
    required this.onChanged,
    this.errorText,
    this.folder = 'images',
  });

  final String label;
  final String? imagePath;
  final ValueChanged<String> onChanged;
  final String? errorText;

  final String folder;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final saved = await saveImage(picked.path, folder);
    onChanged(saved);
  }

  static Future<String> saveImage(String sourcePath, String folder) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    final name =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final copy = await File(sourcePath).copy(p.join(dir.path, name));
    return copy.path;
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Pilih Sumber Gambar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari Galeri'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pick(context, ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil Foto'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pick(context, ImageSource.camera);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final borderColor = errorText != null ? AppColors.danger : AppColors.border;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Material(
            color: hasImage ? AppColors.surface : AppColors.surfaceMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              side: BorderSide(color: borderColor, width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showSourceSheet(context),
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: hasImage
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(imagePath!), fit: BoxFit.cover),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 14, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text('Ganti',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.primary,
                                size: 26),
                          ),
                          const SizedBox(height: 10),
                          const Text('Ketuk untuk upload gambar',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          const Text('Dari galeri atau kamera',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(errorText!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class LocalImage extends StatelessWidget {
  const LocalImage({super.key, required this.path, this.height = 200});

  final String? path;
  final double height;

  Widget _placeholder(String text) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported_outlined,
              size: 36, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final file = (path == null || path!.isEmpty) ? null : File(path!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: file == null
            ? _placeholder('Tidak ada gambar')
            : GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    clipBehavior: Clip.antiAlias,
                    child: InteractiveViewer(child: Image.file(file)),
                  ),
                ),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _placeholder('Gambar tidak ditemukan'),
                ),
              ),
      ),
    );
  }
}
