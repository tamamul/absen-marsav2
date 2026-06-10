import 'dart:convert';

class UserModel {
  final int     id;
  final String  name;
  final String  username;
  final String  role;
  final String? className;
  final String? jurusan;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.className,
    this.jurusan,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id:        json['id'] as int,
    name:      json['name'] as String,
    username:  json['username'] as String,
    role:      json['role'] as String,
    className: json['class'] as String?,
    jurusan:   json['jurusan'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id':      id,
    'name':    name,
    'username':username,
    'role':    role,
    'class':   className,
    'jurusan': jurusan,
  };

  String toJsonString() => jsonEncode(toJson());

  static UserModel fromJsonString(String s) =>
      UserModel.fromJson(jsonDecode(s) as Map<String, dynamic>);

  @override
  String toString() => 'UserModel(id: $id, name: $name, role: $role)';
}