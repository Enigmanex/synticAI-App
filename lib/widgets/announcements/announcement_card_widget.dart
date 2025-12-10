import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/announcements_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/announcement_constants.dart';

class AnnouncementCardWidget extends StatelessWidget {
  final dynamic doc;
  final AnnouncementsController controller;

  const AnnouncementCardWidget({
    super.key,
    required this.doc,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data["title"] as String? ?? "Announcement";
    final text = data["text"] as String? ?? "";
    final imageUrl = data["imageUrl"] as String? ?? "";
    final pdfUrl = data["pdfUrl"] as String? ?? "";
    final category = data["category"] as String? ?? "General";
    final targetType = data["targetType"] as String? ?? announcementTargetAll;
    final targetEmployeeIds = (data["targetEmployeeIds"] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final seenBy = (data["seenBy"] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final timestamp = data["createdAt"];

    DateTime? date;
    if (timestamp != null) {
      date = timestamp is DateTime ? timestamp : timestamp.toDate();
    }

    final targetDetail = formatTargetAudience(
      targetType,
      targetType == announcementTargetEmployees ? targetEmployeeIds.length.toString() : null,
      targetEmployeeIds.length,
    );
    final isRead = seenBy.contains(controller.userId.value);
    final processing = controller.processingAnnouncements.contains(doc.id);
    final hasImage = imageUrl.isNotEmpty;
    final hasPdf = pdfUrl.isNotEmpty;
    final hasText = text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      label: Text(isRead ? "Marked as read" : "Unread"),
                      backgroundColor: isRead ? Colors.green.shade100 : Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isRead ? Colors.green.shade800 : Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Seen by ${seenBy.length} people",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: processing
                      ? null
                      : () => controller.toggleAnnouncementRead(doc.id, !isRead),
                  child: Icon(
                    !isRead ? Icons.email_outlined : Icons.email,
                    color: isRead ? AppColors.primaryLight : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (date != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Text(
              DateFormat('EEEE, MMMM d, y • h:mm a').format(date),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(
                label: Text(category),
                backgroundColor: AppColors.primary.withOpacity(0.12),
                labelStyle: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Chip(
                label: Text(announcementTargetLabels[targetType] ?? "Targeted"),
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            targetDetail,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (hasText)
            Text(
              text,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
            ),
          if (hasImage) ...[
            if (hasText) const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.error_outline),
                ),
              ),
            ),
          ],
          if (hasPdf) ...[
            if (hasText || hasImage) const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openPdf(pdfUrl),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        "Open PDF",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar("Error", "Could not open PDF");
    }
  }
}

