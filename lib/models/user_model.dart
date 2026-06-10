class UserModel {
  final String id;
  final String idPegawai;
  final String email;
  final String username;

  UserModel({
    required this.id,
    required this.idPegawai,
    required this.email,
    required this.username,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:         json['id']?.toString() ?? '',
      idPegawai:  json['id_pegawai']?.toString() ?? '',
      email:      json['email'] ?? '',
      username:   json['username'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id':         id,
    'id_pegawai': idPegawai,
    'email':      email,
    'username':   username,
  };
}