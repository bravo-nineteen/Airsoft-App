import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_model.dart';
import '../notifications/notification_writer.dart';

enum ContactRelationshipAction {
  add,
  outgoingPending,
  incomingPending,
  friends,
  self,
}

class ContactRelationshipState {
  const ContactRelationshipState({
    required this.action,
    this.contact,
  });

  final ContactRelationshipAction action;
  final ContactModel? contact;

  bool get canSendRequest => action == ContactRelationshipAction.add;
  bool get canAcceptRequest =>
      action == ContactRelationshipAction.incomingPending && contact != null;
}

ContactRelationshipState deriveContactRelationshipState({
  required List<ContactModel> contacts,
  required String currentUserId,
  required String otherUserId,
}) {
  if (currentUserId == otherUserId) {
    return const ContactRelationshipState(
      action: ContactRelationshipAction.self,
    );
  }

  ContactModel? outgoingPending;
  ContactModel? incomingPending;

  for (final ContactModel contact in contacts) {
    final bool matchesPair =
        (contact.requesterId == currentUserId &&
            contact.addresseeId == otherUserId) ||
        (contact.requesterId == otherUserId &&
            contact.addresseeId == currentUserId);
    if (!matchesPair) {
      continue;
    }

    if (contact.status == 'accepted') {
      return ContactRelationshipState(
        action: ContactRelationshipAction.friends,
        contact: contact,
      );
    }

    if (contact.status != 'pending') {
      continue;
    }

    if (contact.requesterId == otherUserId) {
      incomingPending ??= contact;
    } else {
      outgoingPending ??= contact;
    }
  }

  if (incomingPending != null) {
    return ContactRelationshipState(
      action: ContactRelationshipAction.incomingPending,
      contact: incomingPending,
    );
  }

  if (outgoingPending != null) {
    return ContactRelationshipState(
      action: ContactRelationshipAction.outgoingPending,
      contact: outgoingPending,
    );
  }

  return const ContactRelationshipState(action: ContactRelationshipAction.add);
}

class ContactRepository {
  ContactRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client,
      _notificationWriter = NotificationWriter(client: client);

  final SupabaseClient _client;
  final NotificationWriter _notificationWriter;

