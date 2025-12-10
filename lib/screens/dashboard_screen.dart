import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/attendance_controller.dart';
import '../utils/app_colors.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/dashboard/records_list_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    Get.put(DashboardController());
    Get.put(AttendanceController());

    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,

        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const DashboardAppBar(),
                const SizedBox(height: 20),
                const UserInfoCard(),
                const SizedBox(height: 20),
                const ActionButtons(),
                const SizedBox(height: 20),
                const LeaveApplicationButton(),
                const SizedBox(height: 20),
                const WorkedHoursCard(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        "Today's Records",
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
                const RecordsListWidget(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
