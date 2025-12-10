import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import '../utils/app_colors.dart';

class DailyProgressScreen extends StatefulWidget {
  const DailyProgressScreen({super.key});

  @override
  State<DailyProgressScreen> createState() => _DailyProgressScreenState();
}

class _DailyProgressScreenState extends State<DailyProgressScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  final TextEditingController _topicController = TextEditingController();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _selectedDocument;
  String? _documentUrl;
  String? _documentName;
  bool _isUploading = false;
  bool _isSubmitting = false;
  DateTime _selectedDate = DateTime.now();
  String _userId = "";
  String _userName = "";
  String _userEmail = "";
  
  late TabController _tabController;
  String _viewMode = "all"; // "today", "month", "all"
  DateTime _selectedMonth = DateTime.now();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _progressStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final user = await LocalStorage.getUser();
    final employee = await _fs.getEmployee(user["uid"]);
    if (mounted) {
      setState(() {
        _userId = user["uid"];
        _userName = employee?.name ?? "";
        _userEmail = employee?.email ?? "";
        // Initialize stream only once when userId is loaded
        if (_progressStream == null && _userId.isNotEmpty) {
          _progressStream = _fs.getInternProgressByIntern(_userId);
        }
      });
    }
  }


  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _selectedDocument = File(file.path!);
            _documentName = file.name;
            _documentUrl = null; // Reset previous URL
          });
        }
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick document: ${e.toString()}");
    }
  }

  Future<String?> _uploadDocument(File document) async {
    try {
      setState(() => _isUploading = true);
      final ref = _storage.ref().child(
        'daily_progress/${_userId}_${DateTime.now().millisecondsSinceEpoch}_${document.path.split("/").last}',
      );
      await ref.putFile(document);
      final url = await ref.getDownloadURL();
      setState(() => _isUploading = false);
      return url;
    } catch (e) {
      setState(() => _isUploading = false);
      Get.snackbar(
        "Upload Error",
        "Failed to upload document: ${e.toString()}",
      );
      return null;
    }
  }

  Future<void> _submitProgress() async {
    if (_topicController.text.trim().isEmpty) {
      Get.snackbar("Error", "Please enter a topic name");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? documentUrl = _documentUrl;

      // Upload document if a new one is selected
      if (_selectedDocument != null) {
        documentUrl = await _uploadDocument(_selectedDocument!);
        if (documentUrl == null) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      await _fs.submitDailyProgress(
        internId: _userId,
        internName: _userName,
        internEmail: _userEmail,
        topicName: _topicController.text.trim(),
        date: _selectedDate,
        documentUrl: documentUrl,
        documentName: _documentName,
      );

      Get.snackbar("Success", "Daily progress submitted successfully");

      // Reset form
      _topicController.clear();
      setState(() {
        _selectedDocument = null;
        _documentUrl = null;
        _documentName = null;
        _selectedDate = DateTime.now();
      });
    } catch (e) {
      Get.snackbar("Error", "Failed to submit progress: ${e.toString()}");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
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
              "Daily Progress",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: "Submit Progress", icon: Icon(Icons.add_circle_outline)),
              Tab(text: "My Submissions", icon: Icon(Icons.history)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Tabs
              _buildHeader(),
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Submit Progress Tab
                    SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Form Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                      // Date Picker
                      Text(
                        "Date",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat(
                                  'MMMM d, yyyy',
                                ).format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Topic Name
                      Text(
                        "Topic Name *",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _topicController,
                        decoration: InputDecoration(
                          hintText: "Enter the topic you worked on today",
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Document Upload
                      Text(
                        "Upload Work Document (Optional)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedDocument != null || _documentUrl != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _documentName ?? "Document",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedDocument = null;
                                    _documentUrl = null;
                                    _documentName = null;
                                  });
                                },
                                icon: Icon(Icons.close, color: Colors.red),
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          onTap: _pickDocument,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                style: BorderStyle.solid,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud_upload,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Tap to upload document",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "PDF, DOC, DOCX, JPG, PNG",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isSubmitting || _isUploading
                            ? null
                            : _submitProgress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting || _isUploading
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
                            : const Text(
                                "Submit Progress",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // View Previous Submissions Tab
                    _buildPreviousSubmissionsView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviousSubmissionsView() {
    if (_userId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Filter buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildFilterButton("Today", "today", Icons.today),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterButton("Month", "month", Icons.calendar_month),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterButton("All", "all", Icons.history),
              ),
            ],
          ),
        ),
        // Month picker (only shown when month mode is selected)
        if (_viewMode == "month")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedMonth,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      helpText: "Select Month",
                      initialDatePickerMode: DatePickerMode.year,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedMonth = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Submissions List
        Expanded(
          child: _userId.isEmpty || _progressStream == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  key: ValueKey(_userId), // Stable key to prevent unnecessary rebuilds
                  stream: _progressStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      // Log the error for debugging
                      print('StreamBuilder error: ${snapshot.error}');
                      print('Error stack: ${snapshot.stackTrace}');
                      
                      String errorMessage = snapshot.error.toString();
                      // Check if it's an index error
                      if (errorMessage.contains('index') || errorMessage.contains('failed-precondition')) {
                        errorMessage = 'Firestore index is still building. Please wait a few minutes and try again.';
                      }
                      
                      return Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  "Error loading submissions",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    errorMessage,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // Retry by reloading user info and recreating stream
                                    setState(() {
                                      _progressStream = null;
                                    });
                                    _loadUserInfo();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snapshot.data!.docs;

                    // Filter based on view mode
                    if (_viewMode == "today") {
                      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      docs = docs.where((doc) {
                        final data = doc.data();
                        final dateStr = data["date"] as String?;
                        return dateStr == today;
                      }).toList();
                    } else if (_viewMode == "month") {
                      final startDate = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month,
                        1,
                      );
                      final endDate = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                        0,
                      );
                      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
                      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
                      docs = docs.where((doc) {
                        final data = doc.data();
                        final dateStr = data["date"] as String?;
                        if (dateStr == null) return false;
                        return dateStr.compareTo(startDateStr) >= 0 &&
                            dateStr.compareTo(endDateStr) <= 0;
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              "No progress submissions found",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildSubmissionCard(docs[index]);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String label, String mode, IconData icon) {
    final isSelected = _viewMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _viewMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final topicName = data["topicName"] as String? ?? "";
    final date = data["date"] as String? ?? "";
    final documentUrl = data["documentUrl"] as String? ?? "";
    final documentName = data["documentName"] as String? ?? "";
    final createdAt = data["createdAt"]?.toDate();
    final remarks = data["remarks"] as String? ?? "";
    final remarksUpdatedAt = data["remarksUpdatedAt"]?.toDate();
    final hasDocument = documentUrl.isNotEmpty;
    final hasRemarks = remarks.isNotEmpty;

    String dateDisplay = date;
    try {
      if (date.isNotEmpty) {
        final dateTime = DateTime.parse(date);
        dateDisplay = DateFormat('MMMM d, yyyy').format(dateTime);
      }
    } catch (e) {
      // Keep original date string
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateDisplay,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        "Submitted: ${DateFormat('MMM d, y • h:mm a').format(createdAt)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dateDisplay.split(' ').first, // Show month abbreviation
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Topic:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            topicName,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          if (hasDocument) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(documentUrl);
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  Get.snackbar(
                    "Cannot open document",
                    "Please check your network or try again later.",
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        documentName.isNotEmpty ? documentName : "Work Document",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.open_in_new, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
          ],
          // Admin Remarks Section
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasRemarks
                  ? AppColors.primary.withOpacity(0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasRemarks
                    ? AppColors.primary.withOpacity(0.3)
                    : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.comment,
                      size: 18,
                      color: hasRemarks
                          ? AppColors.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Admin Remarks",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: hasRemarks
                            ? AppColors.primary
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                if (hasRemarks) ...[
                  const SizedBox(height: 8),
                  Text(
                    remarks,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                  if (remarksUpdatedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Updated: ${DateFormat('MMM d, y • h:mm a').format(remarksUpdatedAt)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "No remarks from admin yet",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
