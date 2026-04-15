class ContactModel {
  const ContactModel({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final String status;

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'].toString(),
      requesterId: json['requester_id'].toString(),
      addresseeId: json['addressee_id'].toString(),
      status: json['status'] as String,
    );
  }
}