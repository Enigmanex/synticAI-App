import 'package:get/get.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';

class AnnouncementsController extends GetxController {
  final fs = FirestoreService();

  final userId = "".obs;
  final userDepartment = "".obs;
  final isLoadingUser = true.obs;
  final selectedCategory = "All".obs;
  final processingAnnouncements = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserContext();
  }

  Future<void> loadUserContext() async {
    try {
      final user = await LocalStorage.getUser();
      final uid = user["uid"] as String? ?? "";
      String department = "";
      if (uid.isNotEmpty) {
        final employee = await fs.getEmployee(uid);
        department = employee?.department ?? "";
      }
      userId.value = uid;
      userDepartment.value = department;
      isLoadingUser.value = false;
    } catch (e) {
      isLoadingUser.value = false;
    }
  }

  Future<void> toggleAnnouncementRead(String docId, bool markRead) async {
    if (userId.value.isEmpty) return;
    processingAnnouncements.add(docId);
    try {
      if (markRead) {
        await fs.markAnnouncementAsRead(docId, userId.value);
      } else {
        await fs.markAnnouncementAsUnread(docId, userId.value);
      }
    } finally {
      processingAnnouncements.remove(docId);
    }
  }

  void changeCategory(String category) {
    selectedCategory.value = category;
  }

  bool isTargetedAnnouncement(Map<String, dynamic> data) {
    final targetType = data["targetType"] as String? ?? "all";
    if (targetType == "all") return true;
    if (userId.value.isEmpty) return false;

    if (targetType == "employees") {
      final ids = (data["targetEmployeeIds"] as List<dynamic>?) ?? [];
      return ids.map((e) => e.toString()).contains(userId.value);
    }
    return true;
  }
}
