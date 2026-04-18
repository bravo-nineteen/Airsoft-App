import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_model.dart';

class ContactRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ContactModel>> getContacts() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in.');

    final List<dynamic> response = await _client
        .from('user_contacts')
        .select('id, requester_id, addressee_id, status')
        .or('requester_id.eq.${user.id},addressee_id.eq.${user.id}')
        .order('created_at', ascending: false);

    final Set<String> profileIds = <String>{};
    for (final dynamic row in response) {
      profileIds.add(row['requester_id'].toString());
      profileIds.add(row['addressee_id'].toString());
    }

    final Map<String, Map<String, dynamic>> profilesById =
        <String, Map<String, dynamic>>{};
    if (profileIds.isNotEmpty) {
      final List<dynamic> profilesResponse = await _client
          .from('profiles')
          .select('id, call_sign, user_code')
          .inFilter('id', profileIds.toList());

      for (final dynamic row in profilesResponse) {
        profilesById[row['id'].toString()] = Map<String, dynamic>.from(
          row as Map,
        );
      }
    }

    return response.map<ContactModel>((dynamic row) {
      final Map<String, dynamic> mapped = Map<String, dynamic>.from(row as Map);
      mapped['requester_profile'] = profilesById[mapped['requester_id'].toString()];
      mapped['addressee_profile'] = profilesById[mapped['addressee_id'].toString()];
      return ContactModel.fromJson(mapped);
    }).toList();
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
