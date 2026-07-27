import 'package:flutter/material.dart';

import 'legal_content.dart';

/// Renders a [LegalSection] list (Terms & Conditions or Privacy Policy).
/// Bundled in the app rather than loaded from a URL, so it's always
/// available — including fully offline, consistent with the rest of the app.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Last updated: $legalLastUpdated',
            style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          for (final section in sections) ...[
            Text(section.heading, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final paragraph in section.paragraphs) ...[
              Text(paragraph),
              const SizedBox(height: 8),
            ],
            for (final bullet in section.bullets)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(bullet)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
