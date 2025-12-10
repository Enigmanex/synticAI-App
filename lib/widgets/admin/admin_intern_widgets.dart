import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/admin_controller.dart';
import '../../services/firestore_service.dart';
import '../../services/local_storage.dart';
import '../../utils/app_colors.dart';
import 'admin_shimmer_widgets.dart';
import 'admin_common_widgets.dart';

class InternProgressView extends StatelessWidget {
  const InternProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    final fs = FirestoreService();
    
    return Obx(() {
      Stream<QuerySnapshot<Map<String, dynamic>>> stream;
      
      switch (controller.internProgressViewMode.value) {
        case "today":
          stream = fs.getTodayInternProgress();
          break;
        case "month":
          stream = fs.getInternProgressForMonth(controller.selectedMonth.value);
          break;
        case "all":
        default:
          stream = fs.getAllInternProgress();
          break;
      }
      
      return StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          // Show shimmer only when actively loading (waiting for first data)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const InternProgressShimmer();
          }

          // Handle errors
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "Error loading progress",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // If no data yet, show shimmer
          if (!snapshot.hasData) {
            return const InternProgressShimmer();
          }

          List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
          
          if (controller.internProgressViewMode.value == "today") {
            // For today view, filter in memory
            final allDocs = snapshot.data!.docs;
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            
            docs = allDocs.where((doc) {
              final data = doc.data();
              final dateStr = data["date"] as String?;
              return dateStr == today;
            }).toList();
          } else if (controller.internProgressViewMode.value == "month") {
            // For month view, filter in memory
            final allDocs = snapshot.data!.docs;
            final startDate = DateTime(
              controller.selectedMonth.value.year,
              controller.selectedMonth.value.month,
              1,
            );
            final endDate = DateTime(
              controller.selectedMonth.value.year,
              controller.selectedMonth.value.month + 1,
              0,
            );
            final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
            final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
            
            docs = allDocs.where((doc) {
              final data = doc.data();
              final dateStr = data["date"] as String?;
              if (dateStr == null) return false;
              return dateStr.compareTo(startDateStr) >= 0 &&
                  dateStr.compareTo(endDateStr) <= 0;
            }).toList();
          } else {
            docs = snapshot.data!.docs;
          }

          // Show empty state if no documents
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "No progress available",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // Show the list of progress cards
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) => InternProgressCard(doc: docs[index]),
          );
        },
      );
    });
  }
}

class InternProgressCard extends StatelessWidget {
  final dynamic doc;

  const InternProgressCard({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    final data = doc.data() as Map<String, dynamic>;
    final docId = doc.id;
    final internName = data["internName"] as String? ?? "Unknown Intern";
    final internEmail = data["internEmail"] as String? ?? "";
    final topicName = data["topicName"] as String? ?? "";
    final date = data["date"] as String? ?? "";
    final documentUrl = data["documentUrl"] as String? ?? "";
    final documentName = data["documentName"] as String? ?? "";
    final createdAt = data["createdAt"]?.toDate();
    final hasDocument = documentUrl.isNotEmpty;
    final remarks = data["remarks"] as String? ?? "";
    final remarksUpdatedAt = data["remarksUpdatedAt"]?.toDate();
    final hasRemarks = remarks.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
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
                      internName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (internEmail.isNotEmpty)
                      Text(
                        internEmail,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              if (createdAt != null)
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
                        DateFormat('MMM d').format(createdAt),
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
          const SizedBox(height: 16),
          if (date.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.event, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Progress Date: ${DateFormat('MMMM d, yyyy').format(DateTime.parse(date))}",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            "Topic:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            topicName,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          if (hasDocument) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _launchDocumentUrl(documentUrl),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: _buildDocumentPreview(documentUrl),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  documentName.isNotEmpty
                                      ? documentName
                                      : "Work Document",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.link,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        "Tap to open",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.open_in_new,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 16),
            Text(
              "Submitted on: ${DateFormat('MMM d, y • h:mm a').format(createdAt)}",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          // Remarks Section
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasRemarks
                  ? AppColors.primary.withOpacity(0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasRemarks
                    ? AppColors.primary.withOpacity(0.3)
                    : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.comment,
                          size: 18,
                          color: hasRemarks
                              ? AppColors.primary
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Admin Remarks",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: hasRemarks
                                ? AppColors.primary
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => _showRemarksDialog(
                        context,
                        docId,
                        remarks,
                        controller,
                      ),
                      icon: Icon(
                        hasRemarks ? Icons.edit : Icons.add_comment,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        hasRemarks ? "Edit" : "Add Remarks",
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                if (hasRemarks) ...[
                  const SizedBox(height: 8),
                  Text(
                    remarks,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                  if (remarksUpdatedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Updated: ${DateFormat('MMM d, y • h:mm a').format(remarksUpdatedAt)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "No remarks added yet",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview(String url) {
    final type = documentPreviewTypeFromUrl(url);
    
    if (type == DocumentPreviewType.image) {
      return CachedNetworkImage(
        imageUrl: url,
        height: 200,
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
          child: const Center(
            child: Icon(Icons.error_outline, size: 48),
          ),
        ),
      );
    } else if (type == DocumentPreviewType.pdf) {
      return Container(
        height: 200,
        color: Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                "PDF Document",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        height: 200,
        color: Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_drive_file,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                "Document",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _launchDocumentUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar("Cannot open document", "Please check your network or try again later.");
    }
  }
}

void _showRemarksDialog(
  BuildContext context,
  String progressId,
  String currentRemarks,
  AdminController controller,
) {
  final remarksController = TextEditingController(text: currentRemarks);
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.comment, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text("Add/Edit Remarks"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add your remarks or feedback on this progress submission:",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarksController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: "Enter your remarks here...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSaving
                ? null
                : () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isSaving
                ? null
                : () async {
                    setState(() {
                      isSaving = true;
                    });

                    try {
                      final currentUser = await LocalStorage.getUser();
                      final adminId = currentUser["uid"] as String? ?? "";

                      await controller.fs.updateProgressRemarks(
                        progressId,
                        remarksController.text.trim(),
                        adminId,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        Get.snackbar(
                          "Success",
                          currentRemarks.isEmpty
                              ? "Remarks added successfully"
                              : "Remarks updated successfully",
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      }
                    } catch (e) {
                      setState(() {
                        isSaving = false;
                      });
                      Get.snackbar(
                        "Error",
                        "Failed to save remarks: ${e.toString()}",
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  },
            child: isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text("Save"),
          ),
        ],
      ),
    ),
  );
}

