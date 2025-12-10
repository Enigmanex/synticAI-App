import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/admin/admin_leave_widgets.dart';

class AdminLeaveApplicationsScreen extends StatelessWidget {
  const AdminLeaveApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: const LeaveApplicationsView(),
      ),
    );
  }
}
