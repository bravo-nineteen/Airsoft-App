import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_model.dart';

class ContactRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ContactModel>> getContacts() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in.');

    final response = await _client
        .from('user_contacts')
        .select(
          'id, requester_id, addressee_id, status, '
          'requester_profile:profiles!user_contacts_requester_id_fkey(call_sign, user_code), '
          'addressee_profile:profiles!user_contacts_addressee_id_fkey(call_sign, user_code)',
        )
        .or('requester_id.eq.${user.id},addressee_id.eq.${user.id}')
        .order('created_at', ascending: false);

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

  Future<void> acceptRequest(ContactModel contact) async {
    await _client
        .from('user_contacts')
        .update({'status': 'accepted'})
        .eq('requester_id', contact.requesterId)
        .eq('addressee_id', contact.addresseeId)
        .eq('status', 'pending');
  }

  Future<void> rejectRequest(ContactModel contact) async {
    await _client
        .from('user_contacts')
        .delete()
        .eq('requester_id', contact.requesterId)
        .eq('addressee_id', contact.addresseeId);
  }

  Future<void> removeContact(ContactModel contact) async {
    await _client
        .from('user_contacts')
        .delete()
        .eq('requester_id', contact.requesterId)
        .eq('addressee_id', contact.addresseeId);
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
        .maybeSingle();

    return response != null;
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
