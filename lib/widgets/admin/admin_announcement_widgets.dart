import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/admin_controller.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/announcement_constants.dart';
import '../../screens/create_announcement_dialog.dart';
import 'admin_shimmer_widgets.dart';

class AnnouncementsView extends StatelessWidget {
  const AnnouncementsView({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    
    return StreamBuilder(
      stream: fs.getAnnouncements(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AnnouncementsShimmer();
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  "No announcements yet",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnnouncementsSummary(docs: docs),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: AnnouncementCard(doc: docs[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnnouncementsSummary extends StatelessWidget {
  final List<dynamic> docs;

  const AnnouncementsSummary({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    final totalAnnouncements = docs.length;
    final totalEmployees = controller.allEmployees.length;
    final totalSeenEntries = docs.fold<int>(0, (total, doc) {
      final seen = (doc.data()["seenBy"] as List<dynamic>?) ?? [];
      return total + seen.length;
    });
    final coverage = (totalAnnouncements == 0 || totalEmployees == 0)
        ? 0
        : ((totalSeenEntries / (totalAnnouncements * totalEmployees)) * 100).clamp(0, 100);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _SummaryItem(label: "Total\nAnnouncements", value: "$totalAnnouncements", color: AppColors.primary)),
          Expanded(child: _SummaryItem(label: "Total\nEmployees", value: "${totalEmployees - 1}", color: Colors.grey.shade800)),
          Expanded(child: _SummaryItem(label: "Read\ncoverage", value: "${coverage.toStringAsFixed(0)}%", color: Colors.green.shade700)),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundMedium,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(5),
      margin: const EdgeInsets.all(2),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  final dynamic doc;

  const AnnouncementCard({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    final data = doc.data() as Map<String, dynamic>;
    final docId = doc.id;
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

    final targetLabel = announcementTargetLabels[targetType] ?? "All Employees";
    final targetDetail = formatTargetAudience(
      targetType,
      targetType == announcementTargetEmployees ? targetEmployeeIds.length.toString() : null,
      targetEmployeeIds.length,
    );
    final totalEmployees = controller.allEmployees.isNotEmpty
        ? controller.allEmployees.length
        : seenBy.length;

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
                label: Text(targetLabel),
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
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                height: 190,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  height: 190,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 190,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.error_outline),
                ),
              ),
            ),
          ],
          if (pdfUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _launchDocumentUrl(pdfUrl),
              child: Container(
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
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Seen by: ${seenBy.length}/${totalEmployees - 1 > 0 ? totalEmployees - 1 : seenBy.length}",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _showAnnouncementAnalytics(title, seenBy, controller),
                    child: const Text("View analytics"),
                  ),
                  IconButton(
                    onPressed: () => _openAnnouncementDialog(docId: docId, initialData: data, controller: controller),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    onPressed: () => _confirmDeleteAnnouncement(docId, title),
                    icon: Icon(Icons.delete, color: Colors.black.withOpacity(0.8)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchDocumentUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar("Cannot open document", "Please check your network or try again later.");
    }
  }
}

void _openAnnouncementDialog({
  String? docId,
  Map<String, dynamic>? initialData,
  required AdminController controller,
}) {
  showDialog(
    context: Get.context!,
    builder: (context) => CreateAnnouncementDialog(
      announcementId: docId,
      initialData: initialData,
      onSaved: controller.refreshEmployeeCache,
    ),
  );
}

void _showAnnouncementAnalytics(String title, List<String> seenBy, AdminController controller) {
  final nonAdminEmployees = controller.allEmployees.where((e) => !e.isAdmin).toList();
  final nonAdminEmployeeIds = nonAdminEmployees.map((e) => e.id).toSet();
  final seenIds = seenBy.where((id) => nonAdminEmployeeIds.contains(id)).toList();
  final unseenIds = nonAdminEmployees
      .where((employee) => !seenBy.contains(employee.id))
      .map((employee) => employee.id)
      .toList();
  final totalEmployees = nonAdminEmployees.length;
  final seenCount = seenIds.length;
  final coverage = totalEmployees == 0 ? 0.0 : seenCount / totalEmployees;

  showDialog(
    context: Get.context!,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Announcement Analytics",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _AnalyticsStat("Seen", "$seenCount", AppColors.backgroundLight, Colors.green),
                const SizedBox(width: 10),
                _AnalyticsStat("Pending", "${totalEmployees - seenCount}", AppColors.backgroundLight, Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: coverage.clamp(0, 1),
              backgroundColor: Colors.grey.shade200,
              color: Colors.green.shade600,
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text(
              "${(coverage * 100).clamp(0, 100).toStringAsFixed(0)}% coverage",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 20),
            if (seenIds.isNotEmpty)
              _AnalyticsList("Seen by (${seenIds.length})", seenIds, Colors.green.shade50, controller),
            if (unseenIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              _AnalyticsList("Pending (${unseenIds.length})", unseenIds, Colors.orange.shade50, controller),
            ],
            if (seenIds.isEmpty && unseenIds.isEmpty)
              Center(
                child: Text(
                  "No employees available for this announcement yet.",
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AnalyticsStat extends StatelessWidget {
  final String label;
  final String value;
  final Color background;
  final Color accent;

  const _AnalyticsStat(this.label, this.value, this.background, this.accent);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsList extends StatelessWidget {
  final String label;
  final List<String> userIds;
  final Color background;
  final AdminController controller;

  const _AnalyticsList(this.label, this.userIds, this.background, this.controller);

  @override
  Widget build(BuildContext context) {
    final listHeight = math.min(userIds.length * 48.0, 200.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: listHeight,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: userIds.length,
              separatorBuilder: (_, __) => Divider(color: Colors.grey.shade300, height: 10),
              itemBuilder: (context, index) {
                final id = userIds[index];
                final entry = controller.employeeLookup[id];
                final name = entry?.name ?? "Employee";
                final initials = name
                    .trim()
                    .split(" ")
                    .where((part) => part.isNotEmpty)
                    .map((part) => part[0])
                    .take(2)
                    .join()
                    .toUpperCase();
                final profileImage = entry?.profileImage;
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      backgroundImage: profileImage?.isNotEmpty == true ? NetworkImage(profileImage!) : null,
                      child: profileImage?.isNotEmpty == true
                          ? null
                          : Text(
                              initials,
                              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

void _confirmDeleteAnnouncement(String id, String title) {
  showDialog(
    context: Get.context!,
    builder: (context) => AlertDialog(
      title: const Text("Delete announcement"),
      content: Text("Delete \"$title\" permanently?", style: TextStyle(color: Colors.grey.shade700)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(context);
            try {
              final fs = FirestoreService();
              await fs.deleteAnnouncement(id);
              Get.snackbar("Deleted", "Announcement removed");
            } catch (e) {
              Get.snackbar("Error", "Failed to delete announcement");
            }
          },
          child: const Text("Delete"),
        ),
      ],
    ),
  );
}

