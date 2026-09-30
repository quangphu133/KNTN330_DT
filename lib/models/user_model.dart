class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final int id;
  final String fullName;
  final String email;
  final String role;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _readInt(json['id']),
      fullName: '${json['full_name'] ?? json['fullName'] ?? ''}',
      email: '${json['email'] ?? ''}',
      role: '${json['role'] ?? 'telesales'}',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'role': role,
  };
}

int _readInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
