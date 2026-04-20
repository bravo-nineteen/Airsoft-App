import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_model.dart';

class ContactRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ContactModel>> getContacts() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in.');

    final response = await _client
        .from('user_contacts')
        .select()
        .or('requester_id.eq.${user.id},addressee_id.eq.${user.id}')
        .order('created_at', ascending: false);

    return response
        .map<ContactModel>((e) => ContactModel.fromJson(e))
        .toList();
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

  Future<void> rejectRequest(String id) async {
    await _client.from('user_contacts').delete().eq('id', id);
  }

  Future<void> removeContact(String id) async {
    await _client.from('user_contacts').delete().eq('id', id);
  }

  Future<bool> areAcceptedContacts(String otherUserId) async {
    final current = _client.auth.currentUser;
    if (current == null) return false;

    final response = await _client
        .from('user_contacts')
        .select('id')
        .or(
          'and(requester_id.eq.${current.id},addressee_id.eq.$otherUserId),and(requester_id.eq.$otherUserId,addressee_id.eq.${current.id})',
        )
        .eq('status', 'accepted')
        .limit(1);

    return (response as List).isNotEmpty;
  }

  Future<int> getPendingRequestsCount() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    final response = await _client
        .from('user_contacts')
        .select('id')
        .eq('addressee_id', user.id)
        .eq('status', 'pending');

    return response.length;
  }
}