import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import '../utils/app_colors.dart';

enum DocumentPreviewType { image, pdf, video, other }

const Set<String> _imageExtensions = {
  "png",
  "jpg",
  "jpeg",
  "gif",
  "bmp",
  "webp",
};

const Set<String> _documentExtensions = {
  "pdf",
};

class MyLeaveApplicationsScreen extends StatefulWidget {
  const MyLeaveApplicationsScreen({super.key});

  @override
  State<MyLeaveApplicationsScreen> createState() =>
      _MyLeaveApplicationsScreenState();
}

class _MyLeaveApplicationsScreenState
    extends State<MyLeaveApplicationsScreen> {
  final FirestoreService _fs = FirestoreService();
  String _userId = "";

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final user = await LocalStorage.getUser();
    setState(() => _userId = user["uid"] ?? "");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // Leave Applications List
              Expanded(
                child: _buildLeaveApplicationsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "My Leave Applications",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveApplicationsList() {
    if (_userId.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    return StreamBuilder(
      stream: _fs.getEmployeeLeaveApplications(_userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "Error loading applications",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Loading applications...",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          );
        }

    if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No leave applications yet",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  "Apply for leave from the Dashboard",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No leave applications yet",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  "Apply for leave from the Dashboard",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          );
        }

        // Sort by createdAt if not already sorted by Firestore
        final sortedDocs = List.from(docs);
        sortedDocs.sort((a, b) {
          final aTime = a.data()["createdAt"]?.toDate() ?? DateTime(1970);
          final bTime = b.data()["createdAt"]?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime); // Descending order
        });

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: sortedDocs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _buildApplicationCard(sortedDocs[index]);
          },
        );
      },
    );
  }

  Widget _buildApplicationCard(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    final reason = data["reason"] as String? ?? "";
    final imageUrl = data["imageUrl"] as String? ?? "";
    final status = data["status"] as String? ?? "pending";
    final startDate = data["startDate"]?.toDate();
    final endDate = data["endDate"]?.toDate();
    final createdAt = data["createdAt"]?.toDate();
    final updatedAt = data["updatedAt"]?.toDate();
    final leaveType = data["leaveType"] as String? ?? "Leave";
    final leaveSubType = data["leaveSubType"] as String? ?? "General";
    final documentUrl = data["documentUrl"] as String?;
    final documentName = data["documentName"] as String? ?? "Supporting document";
    final documentPreviewType = documentUrl != null && documentUrl.isNotEmpty
        ? _documentPreviewTypeFromUrl(documentUrl)
        : DocumentPreviewType.other;

    final hasImage = imageUrl.isNotEmpty;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case "approved":
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = "Approved";
        break;
      case "rejected":
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = "Rejected";
        break;
      default:
        statusColor = AppColors.primary;
        statusIcon = Icons.pending;
        statusText = "Pending";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
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
          // Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (updatedAt != null && status != "pending")
                Text(
                  "Updated: ${DateFormat('MMM d, y').format(updatedAt)}",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge(leaveType, Icons.medical_information, AppColors.primary),
              _buildBadge(leaveSubType, Icons.category, Colors.grey.shade600),
            ],
          ),
          const SizedBox(height: 16),

          // Date Range
          if (startDate != null && endDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Reason
          Text(
            "Reason:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          if (documentUrl?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () =>
                  _showDocumentPreview(documentUrl!, documentName, documentPreviewType),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: const Icon(
                        Icons.insert_drive_file,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        documentName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.fullscreen,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _launchDocumentUrl(documentUrl!),
                child: Text(
                  "Open externally",
                  style: TextStyle(color: AppColors.primary, fontSize: 13),
                ),
              ),
            ),
          ],

          // Image
          if (hasImage) ...[
            const SizedBox(height: 16),
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.orange.shade600,
                      ),
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

          if (createdAt != null) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  "Applied on: ${DateFormat('MMM d, y • h:mm a').format(createdAt)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
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

  Future<void> _launchDocumentUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar(
        "Cannot open document",
        "Please check your internet connection or try again later.",
      );
    }
  }

  Future<void> _showDocumentPreview(
    String url,
    String title,
    DocumentPreviewType type,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              if (type == DocumentPreviewType.image)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      placeholder: (context, url) => Container(
                        height: 240,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 240,
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.error)),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type == DocumentPreviewType.pdf
                              ? Icons.picture_as_pdf
                              : Icons.insert_drive_file,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          type == DocumentPreviewType.pdf
                              ? "PDF Preview not supported"
                              : "Document Preview",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tap open externally to view full document.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _launchDocumentUrl(url);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("Open full document"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DocumentPreviewType _documentPreviewTypeFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return DocumentPreviewType.other;
    final path = uri.path;
    final lastSegment = path.split('/').last;
    final dotIndex = lastSegment.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == lastSegment.length - 1) {
      return DocumentPreviewType.other;
    }
    final ext = lastSegment.substring(dotIndex + 1).toLowerCase();
    if (_imageExtensions.contains(ext)) return DocumentPreviewType.image;
    if (_documentExtensions.contains(ext)) return DocumentPreviewType.pdf;
    return DocumentPreviewType.other;
  }
}

