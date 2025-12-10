class Employee {
  final String id;
  final String name;
  final String email;
  final bool admin;
  final String? profileImage;
  final String? department;
  final String role; // "admin", "employee", or "intern"

  Employee({
    required this.id,
    required this.name,
    required this.email,
    this.admin = false,
    this.profileImage,
    this.department,
    this.role = "employee",
  });

  bool get isIntern => role == "intern";
  bool get isEmployee => role == "employee";
  bool get isAdmin => role == "admin" || admin;

  factory Employee.fromMap(String uid, Map<String, dynamic> map) {
    final role = map["role"] as String? ?? "employee";
    return Employee(
      id: uid,
      name: map["name"],
      email: map["email"],
      admin: (role == "admin"),
      profileImage: map["profileImage"],
      department: map["department"],
      role: role,
    );
  }
}
