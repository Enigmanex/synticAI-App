import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_colors.dart';
import 'admin_common_widgets.dart';
import 'admin_shimmer_widgets.dart';

class LeaveApplicationsView extends StatelessWidget {
  const LeaveApplicationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    
    return StreamBuilder(
      stream: fs.getLeaveApplications(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LeaveApplicationsShimmer();
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  "No leave applications",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) => LeaveApplicationCard(doc: docs[index]),
        );
      },
    );
  }
}

class LeaveApplicationCard extends StatelessWidget {
  final dynamic doc;

  const LeaveApplicationCard({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final employeeName = data["employeeName"] as String? ?? "Unknown";
    final employeeEmail = data["employeeEmail"] as String? ?? "";
    final reason = data["reason"] as String? ?? "";
    final imageUrl = data["imageUrl"] as String? ?? "";
    final status = data["status"] as String? ?? "pending";
    final startDate = data["startDate"]?.toDate();
    final endDate = data["endDate"]?.toDate();
    final createdAt = data["createdAt"]?.toDate();
    final leaveType = data["leaveType"] as String? ?? "Leave";
    final leaveSubType = data["leaveSubType"] as String? ?? "General";
    final documentUrl = data["documentUrl"] as String?;
    final documentName = data["documentName"] as String? ?? "Supporting document";
    final documentUrlValue = documentUrl ?? "";
    final hasDocument = documentUrlValue.isNotEmpty;
    final documentPreviewType = hasDocument
        ? documentPreviewTypeFromUrl(documentUrlValue)
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
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
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
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              BadgeWidget(label: leaveType, icon: Icons.health_and_safety, color: AppColors.primary),
              BadgeWidget(label: leaveSubType, icon: Icons.category, color: Colors.grey.shade600),
            ],
          ),
          const SizedBox(height: 16),
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
          if (hasDocument) ...[
            const SizedBox(height: 16),
            DocumentPreviewWidget(
              url: documentUrlValue,
              name: documentName,
              type: documentPreviewType,
            ),
          ],
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
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
          if (status == "pending") ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final fs = FirestoreService();
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
                      final fs = FirestoreService();
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
}

