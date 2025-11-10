class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final bool? attended; // Campo para check-in en eventos

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.attended,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      attended: json['attended'] is bool
          ? json['attended']
          : json['attended'] == true ||
                json['attended'] == 1 ||
                json['attended'] == 'true'
          ? true
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'isActive': isActive,
      if (attended != null) 'attended': attended,
    };
  }
}
