import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../utils/app_colors.dart';
import '../widgets/route_guard.dart';
import 'create_announcement_dialog.dart';
import '../widgets/admin/admin_headers.dart';
import '../widgets/admin/admin_dashboard_widgets.dart';
import '../widgets/admin/admin_announcement_widgets.dart';
import '../widgets/admin/admin_leave_widgets.dart';
import '../widgets/admin/admin_intern_widgets.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(AdminController());
    final controller = Get.find<AdminController>();

    return RouteGuard(
      requireAdmin: true,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                Obx(() {
                  switch (controller.currentIndex.value) {
                    case 0:
                      return const AdminAppBar();
                    case 1:
                      return const AnnouncementsHeader();
                    case 2:
                      return const LeaveApplicationsHeader();
                    case 3:
                      return const InternProgressHeader();
                    default:
                      return const AdminAppBar();
                  }
                }),
                Expanded(child: _buildCurrentView(controller)),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(controller),
        floatingActionButton: Obx(() {
          if (controller.currentIndex.value == 1) {
            return FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateAnnouncementDialog(
                    onSaved: controller.refreshEmployeeCache,
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return const SizedBox.shrink();
        }),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildCurrentView(AdminController controller) {
    return Obx(() {
      switch (controller.currentIndex.value) {
        case 0:
          return const DashboardView();
        case 1:
          return const AnnouncementsView();
        case 2:
          return const LeaveApplicationsView();
        case 3:
          return const InternProgressView();
        default:
          return const DashboardView();
      }
    });
  }

  Widget _buildBottomNavigationBar(AdminController controller) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Obx(
        () => BottomNavigationBar(
          currentIndex: controller.currentIndex.value,
          onTap: (index) => controller.changeTab(index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey.shade600,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          iconSize: 24,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: "Dashboard",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.campaign),
              label: "Announcements",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_busy),
              label: "Leaves",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.school), label: "Interns"),
          ],
        ),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          const StatisticsCards(),
          const SizedBox(height: 24),
          const ViewModeSelector(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.people, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  "Employees",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const EmployeeStatsList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
