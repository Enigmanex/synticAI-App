import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';

enum DocumentPreviewType { image, pdf, other }

const Set<String> _imageExtensions = {
  "png",
  "jpg",
  "jpeg",
  "gif",
  "bmp",
  "webp",
};

const Set<String> _documentExtensions = {"pdf"};

class AdminLeaveApplicationsScreen extends StatelessWidget {
  const AdminLeaveApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService _fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text("Leave Applications"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade50.withOpacity(0.3),
              Colors.orange.shade100.withOpacity(0.3),
              Colors.white,
            ],
          ),
        ),
        child: StreamBuilder(
          stream: _fs.getLeaveApplications(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.orange.shade600,
                  ),
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
                      "No leave applications",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildApplicationCard(docs[index], _fs);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildApplicationCard(dynamic doc, FirestoreService fs) {
    final data = doc.data() as Map<String, dynamic>;
    final employeeName = data["employeeName"] as String? ?? "Unknown";
    final employeeEmail = data["employeeEmail"] as String? ?? "";
    final reason = data["reason"] as String? ?? "";
    final imageUrl = data["imageUrl"] as String? ?? "";
    final status = data["status"] as String? ?? "pending";
    final startDate = data["startDate"]?.toDate();
    final endDate = data["endDate"]?.toDate();
    final createdAt = data["createdAt"]?.toDate();
    final documentUrl = data["documentUrl"] as String?;
    final documentName = data["documentName"] as String? ?? "Supporting document";
    final documentPreviewType = documentUrl != null && documentUrl.isNotEmpty
        ? _documentPreviewTypeFromUrl(documentUrl)
        : DocumentPreviewType.other;
    final leaveType = data["leaveType"] as String? ?? "Leave";
    final leaveSubType = data["leaveSubType"] as String? ?? "General";

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
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = "Pending";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
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
          // Header with Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (employeeEmail.isNotEmpty)
                      Text(
                        employeeEmail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge(leaveType, Icons.health_and_safety, AppColors.primary),
              _buildBadge(leaveSubType, Icons.category, Colors.grey.shade600),
            ],
          ),
          const SizedBox(height: 16),

          // Date Range
          if (startDate != null && endDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}",
                      style: TextStyle(
                        color: Colors.orange.shade700,
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
            _buildDocumentPreview(
              documentUrl!,
              documentName,
              documentPreviewType,
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
            Text(
              "Applied on: ${DateFormat('MMM d, y • h:mm a').format(createdAt)}",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],

          // Action Buttons (only for pending)
          if (status == "pending") ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      fs.updateLeaveApplicationStatus(doc.id, "approved");
                      Get.snackbar("Success", "Leave application approved");
                    },
                    icon: const Icon(Icons.check),
                    label: const Text("Approve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      fs.updateLeaveApplicationStatus(doc.id, "rejected");
                      Get.snackbar("Success", "Leave application rejected");
                    },
                    icon: const Icon(Icons.close),
                    label: const Text("Reject"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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

  Widget _buildDocumentPreview(
    String url,
    String name,
    DocumentPreviewType type,
  ) {
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: type == DocumentPreviewType.image
                  ? CachedNetworkImage(
                      imageUrl: url,
                      height: 160,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.error_outline),
                        ),
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
                  Icon(
                    Icons.open_in_full,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DocumentPreviewType _documentPreviewTypeFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return DocumentPreviewType.other;
    final lastSegment = uri.path.split('/').last;
    final dotIndex = lastSegment.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == lastSegment.length - 1) {
      return DocumentPreviewType.other;
    }
    final ext = lastSegment.substring(dotIndex + 1).toLowerCase();
    if (_imageExtensions.contains(ext)) return DocumentPreviewType.image;
    if (_documentExtensions.contains(ext)) return DocumentPreviewType.pdf;
    return DocumentPreviewType.other;
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
