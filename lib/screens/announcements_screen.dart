import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/announcements_controller.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';
import '../utils/announcement_constants.dart';
import '../widgets/announcements/announcement_card_widget.dart';
import '../widgets/announcements/category_filter_widget.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(AnnouncementsController());
    final controller = Get.find<AnnouncementsController>();
    final fs = FirestoreService();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Obx(
                  () => controller.isLoadingUser.value
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        )
                      : _buildAnnouncementsList(controller, fs),
                ),
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

  Widget _buildAnnouncementsList(
    AnnouncementsController controller,
    FirestoreService fs,
  ) {
    return StreamBuilder(
      stream: fs.getAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Failed to load announcements",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  "Loading announcements...",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final targetedDocs = docs
            .where((doc) => controller.isTargetedAnnouncement(doc.data()))
            .toList();

        return Obx(() {
          final displayDocs = controller.selectedCategory.value == "All"
              ? targetedDocs
              : targetedDocs.where((doc) {
                  final category =
                      (doc.data()["category"] as String?) ??
                      announcementCategories.first;
                  return category == controller.selectedCategory.value;
                }).toList();

          String message;
          if (docs.isEmpty) {
            message = "No announcements yet";
          } else if (targetedDocs.isEmpty) {
            message = "No announcements available for you yet";
          } else {
            message = "No announcements match this category";
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: const CategoryFilterWidget(),
              ),
              Expanded(
                child: displayDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              size: 70,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              message,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: displayDocs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(
                              milliseconds: 300 + (index * 100),
                            ),
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
                            child: AnnouncementCardWidget(
                              doc: displayDocs[index],
                              controller: controller,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        });
      },
    );
  }
}
