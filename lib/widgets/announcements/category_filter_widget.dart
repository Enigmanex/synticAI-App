import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/announcements_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/announcement_constants.dart';

class CategoryFilterWidget extends StatelessWidget {
  const CategoryFilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AnnouncementsController>();
    final filters = ["All", ...announcementCategories];
    
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: filters.map((category) {
        return Obx(() {
          final isSelected = controller.selectedCategory.value == category;
          return ChoiceChip(
            checkmarkColor: Colors.white,
            label: Text(category),
            selected: isSelected,
            onSelected: (_) => controller.changeCategory(category),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.grey.shade100,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          );
        });
      }).toList(),
    );
  }
}

