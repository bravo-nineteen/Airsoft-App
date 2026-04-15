import 'package:flutter/material.dart';

import 'contact_model.dart';
import 'contact_repository.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _repo = ContactRepository();
  late Future<List<ContactModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getContacts();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repo.getContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: FutureBuilder<List<ContactModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final contacts = snapshot.data!;

          if (contacts.isEmpty) {
            return const Center(child: Text('No contacts yet.'));
          }

          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];

              return Card(
                child: ListTile(
                  title: Text(contact.addresseeId),
                  subtitle: Text(contact.status),
                  trailing: contact.status == 'pending'
                      ? IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () async {
                            await _repo.acceptRequest(contact.id);
                            _refresh();
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}