import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

import 'golden_diff_comparator.dart';

/// Whether golden pixel comparisons should run.
///
/// Pass `--dart-define=GOLDENS=true` to compare against the committed golden
/// reference images. Anywhere else, widget rendering still runs while pixel
/// comparisons are skipped.
const bool kGoldensEnabled = bool.fromEnvironment('GOLDENS');

Future<void> _loadPackageFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final String manifestJson = await rootBundle.loadString('FontManifest.json');
  final List<dynamic> fontManifest = json.decode(manifestJson) as List<dynamic>;
  for (final dynamic entry in fontManifest) {
    final Map<String, dynamic> font = entry as Map<String, dynamic>;
    final String family = font['family'] as String? ?? '';
    final List<dynamic> fonts = font['fonts'] as List<dynamic>? ?? <dynamic>[];
    String derivedFamily = family;
    if (!family.startsWith('packages/')) {
      for (final dynamic f in fonts) {
        final String? asset = (f as Map<String, dynamic>)['asset'] as String?;
        if (asset != null && asset.startsWith('packages/')) {
          final String packageName = asset.split('/')[1];
          derivedFamily = 'packages/$packageName/$family';
          break;
        }
      }
    }
    final FontLoader loader = FontLoader(derivedFamily);
    for (final dynamic f in fonts) {
      final String asset = (f as Map<String, dynamic>)['asset'] as String;
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

final snapshots = {
  'readme example': 'latex: \$c = \\pm\\sqrt{a^2 + b^2}\$',
  'inline latex': '''
This is inline latex: \$c = \\pm\\sqrt{a^2 + b^2}\$
''',
  'block latex': '''
This is block level latex:

\$\$
c = \\pm\\sqrt{a^2 + b^2}
\$\$
''',
  'inline latex more \$': '''
This is inline latex with displayMode: \$\$c = \\pm\\sqrt{a^2 + b^2}\$\$
''',
  'inline latex 3 \$': '''
This is not inline latex: \$\$\$c = \\pm\\sqrt{a^2 + b^2}\$\$\$
''',
  //   'block latex more \$': '''
  // This is not latex:

  // \$\$\$
  // c = \\pm\\sqrt{a^2 + b^2}
  // \$\$\$
  // ''',
  //   'block latex 1 \$': '''
  // This is block level latex:

  // \$
  // c = \\pm\\sqrt{a^2 + b^2}
  // \$
  // ''',
  'not latex': 'not latex \$300 \$400',
  'not latex at beginning': '\$300 \$400 not latex',
  'not latex at end': 'not latex 300\$ 400\$',
  'block latex with \$ inside': '''
\$\$
\\colorbox{aqua}{\$
\\frac{b}{2}\\sqrt{a^2-\\frac{b^2}{4}}
a\$}
\$\$
''',
  'inline latex with \$ inside':
      'this is inline latex: \$a\\raisebox{0.25em}{\$b\$}c\$',
  'inline latex with a question mark after': 'this is inline latex: \$x\$?',
  'inline latex with an exclamation mark after': 'this is inline latex: \$x\$!',
  'inline latex with a period after': 'this is inline latex: \$x\$.',
  'inline latex with a comma after': 'this is inline latex: \$x\$,',
  'inline latex with a colon after': 'this is inline latex: \$x\$:',
  'inline latex \$\$...\$':
      'this is not latex: \$\$a\\raisebox{0.25em}{\$b\$}c\$',
  'inline latex \$...\$\$':
      'this is not latex: \$a\\raisebox{0.25em}{\$b\$}c\$\$',
  'slash \$': 'must include space between latex and end delimiter: \$ \\\$ \$',
  'block slash \$': '''
this is block latex:

\$\$
\\\$\\\$
\$\$
''',
  'inline latex with newline': '''
this is not latex: \$
c = \\pm\\sqrt{a^2 + b^2}
\$
''',
  'multiple inline latex \$': '''
this is latex: **pi:** \$\\pi\$ **theta:** \$\\theta\$
''',
  'multiple inline latex \$\$': '''
this is latex: **pi:** \$\$\\pi\$\$ **theta:** \$\$\\theta\$\$
''',
  'multiple block latex \$': '''
# pi:

\$
\\pi
\$

# theta:

\$
\\theta
\$
''',
  'multiple block latex \$\$': '''
# pi:

\$\$
\\pi
\$\$

# theta:

\$\$
\\theta
\$\$
''',
  'OpenAI inline latex': '''
OpenAI inline latex \\( f(x) = \\sum_{i=0}^{n} \\frac{a_i}{1+x} \\)
''',
  'OpenAI block latex': '''
OpenAI block latex:

\\[ c = \\pm\\sqrt{a^2 + b^2} \\]
''',
};

void main() {
  group('Latex Rules', () {
    setUpAll(() async {
      if (!kGoldensEnabled) {
        // ignore: avoid_print
        print(
          'Golden tests: skipped (pass --dart-define=GOLDENS=true to compare against reference images).',
        );
      } else {
        final GoldenFileComparator current = goldenFileComparator;
        if (current is LocalFileComparator) {
          goldenFileComparator = GoldenDiffComparator(
            Uri.parse('${current.basedir}test.dart'),
            tolerance: 0.05,
          );
        }
      }
      await _loadPackageFonts();
    });

    snapshots.forEach((key, value) {
      testWidgets(key, (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: MarkdownBody(
                selectable: true,
                data: value,
                builders: {'latex': LatexElementBuilder()},
                extensionSet: md.ExtensionSet(
                  [LatexBlockSyntax()],
                  [LatexInlineSyntax()],
                ),
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'FlutterTest',
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(MarkdownBody), findsOneWidget);

        if (kGoldensEnabled) {
          await expectLater(
            find.byType(MarkdownBody),
            matchesGoldenFile('goldens/$key.png'),
          );
        }
      });
    });
  });
}
