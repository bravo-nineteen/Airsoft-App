class ContactModel {
  const ContactModel({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    this.requesterCallSign,
    this.addresseeCallSign,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final String status;
  final String? requesterCallSign;
  final String? addresseeCallSign;

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'].toString(),
      requesterId: json['requester_id'].toString(),
      addresseeId: json['addressee_id'].toString(),
      status: (json['status'] ?? 'pending').toString(),
      requesterCallSign: _readNestedCallSign(json['requester_profile']),
      addresseeCallSign: _readNestedCallSign(json['addressee_profile']),
    );
  }

  static String? _readNestedCallSign(dynamic value) {
    if (value is Map<String, dynamic>) {
      final raw = value['call_sign'];
      if (raw == null) return null;
      final text = raw.toString().trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }
}