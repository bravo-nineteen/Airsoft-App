import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_model.dart';

class ContactRepository {
  final _client = Supabase.instance.client;

  Future<List<ContactModel>> getContacts() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final response = await _client
        .from('user_contacts')
        .select()
        .or('requester_id.eq.${user.id},addressee_id.eq.${user.id}');

    return response.map<ContactModel>((e) => ContactModel.fromJson(e)).toList();
  }

  Future<void> sendRequest(String userId) async {
    final current = _client.auth.currentUser!;
    await _client.from('user_contacts').insert({
      'requester_id': current.id,
      'addressee_id': userId,
      'status': 'pending',
    });
  }

  Future<void> acceptRequest(String id) async {
    await _client
        .from('user_contacts')
        .update({'status': 'accepted'})
        .eq('id', id);
  }
}