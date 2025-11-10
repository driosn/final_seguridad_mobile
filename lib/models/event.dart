class Event {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> registeredUsers;
  final Map<String, bool> checkIns;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.registeredUsers,
    required this.checkIns,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // Manejar createdBy que puede venir como string o como objeto
    String createdByValue = '';
    if (json['createdBy'] != null) {
      if (json['createdBy'] is String) {
        createdByValue = json['createdBy'];
      } else if (json['createdBy'] is Map) {
        createdByValue =
            json['createdBy']['_id'] ?? json['createdBy']['id'] ?? '';
      }
    }

    // Manejar registeredUsers que puede venir como lista de strings o lista de objetos
    List<String> registeredUsersList = [];
    if (json['registeredUsers'] != null) {
      final users = json['registeredUsers'];
      if (users is List) {
        registeredUsersList = users
            .map((user) {
              if (user is String) {
                return user;
              } else if (user is Map) {
                return user['_id'] ?? user['id'] ?? '';
              }
              return '';
            })
            .where((id) => id.isNotEmpty)
            .toList()
            .cast<String>();
      }
    }

    // Manejar checkIns que puede tener valores que no son booleanos
    Map<String, bool> checkInsMap = {};
    if (json['checkIns'] != null && json['checkIns'] is Map) {
      json['checkIns'].forEach((key, value) {
        if (value is bool) {
          checkInsMap[key] = value;
        } else {
          // Convertir a bool si viene como otro tipo
          checkInsMap[key] = value == true || value == 1 || value == 'true';
        }
      });
    }

    return Event(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdBy: createdByValue,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
      registeredUsers: registeredUsersList,
      checkIns: checkInsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'description': description};
  }
}
