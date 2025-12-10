import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/admin_controller.dart';
import '../../models/employee.dart';
import '../../utils/app_colors.dart';
import '../../screens/employee_details_screen.dart';
import 'admin_shimmer_widgets.dart';

class StatisticsCards extends StatelessWidget {
  const StatisticsCards({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();

    return FutureBuilder<List<Employee>>(
      future: controller.getFilteredEmployees(),
      builder: (context, snapshot) {
        final employeeCount = snapshot.hasData ? snapshot.data!.length : 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.people,
                  label: "Total Employees",
                  value: "$employeeCount",
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Obx(
                  () => StatCard(
                    icon: Icons.access_time,
                    label: "View Mode",
                    value: controller.viewMode.value == "today"
                        ? "Today"
                        : "Monthly",
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final MaterialColor color;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.shade400, color.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class ViewModeSelector extends StatelessWidget {
  const ViewModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ModeButton(label: "Today", mode: "today", icon: Icons.today),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ModeButton(
              label: "Month",
              mode: "month",
              icon: Icons.calendar_month,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ModeButton(
              label: "All Time",
              mode: "all",
              icon: Icons.history,
            ),
          ),
        ],
      ),
    );
  }
}

class ModeButton extends StatelessWidget {
  final String label;
  final String mode;
  final IconData icon;

  const ModeButton({
    super.key,
    required this.label,
    required this.mode,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();

    return Obx(() {
      final isSelected = controller.viewMode.value == mode;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.changeViewMode(mode),
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
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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

class EmployeeStatsList extends StatelessWidget {
  const EmployeeStatsList({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();

    return FutureBuilder<List<Employee>>(
      future: controller.getFilteredEmployees(),
      builder: (context, employeesSnapshot) {
        if (!employeesSnapshot.hasData) {
          return const EmployeeShimmer();
        }

        final employees = employeesSnapshot.data!;

        if (employees.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No employees found",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: employees.length,
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
              child: EmployeeCard(employee: employees[index], index: index),
            );
          },
        );
      },
    );
  }
}

class EmployeeCard extends StatelessWidget {
  final Employee employee;
  final int index;

  const EmployeeCard({super.key, required this.employee, required this.index});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();

    return Obx(() {
      return FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(
          '${employee.id}_${controller.viewMode.value}_${controller.selectedMonth.value.millisecondsSinceEpoch}',
        ),
        future: controller.getEmployeeRecords(employee.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EmployeeCardShimmer();
          }

          Duration totalDuration = Duration.zero;
          if (snapshot.hasData) {
            totalDuration = controller.calculateWorkedHours(snapshot.data!);
          }

          final hours = totalDuration.inHours;
          final minutes = totalDuration.inMinutes % 60;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmployeeDetailsScreen(
                      employee: employee,
                      viewMode: controller.viewMode.value,
                      selectedMonth: controller.viewMode.value == "month"
                          ? controller.selectedMonth.value
                          : null,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child:
                              employee.profileImage != null &&
                                  employee.profileImage!.isNotEmpty
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: employee.profileImage!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: AppColors.primaryLight,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      employee.email,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.backgroundLight,
                            AppColors.backgroundMedium,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(20),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_filled,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Obx(
                                        () => Text(
                                          controller.viewMode.value == "today"
                                              ? "Today's Hours"
                                              : controller.viewMode.value ==
                                                    "month"
                                              ? "This Month"
                                              : "Total Hours",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "$hours",
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          height: 1,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                          left: 4,
                                        ),
                                        child: Text(
                                          "h",
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "$minutes",
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          height: 1,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                          left: 4,
                                        ),
                                        child: Text(
                                          "m",
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(
                                          0.2,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: GestureDetector(
                                    onTap: () async {
                                      try {
                                        final records = await controller
                                            .getEmployeeRecords(employee.id);
                                        await controller.pdfService
                                            .generateAttendanceStatement(
                                              employee: employee,
                                              records: records,
                                              viewMode:
                                                  controller.viewMode.value,
                                              selectedMonth:
                                                  controller.viewMode.value ==
                                                      "month"
                                                  ? controller
                                                        .selectedMonth
                                                        .value
                                                  : null,
                                            );
                                      } catch (e) {
                                        Get.snackbar(
                                          "Error",
                                          "Failed to generate PDF: ${e.toString()}",
                                        );
                                      }
                                    },
                                    child: Icon(
                                      Icons.download,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Obx(() {
                                  if (controller.viewMode.value == "month") {
                                    return Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: GestureDetector(
                                        onTap: () => controller.pickMonth(),
                                        child: Icon(
                                          Icons.calendar_today,
                                          color: Colors.orange.shade700,
                                          size: 18,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
