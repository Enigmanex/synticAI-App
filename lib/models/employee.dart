class Employee {
  final String id;
  final String name;
  final String email;
  final bool admin;
  final String? profileImage;
  final String? department;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    this.admin = false,
    this.profileImage,
    this.department,
  });

  factory Employee.fromMap(String uid, Map<String, dynamic> map) {
    return Employee(
      id: uid,
      name: map["name"],
      email: map["email"],
      admin: (map["role"] == "admin"),
      profileImage: map["profileImage"],
      department: map["department"],
    );
  }
}
