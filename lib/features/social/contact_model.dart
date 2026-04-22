class ContactModel {
  const ContactModel({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    this.createdAt,
    this.requesterCallSign,
    this.addresseeCallSign,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final String status;
  final DateTime? createdAt;
  final String? requesterCallSign;
  final String? addresseeCallSign;

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'].toString(),
      requesterId: json['requester_id'].toString(),
      addresseeId: json['addressee_id'].toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      requesterCallSign: _readNestedDisplayName(json['requester_profile']),
      addresseeCallSign: _readNestedDisplayName(json['addressee_profile']),
    );
  }

  static String? _readNestedDisplayName(dynamic value) {
    if (value is Map<String, dynamic>) {
      final raw = value['call_sign'] ?? value['user_code'];
      if (raw == null) return null;
      final text = raw.toString().trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }
}
