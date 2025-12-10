import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_colors.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/auth_controller.dart';

class AdminAppBar extends StatelessWidget {
  const AdminAppBar({super.key});

  @override
  Widget build(BuildContext context) {
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Text(
              "Admin Dashboard",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to logout?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.find<AuthController>().logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.logout, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

class AnnouncementsHeader extends StatelessWidget {
  const AnnouncementsHeader({super.key});

  @override
  Widget build(BuildContext context) {
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
      child: Center(
        child: Text(
          "Announcements",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class LeaveApplicationsHeader extends StatelessWidget {
  const LeaveApplicationsHeader({super.key});

  @override
  Widget build(BuildContext context) {
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
      child: Center(
        child: const Text(
          "Leave Applications",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class InternProgressHeader extends StatelessWidget {
  const InternProgressHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();

    return Column(
      children: [
        Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Intern Daily Progress",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Obx(() {
                String tooltipText;
                switch (controller.internProgressViewMode.value) {
                  case "today":
                    tooltipText = "Download Today's Report";
                    break;
                  case "month":
                    tooltipText = "Download Month Report";
                    break;
                  case "all":
                  default:
                    tooltipText = "Download All Time Report";
                    break;
                }

                return IconButton(
                  onPressed: () async {
                    try {
                      // Get filtered data based on current view mode
                      QuerySnapshot<Map<String, dynamic>> snapshot;
                      String reportType;

                      switch (controller.internProgressViewMode.value) {
                        case "today":
                          snapshot = await controller.fs
                              .getTodayInternProgress()
                              .first;
                          reportType = "Today's Intern Progress Report";
                          break;
                        case "month":
                          snapshot = await controller.fs
                              .getInternProgressForMonth(
                                controller.selectedMonth.value,
                              )
                              .first;
                          final month = DateFormat(
                            'MMMM yyyy',
                          ).format(controller.selectedMonth.value);
                          reportType = "$month Intern Progress Report";
                          break;
                        case "all":
                        default:
                          snapshot = await controller.fs
                              .getAllInternProgress()
                              .first;
                          reportType = "All Time Intern Progress Report";
                          break;
                      }

                      // Filter data in memory if needed
                      List<Map<String, dynamic>> progressList;

                      if (controller.internProgressViewMode.value == "today") {
                        final allDocs = snapshot.docs;
                        final today = DateFormat(
                          'yyyy-MM-dd',
                        ).format(DateTime.now());
                        progressList = allDocs
                            .where((doc) {
                              final data = doc.data();
                              final dateStr = data["date"] as String?;
                              return dateStr == today;
                            })
                            .map((doc) => doc.data())
                            .toList();
                      } else if (controller.internProgressViewMode.value ==
                          "month") {
                        final allDocs = snapshot.docs;
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
                        final startDateStr = DateFormat(
                          'yyyy-MM-dd',
                        ).format(startDate);
                        final endDateStr = DateFormat(
                          'yyyy-MM-dd',
                        ).format(endDate);

                        progressList = allDocs
                            .where((doc) {
                              final data = doc.data();
                              final dateStr = data["date"] as String?;
                              if (dateStr == null) return false;
                              return dateStr.compareTo(startDateStr) >= 0 &&
                                  dateStr.compareTo(endDateStr) <= 0;
                            })
                            .map((doc) => doc.data())
                            .toList();
                      } else {
                        progressList = snapshot.docs
                            .map((doc) => doc.data())
                            .toList();
                      }

                      if (progressList.isEmpty) {
                        Get.snackbar(
                          "Info",
                          "No intern progress submissions to download",
                        );
                        return;
                      }

                      await controller.pdfService.generateInternProgressPdf(
                        progressList: progressList,
                        reportType: reportType,
                      );
                    } catch (e) {
                      Get.snackbar(
                        "Error",
                        "Failed to generate PDF: ${e.toString()}",
                      );
                    }
                  },
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: tooltipText,
                );
              }),
            ],
          ),
        ),
        // Filter buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: InternProgressModeButton(
                  label: "Today",
                  mode: "today",
                  icon: Icons.today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InternProgressModeButton(
                  label: "Month",
                  mode: "month",
                  icon: Icons.calendar_month,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InternProgressModeButton(
                  label: "All Time",
                  mode: "all",
                  icon: Icons.history,
                ),
              ),
            ],
          ),
        ),
        // Month picker (only shown when month mode is selected)
        Obx(() {
          if (controller.internProgressViewMode.value == "month") {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => controller.pickMonth(),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Obx(() {
                      final month = controller.selectedMonth.value;
                      return Text(
                        DateFormat('MMMM yyyy').format(month),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }
}

class InternProgressModeButton extends StatelessWidget {
  final String label;
  final String mode;
  final IconData icon;

  const InternProgressModeButton({
    super.key,
    required this.label,
    required this.mode,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();

    return Obx(() {
      final isSelected = controller.internProgressViewMode.value == mode;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.changeInternProgressViewMode(mode),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