  String get _currentUserId {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }
    return user.id;
  }

  Future<List<ContactModel>> getContacts() async {
    final String userId = _currentUserId;

    final List<dynamic> response = await _client
        .from('user_contacts')
        .select('id, requester_id, addressee_id, status, created_at')
        .or('requester_id.eq.$userId,addressee_id.eq.$userId')
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> dedupedRows = <Map<String, dynamic>>[];
    final Map<String, int> pairIndexByKey = <String, int>{};

    for (final dynamic row in response) {
      final Map<String, dynamic> mapped = Map<String, dynamic>.from(row as Map);
      final String requesterId = mapped['requester_id'].toString();
      final String addresseeId = mapped['addressee_id'].toString();
      final List<String> pair = <String>[requesterId, addresseeId]..sort();
      final String pairKey = pair.join('::');
      final int? existingIndex = pairIndexByKey[pairKey];

      if (existingIndex == null) {
        pairIndexByKey[pairKey] = dedupedRows.length;
        dedupedRows.add(mapped);
        continue;
      }

      final Map<String, dynamic> existing = dedupedRows[existingIndex];
      final String existingStatus = (existing['status'] ?? 'pending').toString();
      final String nextStatus = (mapped['status'] ?? 'pending').toString();
      if (existingStatus != 'accepted' && nextStatus == 'accepted') {
        dedupedRows[existingIndex] = mapped;
      }
    }

    final Set<String> profileIds = <String>{};
    for (final Map<String, dynamic> row in dedupedRows) {
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
          row,
        );
      }
    }

    return dedupedRows.map<ContactModel>((Map<String, dynamic> mapped) {
      mapped['requester_profile'] = profilesById[mapped['requester_id'].toString()];
      mapped['addressee_profile'] = profilesById[mapped['addressee_id'].toString()];
      return ContactModel.fromJson(mapped);
    }).toList();
  }

  Future<Map<String, ContactRelationshipState>> getRelationshipStates(
    Iterable<String> otherUserIds,
  ) async {
    final String currentUserId = _currentUserId;
    final List<String> normalizedIds = otherUserIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) {
      return <String, ContactRelationshipState>{};
    }

    final List<ContactModel> contacts = await getContacts();
    return <String, ContactRelationshipState>{
      for (final String otherUserId in normalizedIds)
        otherUserId: deriveContactRelationshipState(
          contacts: contacts,
          currentUserId: currentUserId,
          otherUserId: otherUserId,
        ),
    };
  }

  Future<void> sendRequest(String userId) async {
    final String currentUserId = _currentUserId;
    if (currentUserId == userId) {
      throw Exception('You cannot add yourself.');
    }

    final List<dynamic> existingRows = await _client
        .from('user_contacts')
        .select('id, requester_id, addressee_id, status, created_at')
        .or(
          'and(requester_id.eq.$currentUserId,addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.$currentUserId)',
        )
        .order('created_at', ascending: false);

    final List<ContactModel> existingContacts = existingRows
        .map(
          (dynamic row) =>
              ContactModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    final ContactRelationshipState relationshipState =
        deriveContactRelationshipState(
          contacts: existingContacts,
          currentUserId: currentUserId,
          otherUserId: userId,
        );

    if (relationshipState.action == ContactRelationshipAction.friends ||
        relationshipState.action == ContactRelationshipAction.outgoingPending) {
      return;
    }

    if (relationshipState.canAcceptRequest) {
      await acceptRequest(relationshipState.contact!);
      return;
    }

    await _client.from('user_contacts').insert({
      'requester_id': currentUserId,
      'addressee_id': userId,
      'status': 'pending',
    });

    final String actorName = await _notificationWriter.getCurrentActorName();
    await _notificationWriter.safeCreateNotification(
      userId: userId,
      type: 'contact_request',
      entityId: currentUserId,
      title: actorName,
      body: 'sent you a contact request.',
    );
  }

  Future<void> acceptRequest(ContactModel contact) async {
    try {
      await _client
          .from('user_contacts')
          .update({'status': 'accepted'})
          .eq('requester_id', contact.requesterId)
          .eq('addressee_id', contact.addresseeId)
          .eq('status', 'pending');
    } on PostgrestException catch (error) {
      if (!_isMissingUpdatedAtTriggerError(error)) {
        rethrow;
      }

      // Legacy DBs can have `set_updated_at` triggers on tables that do not
      // yet include the `updated_at` column. Recreate the row to avoid update.
      await _client
          .from('user_contacts')
          .delete()
          .eq('requester_id', contact.requesterId)
          .eq('addressee_id', contact.addresseeId);

      await _client.from('user_contacts').insert({
        'requester_id': contact.requesterId,
        'addressee_id': contact.addresseeId,
        'status': 'accepted',
      });
    }

    final String actorName = await _notificationWriter.getCurrentActorName();
    await _notificationWriter.safeCreateNotification(
      userId: contact.requesterId,
      type: 'contact_request_accepted',
      entityId: contact.addresseeId,
      title: actorName,
      body: 'accepted your contact request.',
    );
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

  Future<List<ContactModel>> getAcceptedFriends() async {
    final List<ContactModel> contacts = await getContacts();
    return contacts
        .where((ContactModel contact) => contact.status == 'accepted')
        .toList();
  }

  Future<void> removeFriendByUserId(String otherUserId) async {
    final User? current = _client.auth.currentUser;
    if (current == null) {
      throw Exception('Not logged in.');
    }

    await _client
        .from('user_contacts')
        .delete()
        .or(
          'and(requester_id.eq.${current.id},addressee_id.eq.$otherUserId),and(requester_id.eq.$otherUserId,addressee_id.eq.${current.id})',
        )
        .eq('status', 'accepted');
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

  bool _isMissingUpdatedAtTriggerError(PostgrestException error) {
    if (error.code != '42703' && error.code != 'PGRST204') {
      return false;
    }

    final String summary =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return summary.contains('updated_at') && summary.contains('new');
  }
}
