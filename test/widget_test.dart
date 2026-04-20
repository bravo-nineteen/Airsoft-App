import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airsoft_app/features/home/home_screen.dart';
import 'package:airsoft_app/features/community/community_model.dart';

void main() {
  testWidgets('Home screen renders key sections', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            loadLatestPosts: () async => <CommunityPostModel>[
              CommunityPostModel(
                id: 'post-1',
                authorId: 'user-1',
                authorName: 'Raven',
                authorAvatarUrl: null,
                title: 'Weekend skirmish',
                bodyText: 'Open game this Sunday.',
                plainText: 'Open game this Sunday.',
                imageUrl: null,
                imageUrls: const <String>[],
                category: 'General',
                language: 'english',
                languageCode: 'en',
                commentCount: 2,
                likeCount: 4,
                viewCount: 10,
                createdAt: DateTime(2026, 4, 19),
                updatedAt: null,
                isPinned: false,
                isLikedByMe: false,
                postContext: 'community',
                targetUserId: null,
              ),
            ],
            loadBlogPosts: () async => <AojBlogPost>[
              AojBlogPost(
                title: 'Tokyo field guide',
                excerpt: 'A quick guide to local fields.',
                link: 'https://example.com/blog/tokyo-field-guide',
                imageUrl: null,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('FieldOps News Feed'), findsOneWidget);
    expect(find.text('Recent Posts'), findsOneWidget);
    expect(find.text('Weekend skirmish'), findsOneWidget);
    expect(find.text('See Posted Events'), findsOneWidget);
    expect(find.text('Airsoft Blog'), findsOneWidget);
  });
}
