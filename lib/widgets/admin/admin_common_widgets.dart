import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import '../../utils/app_colors.dart';

enum DocumentPreviewType { image, pdf, other }

class BadgeWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const BadgeWidget({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class DocumentPreviewWidget extends StatelessWidget {
  final String url;
  final String name;
  final DocumentPreviewType type;

  const DocumentPreviewWidget({
    super.key,
    required this.url,
    required this.name,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _launchDocumentUrl(url),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: type == DocumentPreviewType.image
                  ? CachedNetworkImage(
                      imageUrl: url,
                      height: 160,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.error_outline)),
                      ),
                    )
                  : Container(
                      height: 160,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Icon(
                          type == DocumentPreviewType.pdf
                              ? Icons.picture_as_pdf
                              : Icons.insert_drive_file,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.open_in_full, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchDocumentUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar(
        "Cannot open document",
        "Please check your network or try again later.",
      );
    }
  }
}

DocumentPreviewType documentPreviewTypeFromUrl(String url) {
  const imageExtensions = {"png", "jpg", "jpeg", "gif", "bmp", "webp"};
  const documentExtensions = {"pdf"};

  final uri = Uri.tryParse(url);
  if (uri == null) return DocumentPreviewType.other;
  final lastSegment = uri.path.split('/').last;
  final dotIndex = lastSegment.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == lastSegment.length - 1) {
    return DocumentPreviewType.other;
  }
  final ext = lastSegment.substring(dotIndex + 1).toLowerCase();
  if (imageExtensions.contains(ext)) return DocumentPreviewType.image;
  if (documentExtensions.contains(ext)) return DocumentPreviewType.pdf;
  return DocumentPreviewType.other;
}

