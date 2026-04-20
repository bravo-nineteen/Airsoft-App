import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityRichText extends StatelessWidget {
  const CommunityRichText({
    super.key,
    required this.text,
    this.maxLines,
  });

  final String text;
  final int? maxLines;

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  static final RegExp _boldRegex = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  static final RegExp _underlineRegex =
      RegExp(r'<u>(.+?)<\/u>', caseSensitive: false, dotAll: true);
  static final RegExp _italicRegex = RegExp(r'\*(.+?)\*', dotAll: true);

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.bodyMedium;
    final linkStyle = defaultStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    if (maxLines != null) {
      return RichText(
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: defaultStyle,
          children: _parseInline(
            text.replaceAll('\n', ' '),
            context,
            defaultStyle,
            linkStyle,
          ),
        ),
      );
    }

    final blocks = _buildBlocks(context, defaultStyle, linkStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  List<Widget> _buildBlocks(
    BuildContext context,
    TextStyle? defaultStyle,
    TextStyle? linkStyle,
  ) {
    final normalized = text.replaceAll('\r\n', '\n').trimRight();
    if (normalized.isEmpty) {
      return [
        Text(
          '',
          style: defaultStyle,
        ),
      ];
    }

    final lines = normalized.split('\n');
    final widgets = <Widget>[];
    int index = 0;

    while (index < lines.length) {
      final line = lines[index];

      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        index++;
        continue;
      }

      final bulletMatch = RegExp(r'^\s*-\s+(.*)$').firstMatch(line);
      final numberedMatch = RegExp(r'^\s*(\d+)\.\s+(.*)$').firstMatch(line);

      if (bulletMatch != null) {
        final items = <String>[];
        while (index < lines.length) {
          final match = RegExp(r'^\s*-\s+(.*)$').firstMatch(lines[index]);
          if (match == null) break;
          items.add(match.group(1) ?? '');
          index++;
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '•',
                              style: defaultStyle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: defaultStyle,
                                children: _parseInline(
                                  item,
                                  context,
                                  defaultStyle,
                                  linkStyle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        continue;
      }

      if (numberedMatch != null) {
        final items = <MapEntry<String, String>>[];
        while (index < lines.length) {
          final match =
              RegExp(r'^\s*(\d+)\.\s+(.*)$').firstMatch(lines[index]);
          if (match == null) break;
          items.add(
            MapEntry(
              match.group(1) ?? '',
              match.group(2) ?? '',
            ),
          );
          index++;
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.key}.',
                            style: defaultStyle,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: defaultStyle,
                                children: _parseInline(
                                  item.value,
                                  context,
                                  defaultStyle,
                                  linkStyle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        continue;
      }

      final paragraphLines = <String>[];
      while (index < lines.length) {
        final current = lines[index];
        if (current.trim().isEmpty) break;
        if (RegExp(r'^\s*-\s+').hasMatch(current) ||
            RegExp(r'^\s*\d+\.\s+').hasMatch(current)) {
          break;
        }
        paragraphLines.add(current);
        index++;
      }

      final paragraphText = paragraphLines.join('\n');

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: defaultStyle,
              children: _parseInline(
                paragraphText,
                context,
                defaultStyle,
                linkStyle,
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<InlineSpan> _parseInline(
    String input,
    BuildContext context,
    TextStyle? defaultStyle,
    TextStyle? linkStyle,
  ) {
    if (input.isEmpty) return const [];

    final spans = <InlineSpan>[];
    int cursor = 0;

    while (cursor < input.length) {
      final remaining = input.substring(cursor);

      final nextMatch = _findNextMatch(remaining);

      if (nextMatch == null) {
        spans.add(TextSpan(
          text: remaining,
          style: defaultStyle,
        ));
        break;
      }

      if (nextMatch.start > 0) {
        spans.add(TextSpan(
          text: remaining.substring(0, nextMatch.start),
          style: defaultStyle,
        ));
      }

      final matchedText = nextMatch.group(0)!;

      if (nextMatch.pattern == _urlRegex) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _openUrl(matchedText);
              },
          ),
        );
      } else if (nextMatch.pattern == _boldRegex) {
        final inner = nextMatch.group(1) ?? '';
        spans.add(
          TextSpan(
            style: defaultStyle?.copyWith(fontWeight: FontWeight.bold),
            children: _parseInline(
              inner,
              context,
              defaultStyle?.copyWith(fontWeight: FontWeight.bold),
              linkStyle?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (nextMatch.pattern == _underlineRegex) {
        final inner = nextMatch.group(1) ?? '';
        spans.add(
          TextSpan(
            style: defaultStyle?.copyWith(
              decoration: TextDecoration.underline,
            ),
            children: _parseInline(
              inner,
              context,
              defaultStyle?.copyWith(
                decoration: TextDecoration.underline,
              ),
              linkStyle?.copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        );
      } else if (nextMatch.pattern == _italicRegex) {
        final inner = nextMatch.group(1) ?? '';
        spans.add(
          TextSpan(
            style: defaultStyle?.copyWith(fontStyle: FontStyle.italic),
            children: _parseInline(
              inner,
              context,
              defaultStyle?.copyWith(fontStyle: FontStyle.italic),
              linkStyle?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle,
        ));
      }

      cursor += nextMatch.start + matchedText.length;
    }

    return spans;
  }

  RegExpMatch? _findNextMatch(String input) {
    final matches = <RegExpMatch?>[
      _urlRegex.firstMatch(input),
      _boldRegex.firstMatch(input),
      _underlineRegex.firstMatch(input),
      _italicRegex.firstMatch(input),
    ].whereType<RegExpMatch>().toList();

    if (matches.isEmpty) return null;

    matches.sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      if (startCompare != 0) return startCompare;
      return b.group(0)!.length.compareTo(a.group(0)!.length);
    });

    return matches.first;
  }
}