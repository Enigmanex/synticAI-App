import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/dashboard_controller.dart';
import '../../services/local_storage.dart';
import '../../utils/app_colors.dart';
import 'record_card_widget.dart';

class RecordsListWidget extends StatelessWidget {
  const RecordsListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    final fs = controller.fs;
    
    return FutureBuilder<String>(
      future: controller.userId.value.isEmpty
          ? LocalStorage.getUser().then((u) => u["uid"] ?? "")
          : Future.value(controller.userId.value),
      builder: (context, userIdSnapshot) {
        return StreamBuilder(
          stream: fs.todayRecords(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !userIdSnapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Loading records...",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            final currentUserId = userIdSnapshot.data ?? controller.userId.value;
            if (currentUserId.isEmpty) {
              return const SizedBox.shrink();
            }

            final docs = snapshot.data!.docs;
            final userRecords = docs.where((doc) {
              try {
                final data = doc.data();
                final empId = data["employeeId"];
                final empIdString = empId is String ? empId : empId?.toString() ?? "";
                return empIdString == currentUserId;
              } catch (e) {
                return false;
              }
            }).toList();

            if (userRecords.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      "No records for today",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            final reversedRecords = userRecords.reversed.toList();

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: reversedRecords.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                  child: RecordCardWidget(doc: reversedRecords[index]),
                );
              },
            );
          },
        );
      },
    );
  }
}

