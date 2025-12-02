import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:open_filex/open_filex.dart';

import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import '../utils/app_colors.dart';

class LeaveTypeOption {
  final String name;
  final IconData icon;
  final List<Color> gradient;
  final List<LeaveSubTypeOption> subTypes;

  const LeaveTypeOption({
    required this.name,
    required this.icon,
    required this.gradient,
    required this.subTypes,
  });
}

class LeaveSubTypeOption {
  final String name;
  final IconData icon;

  const LeaveSubTypeOption({required this.name, required this.icon});
}

enum DocumentPreviewType { image, video, pdf, other }

const Set<String> _imageExtensions = {
  "png",
  "jpg",
  "jpeg",
  "gif",
  "bmp",
  "webp",
};

const Set<String> _videoExtensions = {
  "mp4",
  "mov",
  "mkv",
  "webm",
  "avi",
  "flv",
  "3gp",
};

class LeaveApplicationFlowScreen extends StatefulWidget {
  const LeaveApplicationFlowScreen({super.key});

  @override
  State<LeaveApplicationFlowScreen> createState() =>
      _LeaveApplicationFlowScreenState();
}

class _LeaveApplicationFlowScreenState
    extends State<LeaveApplicationFlowScreen> {
  final FirestoreService _fs = FirestoreService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _reasonController = TextEditingController();
  final PageController _pageController = PageController();

  final List<LeaveTypeOption> _leaveTypes = [
    LeaveTypeOption(
      name: "Sick Leave",
      icon: Icons.health_and_safety,
      gradient: [AppColors.gradientStart, AppColors.gradientEnd],
      subTypes: const [
        LeaveSubTypeOption(
          name: "Fever / Diarrhea",
          icon: Icons.thermostat_outlined,
        ),
        LeaveSubTypeOption(name: "High BP", icon: Icons.local_fire_department),
        LeaveSubTypeOption(name: "Injury / Accident", icon: Icons.healing),
      ],
    ),
    LeaveTypeOption(
      name: "Work Leave",
      icon: Icons.work_outline,
      gradient: [AppColors.gradientStart, AppColors.gradientEnd],
      subTypes: const [
        LeaveSubTypeOption(name: "Client Meeting", icon: Icons.handshake),
        LeaveSubTypeOption(name: "Training", icon: Icons.school_outlined),
        LeaveSubTypeOption(name: "Field Work", icon: Icons.map_outlined),
      ],
    ),
    LeaveTypeOption(
      name: "Emergency Leave",
      icon: Icons.warning_amber_outlined,
      // gradient: [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
      gradient: [AppColors.gradientStart, AppColors.gradientEnd],

      subTypes: const [
        LeaveSubTypeOption(
          name: "Family Emergency",
          icon: Icons.family_restroom,
        ),
        LeaveSubTypeOption(name: "Vehicle Breakdown", icon: Icons.car_repair),
        LeaveSubTypeOption(
          name: "Medical",
          icon: Icons.local_hospital_outlined,
        ),
      ],
    ),
    LeaveTypeOption(
      name: "Personal Leave",
      icon: Icons.nature,
      gradient: [AppColors.gradientStart, AppColors.gradientEnd],
      subTypes: const [
        LeaveSubTypeOption(name: "Errand", icon: Icons.local_shipping_outlined),
        LeaveSubTypeOption(name: "Relocation", icon: Icons.home_work),
        LeaveSubTypeOption(name: "Other", icon: Icons.note_add_outlined),
      ],
    ),
  ];

  LeaveTypeOption? _selectedType;
  LeaveSubTypeOption? _selectedSubType;
  DateTime? _startDate;
  DateTime? _endDate;
  File? _supportingDocument;
  String? _documentName;
  int _currentStep = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime initial = isStart
        ? _startDate ?? DateTime.now()
        : _endDate ?? _startDate ?? DateTime.now();
    final DateTime firstDate = isStart
        ? DateTime.now()
        : _startDate ?? DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    if (file.path == null) {
      Get.snackbar("Unsupported file", "Selected file cannot be processed.");
      return;
    }
    setState(() {
      _supportingDocument = File(file.path!);
      _documentName = file.name;
    });
  }

  Future<String?> _uploadSupportingDocument(File document) async {
    try {
      final ref = _storage.ref().child(
        'leave_documents/${DateTime.now().millisecondsSinceEpoch}_${document.path.split("/").last}',
      );
      await ref.putFile(document);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      Get.snackbar("Upload Error", "Failed to upload document: ${e.message}");
      return null;
    }
  }

  void _goToNextStep() {
    if (_currentStep == 0) {
      if (_selectedType == null) {
        Get.snackbar("Validation", "Please select a leave type first.");
        return;
      }
      if (_startDate == null) {
        Get.snackbar("Validation", "Please pick a start date.");
        return;
      }
      if (_endDate == null) {
        Get.snackbar("Validation", "Please pick an end date.");
        return;
      }
      if (_endDate!.isBefore(_startDate!)) {
        Get.snackbar("Validation", "End date cannot be before start date.");
        return;
      }
      if (_reasonController.text.trim().isEmpty) {
        Get.snackbar("Validation", "Please share a reason for leave.");
        return;
      }
    }
    if (_currentStep == 1) {
      if (_selectedSubType == null) {
        Get.snackbar("Validation", "Please choose a leave sub-type.");
        return;
      }
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToPreviousStep() {
    if (_currentStep == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submitApplication() async {
    if (_selectedType == null || _selectedSubType == null) {
      return;
    }
    setState(() => _isSubmitting = true);
    String? documentUrl;
    try {
      if (_supportingDocument != null) {
        documentUrl = await _uploadSupportingDocument(_supportingDocument!);
      }
      final user = await LocalStorage.getUser();
      final employee = await _fs.getEmployee(user["uid"]);
      final employeeName = employee?.name ?? user["email"];
      await _fs.createLeaveApplication(
        employeeId: user["uid"],
        employeeName: employeeName,
        employeeEmail: user["email"],
        reason: _reasonController.text.trim(),
        imageUrl: null,
        startDate: _startDate!,
        endDate: _endDate!,
        leaveType: _selectedType!.name,
        leaveSubType: _selectedSubType!.name,
        documentUrl: documentUrl,
        documentName: _documentName,
      );
      setState(() => _isSubmitting = false);

      await _showSuccessAnimation();
      if (!mounted) return;
      Get.back();
    } catch (e) {
      Get.snackbar("Error", "Failed to submit leave: ${e.toString()}");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildTypeSelectionStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Choose Leave Type",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 15,
              runSpacing: 12,
              children: _leaveTypes.map((typeOption) {
                final isSelected = _selectedType == typeOption;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = typeOption;
                      _selectedSubType = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 170,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: typeOption.gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Colors.white, Colors.white],
                            ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey.shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? typeOption.gradient.last.withOpacity(0.35)
                              : Colors.grey.shade200,
                          blurRadius: isSelected ? 14 : 8,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white.withOpacity(0.25)
                                : Colors.grey.shade100,
                          ),
                          child: Icon(
                            typeOption.icon,
                            size: 28,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          typeOption.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _buildDateField(
              label: "Start Date",
              date: _startDate,
              onTap: () => _pickDate(isStart: true),
            ),
            const SizedBox(height: 16),
            _buildDateField(
              label: "End Date",
              date: _endDate,
              onTap: () => _pickDate(isStart: false),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                hintText: "Reason for Leave",

                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickDocument,
              icon: const Icon(Icons.attach_file_outlined),
              label: Padding(
                padding: const EdgeInsets.all(12.0),
                child: const Text("Upload Supporting Document (Optional)"),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            if (_documentName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.insert_drive_file, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _documentName!,
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _supportingDocument = null;
                        _documentName = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final displayText = date != null
        ? "${date.day}/${date.month}/${date.year}"
        : "Select $label";
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  color: date != null ? Colors.grey.shade800 : Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTypeSelectionStep() {
    final options = _selectedType?.subTypes ?? <LeaveSubTypeOption>[];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Choose Leave Sub-Type",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_selectedType == null)
            const Text("Select a leave type from the previous step first.")
          else if (options.isEmpty)
            const Text(
              "No predefined sub-options. Please proceed with your own reason.",
            )
          else
            Column(
              children: options.map((subtype) {
                final isSelected = _selectedSubType == subtype;
                final gradient =
                    _selectedType?.gradient ??
                    [AppColors.primary, AppColors.primaryLight];
                return InkWell(
                  onTap: () {
                    setState(() => _selectedSubType = subtype);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white70,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 1.8 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: gradient.last.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isSelected
                                  ? gradient
                                  : const [Colors.white, Colors.white],
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Icon(
                            subtype.icon,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            subtype.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    final String range;
    final bool hasFullRange = _startDate != null && _endDate != null;
    if (hasFullRange) {
      range =
          "${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}";
    } else {
      range = "--";
    }
    final durationDays = hasFullRange
        ? _endDate!.difference(_startDate!).inDays + 1
        : null;
    final durationLabel = durationDays != null
        ? "$durationDays day${durationDays == 1 ? '' : 's'}"
        : "--";
    final typeName = _selectedType?.name ?? "Leave type not selected";
    final heroIcon = _selectedType?.icon ?? Icons.calendar_month;
    final subTypeName = _selectedSubType?.name ?? "Not selected";
    final reasonText = _reasonController.text.trim();
    final docLabel = _documentName ?? "Not uploaded";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Review & Submit",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withOpacity(0.4),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24,
                      ),
                      child: Icon(heroIcon, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Leave type",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  range,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Sub-type: $subTypeName",
                  style: TextStyle(color: Colors.white.withOpacity(0.85)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    _buildHeroChip("Duration", durationLabel),
                    _buildHeroChip(
                      "Document",
                      _documentName != null ? "Attached" : "Optional",
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Summary Details",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummaryTile(
                  "Sub-Type",
                  subTypeName,
                  icon: Icons.category,
                ),
                _buildSummaryTile(
                  "Date Range",
                  range,
                  icon: Icons.calendar_today,
                ),
                _buildDetailCard(
                  title: "Reason",
                  icon: Icons.chat_bubble_outline,
                  child: Text(
                    reasonText.isEmpty ? "No reason provided yet." : reasonText,
                    style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                  ),
                ),
                _buildDetailCard(
                  title: "Supporting Document",
                  icon: Icons.insert_drive_file_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docLabel,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "File uploads upon submission${_documentName == null ? " (optional)" : ""}.",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_supportingDocument != null)
                  _buildDocumentPreview(_supportingDocument!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String title, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        elevation: 0,
        shadowColor: AppColors.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: icon != null
                ? CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(icon, color: AppColors.primary, size: 20),
                  )
                : null,
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white24,
      ),
      child: Text(
        "$label: $value",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDocumentPreview(File file) {
    final previewType = _getDocumentPreviewType(file);
    final fileLabel = _documentName ?? file.uri.pathSegments.last;
    final previewContent = previewType == DocumentPreviewType.image
        ? ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              file,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        : Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey.shade100,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _documentPreviewIcon(previewType),
                    size: 42,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    previewType == DocumentPreviewType.pdf
                        ? "PDF Attachment"
                        : previewType == DocumentPreviewType.video
                        ? "Video Attachment"
                        : "Attachment preview",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openDocument(file),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              previewContent,
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _documentPreviewIcon(previewType),
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _documentPreviewPrompt(previewType),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DocumentPreviewType _getDocumentPreviewType(File file) {
    final segments = file.uri.pathSegments;
    if (segments.isEmpty) return DocumentPreviewType.other;
    final fileName = segments.last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return DocumentPreviewType.other;
    }
    final ext = fileName.substring(dotIndex + 1).toLowerCase();
    if (_imageExtensions.contains(ext)) return DocumentPreviewType.image;
    if (_videoExtensions.contains(ext)) return DocumentPreviewType.video;
    if (ext == "pdf") return DocumentPreviewType.pdf;
    return DocumentPreviewType.other;
  }

  IconData _documentPreviewIcon(DocumentPreviewType type) {
    switch (type) {
      case DocumentPreviewType.video:
        return Icons.play_circle_fill;
      case DocumentPreviewType.pdf:
        return Icons.picture_as_pdf;
      case DocumentPreviewType.image:
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _documentPreviewPrompt(DocumentPreviewType type) {
    switch (type) {
      case DocumentPreviewType.image:
        return "Tap to view the full image";
      case DocumentPreviewType.video:
        return "Tap to play the video";
      case DocumentPreviewType.pdf:
        return "Tap to open the PDF";
      default:
        return "Tap to open the file";
    }
  }

  Future<void> _openDocument(File file) async {
    try {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        Get.snackbar("Cannot open file", result.message);
      }
    } catch (e) {
      Get.snackbar(
        "Cannot open file",
        "Unable to open the document (${e.toString()}).",
      );
    }
  }

  Future<void> _showSuccessAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/Success animation.json',
                height: 200,
                repeat: false,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              const Text(
                "Leave submitted!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                "Your application is on its way to the admin team.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text("Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions() {
    final isFinalStep = _currentStep == 2;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(onPressed: _goToPreviousStep, child: const Text("Back")),
          const Spacer(),
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    if (isFinalStep) {
                      _submitApplication();
                    } else {
                      _goToNextStep();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(140, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(isFinalStep ? "Submit" : "Next"),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? AppColors.primary
                    : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text("Leave Application"),
        centerTitle: true,
      ),
      body: Container(
        width: size.width,
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildProgressIndicator(),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) =>
                        setState(() => _currentStep = index),
                    children: [
                      _buildTypeSelectionStep(),
                      _buildSubTypeSelectionStep(),
                      _buildSummaryStep(),
                    ],
                  ),
                ),
              ),

              _buildFooterActions(),
            ],
          ),
        ),
      ),
    );
  }
}
