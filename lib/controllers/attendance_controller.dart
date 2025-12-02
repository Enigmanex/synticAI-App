import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';

class AttendanceController extends GetxController {
  final FirestoreService _fs = FirestoreService();

  RxBool loading = false.obs; // Keep for backward compatibility
  RxBool checkInLoading = false.obs;
  RxBool checkOutLoading = false.obs;
  RxBool hasLocationAccess = true.obs;

  @override
  void onInit() {
    super.onInit();
    _refreshLocationAccessStatus();
  }

  Future<void> _refreshLocationAccessStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      hasLocationAccess.value =
          serviceEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse);
    } catch (_) {
      hasLocationAccess.value = false;
    }
  }

  Future<bool> _ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      hasLocationAccess.value = false;
      Get.snackbar(
        "Location",
        "Location services are disabled. Please enable them in settings.",
        mainButton: TextButton(
          onPressed: () => Geolocator.openLocationSettings(),
          child: const Text("Open Settings"),
        ),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      hasLocationAccess.value = false;
      Get.snackbar(
        "Location",
        "Location permissions are denied. Grant permission to proceed.",
        mainButton: TextButton(
          onPressed: () => Geolocator.openAppSettings(),
          child: const Text("Grant Permission"),
        ),
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      hasLocationAccess.value = false;
      Get.snackbar(
        "Location",
        "Location permissions are blocked. Enable them in the app settings.",
        mainButton: TextButton(
          onPressed: () => Geolocator.openAppSettings(),
          child: const Text("Open Settings"),
        ),
      );
      return false;
    }

    hasLocationAccess.value = true;
    return true;
  }

  Future<String?> _getCurrentAddress() async {
    try {
      if (!await _ensureLocationAccess()) {
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Convert coordinates to address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = _formatAddress(place);
        return address;
      }

      return null;
    } catch (e) {
      Get.snackbar("Location Error", "Failed to get location: ${e.toString()}");
      return null;
    }
  }

  String _formatAddress(Placemark place) {
    List<String> addressParts = [];

    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      addressParts.add(place.country!);
    }

    return addressParts.isNotEmpty
        ? addressParts.join(", ")
        : "Location unavailable";
  }

  Future<void> checkIn() async {
    checkInLoading.value = true;
    loading.value = true; // Keep for backward compatibility
    try {
      String? address = await _getCurrentAddress();
      if (address == null) {
        return;
      }
      final user = await LocalStorage.getUser();
      await _fs.recordAttendance(user["uid"], "check_in", address);
      Get.snackbar("Success", "Checked in successfully");
    } catch (e) {
      Get.snackbar("Error", "Failed to check in: ${e.toString()}");
    } finally {
      checkInLoading.value = false;
      loading.value = false; // Keep for backward compatibility
    }
  }

  Future<void> checkOut() async {
    checkOutLoading.value = true;
    loading.value = true; // Keep for backward compatibility
    try {
      String? address = await _getCurrentAddress();
      if (address == null) {
        return;
      }
      final user = await LocalStorage.getUser();
      await _fs.recordAttendance(user["uid"], "check_out", address);
      Get.snackbar("Success", "Checked out successfully");
    } catch (e) {
      Get.snackbar("Error", "Failed to check out: ${e.toString()}");
    } finally {
      checkOutLoading.value = false;
      loading.value = false; // Keep for backward compatibility
    }
  }
}
