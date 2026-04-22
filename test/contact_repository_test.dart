import 'package:flutter_test/flutter_test.dart';

import 'package:airsoft_app/features/social/contact_model.dart';
import 'package:airsoft_app/features/social/contact_repository.dart';

void main() {
  ContactModel buildContact({
    required String id,
    required String requesterId,
    required String addresseeId,
    required String status,
  }) {
    return ContactModel(
      id: id,
      requesterId: requesterId,
      addresseeId: addresseeId,
      status: status,
      createdAt: DateTime(2026, 4, 22),
    );
  }

  test('incoming pending request takes precedence over outgoing duplicate', () {
    final List<ContactModel> contacts = <ContactModel>[
      buildContact(
        id: 'outgoing',
        requesterId: 'current',
        addresseeId: 'other',
        status: 'pending',
      ),
      buildContact(
        id: 'incoming',
        requesterId: 'other',
        addresseeId: 'current',
        status: 'pending',
      ),
    ];

    final ContactRelationshipState state = deriveContactRelationshipState(
      contacts: contacts,
      currentUserId: 'current',
      otherUserId: 'other',
    );

    expect(state.action, ContactRelationshipAction.incomingPending);
    expect(state.contact?.id, 'incoming');
  });

  test('accepted friendship wins over any pending duplicates', () {
    final List<ContactModel> contacts = <ContactModel>[
      buildContact(
        id: 'pending',
        requesterId: 'current',
        addresseeId: 'other',
        status: 'pending',
      ),
      buildContact(
        id: 'accepted',
        requesterId: 'other',
        addresseeId: 'current',
        status: 'accepted',
      ),
    ];

    final ContactRelationshipState state = deriveContactRelationshipState(
      contacts: contacts,
      currentUserId: 'current',
      otherUserId: 'other',
    );

    expect(state.action, ContactRelationshipAction.friends);
    expect(state.contact?.id, 'accepted');
  });
}