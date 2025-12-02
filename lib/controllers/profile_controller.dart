import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';

class ProfileController extends GetxController {
  final FirestoreService _fs = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  RxBool loading = false.obs;
  RxString name = ''.obs;
  RxString email = ''.obs;
  RxString profileImageUrl = ''.obs;
  Rx<File?> selectedImage = Rx<File?>(null);

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      loading.value = true;
      final user = await LocalStorage.getUser();
      
      // Get employee data with profile image
      final employeeDoc = await FirebaseFirestore.instance
          .collection("employees")
          .doc(user["uid"])
          .get();
      
      if (employeeDoc.exists) {
        final data = employeeDoc.data()!;
        name.value = data["name"] ?? '';
        email.value = data["email"] ?? '';
        profileImageUrl.value = data["profileImage"] ?? '';
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load profile: ${e.toString()}");
    } finally {
      loading.value = false;
    }
  }

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        selectedImage.value = File(image.path);
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick image: ${e.toString()}");
    }
  }

  Future<String?> uploadImage(File imageFile, String uid) async {
    try {
      final ref = _storage.ref().child('profile_images/$uid.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      Get.snackbar("Error", "Failed to upload image: ${e.toString()}");
      return null;
    }
  }

  Future<void> updateProfile() async {
    try {
      if (name.value.trim().isEmpty) {
        Get.snackbar("Error", "Name cannot be empty");
        return;
      }

      loading.value = true;
      final user = await LocalStorage.getUser();
      String? imageUrl;

      if (selectedImage.value != null) {
        imageUrl = await uploadImage(selectedImage.value!, user["uid"]);
        if (imageUrl != null) {
          profileImageUrl.value = imageUrl;
        }
      }

      await _fs.updateProfile(user["uid"], name.value.trim(), imageUrl);
      
      Get.snackbar("Success", "Profile updated successfully");
      selectedImage.value = null;
    } catch (e) {
      Get.snackbar("Error", "Failed to update profile: ${e.toString()}");
    } finally {
      loading.value = false;
    }
  }
}

