import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/employee.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import '../utils/app_colors.dart';
import '../utils/announcement_constants.dart';

class CreateAnnouncementDialog extends StatefulWidget {
  final String? announcementId;
  final Map<String, dynamic>? initialData;
  final VoidCallback? onSaved;

  const CreateAnnouncementDialog({
    super.key,
    this.announcementId,
    this.initialData,
    this.onSaved,
  });

  bool get isEditing => announcementId != null;

  @override
  State<CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState extends State<CreateAnnouncementDialog> {
  final FirestoreService _fs = FirestoreService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _selectedImage;
  File? _selectedPdf;
  bool _isUploading = false;
  bool _sendPushNotification =
      true; // Default to true - always send notifications
  String _selectedCategory = announcementCategories.first;
  String _targetAudience = announcementTargetAll;
  List<Employee> _allEmployees = [];
  Map<String, Employee> _employeeLookup = {};
  Set<String> _selectedEmployeeIds = {};
  bool _removeExistingImage = false;
  bool _removeExistingPdf = false;
  String? _existingImageUrl;
  String? _existingPdfUrl;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadEmployees();
  }

  void _initializeForm() {
    final data = widget.initialData;
    if (data == null) return;

    _titleController.text = data["title"] as String? ?? "";
    _textController.text = data["text"] as String? ?? "";
    _selectedCategory =
        (data["category"] as String?) ?? announcementCategories.first;
    _targetAudience = (data["targetType"] as String?) ?? announcementTargetAll;
    _departmentController.text = data["targetDepartment"] as String? ?? "";
    final selectedIds =
        (data["targetEmployeeIds"] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        {};
    // Filter out admin IDs if any were previously selected
    _selectedEmployeeIds = selectedIds;
    final imageValue = data["imageUrl"] as String?;
    _existingImageUrl = (imageValue?.isEmpty == true) ? null : imageValue;
    final pdfValue = data["pdfUrl"] as String?;
    _existingPdfUrl = (pdfValue?.isEmpty == true) ? null : pdfValue;
    _sendPushNotification = data["sendPushNotification"] as bool? ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _fs.getAllEmployees();
      if (!mounted) return;
      // Filter out admins - only show employees and interns
      final nonAdminEmployees = employees.where((e) => !e.isAdmin).toList();

      // Sort employees alphabetically by name (A to Z)
      nonAdminEmployees.sort((a, b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      final nonAdminEmployeeIds = nonAdminEmployees.map((e) => e.id).toSet();

      setState(() {
        _allEmployees = nonAdminEmployees;
        _employeeLookup = {
          for (var employee in nonAdminEmployees) employee.id: employee,
        };
        // Remove any admin IDs from selected employees if they exist
        _selectedEmployeeIds.removeWhere(
          (id) => !nonAdminEmployeeIds.contains(id),
        );
      });
    } catch (e) {
      Get.snackbar("Error", "Could not load employees");
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _removeExistingImage = false;
        });
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick image: ${e.toString()}");
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedPdf = File(result.files.single.path!);
          _removeExistingPdf = false;
        });
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick PDF: ${e.toString()}");
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final ref = _storage.ref().child(
        'announcements/images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      Get.snackbar("Error", "Failed to upload image: ${e.toString()}");
      return null;
    }
  }

  Future<String?> _uploadPdf(File pdfFile) async {
    try {
      final ref = _storage.ref().child(
        'announcements/pdfs/${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await ref.putFile(pdfFile);
      return await ref.getDownloadURL();
    } catch (e) {
      Get.snackbar("Error", "Failed to upload PDF: ${e.toString()}");
      return null;
    }
  }

  Future<void> _submitAnnouncement() async {
    if (_titleController.text.trim().isEmpty) {
      Get.snackbar("Error", "Title cannot be empty");
      return;
    }

    if (_textController.text.trim().isEmpty &&
        _selectedImage == null &&
        _selectedPdf == null &&
        _existingImageUrl == null &&
        _existingPdfUrl == null) {
      Get.snackbar("Error", "Add text or upload an attachment");
      return;
    }

    if (_targetAudience == announcementTargetEmployees &&
        _selectedEmployeeIds.isEmpty) {
      Get.snackbar("Error", "Select at least one employee");
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = await LocalStorage.getUser();
      String? imageUrl;
      String? pdfUrl;

      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      } else if (_removeExistingImage) {
        imageUrl = "";
      } else {
        imageUrl = _existingImageUrl;
      }

      if (_selectedPdf != null) {
        pdfUrl = await _uploadPdf(_selectedPdf!);
      } else if (_removeExistingPdf) {
        pdfUrl = "";
      } else {
        pdfUrl = _existingPdfUrl;
      }

      final category = _selectedCategory;
      final targetType = _targetAudience;

      final targetEmployeeIds = targetType == announcementTargetEmployees
          ? _selectedEmployeeIds.toList()
          : null;

      if (widget.isEditing) {
        await _fs.updateAnnouncement(
          widget.announcementId!,
          title: _titleController.text.trim(),
          text: _textController.text.trim(),
          imageUrl: imageUrl,
          pdfUrl: pdfUrl,
          category: category,
          targetType: targetType,
          targetEmployeeIds: targetEmployeeIds ?? [],
          sendPushNotification: _sendPushNotification,
        );
      } else {
        await _fs.createAnnouncement(
          title: _titleController.text.trim(),
          text: _textController.text.trim(),
          imageUrl: imageUrl,
          pdfUrl: pdfUrl,
          adminId: user["uid"],
          category: category,
          targetType: targetType,
          targetEmployeeIds: targetEmployeeIds,
          sendPushNotification: _sendPushNotification,
        );
      }

      widget.onSaved?.call();
      Get.back();
      Get.snackbar(
        "Success",
        widget.isEditing
            ? "Announcement updated"
            : "Announcement created successfully",
      );

      if (_sendPushNotification) {
        Get.snackbar(
          "Push Notification",
          "New Announcement Posted: ${_titleController.text.trim()}",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to save announcement: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _selectEmployees() async {
    if (_allEmployees.isEmpty) {
      await _loadEmployees();
    }

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final tempSelection = Set<String>.from(_selectedEmployeeIds);
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Select Employees",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                if (_allEmployees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: _allEmployees.map((employee) {
                        return CheckboxListTile(
                          title: Text(employee.name),
                          subtitle: Text(employee.email),
                          value: tempSelection.contains(employee.id),
                          onChanged: (isChecked) {
                            setModalState(() {
                              if (isChecked == true) {
                                tempSelection.add(employee.id);
                              } else {
                                tempSelection.remove(employee.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, tempSelection),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text("Apply Selection"),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() => _selectedEmployeeIds = result);
    }
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: announcementCategories.map((category) {
        final isSelected = category == _selectedCategory;
        return ChoiceChip(
          checkmarkColor: Colors.white,
          label: Text(category),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedCategory = category),
          selectedColor: AppColors.primary,
          backgroundColor: Colors.grey.shade100,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTargetAudienceChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: announcementTargetOptions.map((value) {
        final label = announcementTargetLabels[value] ?? value;
        final isSelected = _targetAudience == value;
        return ChoiceChip(
          checkmarkColor: Colors.white,
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => setState(() => _targetAudience = value),
          selectedColor: AppColors.primary,
          backgroundColor: Colors.grey.shade100,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedEmployeeChips() {
    if (_selectedEmployeeIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _selectedEmployeeIds.map((id) {
        final name =
            _employeeLookup[id]?.name ??
            _allEmployees
                .firstWhere(
                  (e) => e.id == id,
                  orElse: () => Employee(id: id, name: "Employee", email: ""),
                )
                .name;
        return Chip(
          label: Text(name),
          onDeleted: () {
            setState(() => _selectedEmployeeIds.remove(id));
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing
        ? "Edit Announcement"
        : "Create Announcement";
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 780),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: "Title *",
                  filled: true,
                  fillColor: Colors.white38,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _textController,

                maxLines: 5,
                decoration: InputDecoration(
                  hintText: "Description *",
                  filled: true,
                  fillColor: Colors.white38,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text("Category"),
              const SizedBox(height: 8),
              _buildCategoryChips(),
              const SizedBox(height: 20),
              const Text("Target Audience"),
              const SizedBox(height: 8),
              _buildTargetAudienceChips(),

              if (_targetAudience == announcementTargetEmployees) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _selectEmployees,
                  icon: const Icon(Icons.people, color: Colors.white),

                  label: const Text(
                    "Select Employees",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildSelectedEmployeeChips(),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image, color: Colors.white),
                      label: const Text(
                        "Add Image",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Add PDF",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedImage != null || _existingImageUrl != null) ...[
                const SizedBox(height: 16),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _selectedImage != null
                          ? Image.file(
                              _selectedImage!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              _existingImageUrl!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                            _existingImageUrl = null;
                            _removeExistingImage = true;
                          });
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_selectedPdf != null || _existingPdfUrl != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedPdf != null
                              ? "PDF selected"
                              : "Existing PDF attached",
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedPdf = null;
                            _existingPdfUrl = null;
                            _removeExistingPdf = true;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitAnnouncement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          widget.isEditing
                              ? "Update Announcement"
                              : "Create Announcement",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
