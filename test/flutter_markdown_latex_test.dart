import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:flutter_math_fork/flutter_math.dart';
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

class _LatexSnapshotCase {
  const _LatexSnapshotCase({
    required this.markdown,
    required this.mathStyles,
    this.expectedTex = const <String>[],
    this.expectParseError = false,
    this.expectedTexts = const <String>[],
  });

  final String markdown;
  final List<MathStyle> mathStyles;
  final List<String> expectedTex;
  final bool expectParseError;
  final List<String> expectedTexts;
}

const Map<String, _LatexSnapshotCase> _snapshotCases = {
  'readme example': _LatexSnapshotCase(
    markdown: 'latex: \$c = \\pm\\sqrt{a^2 + b^2}\$',
    mathStyles: [MathStyle.text],
    expectedTex: [r'c = \pm\sqrt{a^2 + b^2}'],
    expectedTexts: ['latex: '],
  ),
  'inline latex': _LatexSnapshotCase(
    markdown: '''
This is inline latex: \$c = \\pm\\sqrt{a^2 + b^2}\$
''',
    mathStyles: [MathStyle.text],
    expectedTex: [r'c = \pm\sqrt{a^2 + b^2}'],
    expectedTexts: ['This is inline latex: '],
  ),
  'block latex': _LatexSnapshotCase(
    markdown: '''
This is block level latex:

\$\$
c = \\pm\\sqrt{a^2 + b^2}
\$\$
''',
    mathStyles: [MathStyle.display],
    expectedTex: [r'c = \pm\sqrt{a^2 + b^2}'],
    expectedTexts: ['This is block level latex:'],
  ),
  'inline latex more \$': _LatexSnapshotCase(
    markdown: '''
This is inline latex with displayMode: \$\$c = \\pm\\sqrt{a^2 + b^2}\$\$
''',
    mathStyles: [MathStyle.display],
    expectedTex: [r'c = \pm\sqrt{a^2 + b^2}'],
    expectedTexts: ['This is inline latex with displayMode: '],
  ),
  'inline latex 3 \$': _LatexSnapshotCase(
    markdown: '''
This is not inline latex: \$\$\$c = \\pm\\sqrt{a^2 + b^2}\$\$\$
''',
    mathStyles: [MathStyle.display],
    expectParseError: true,
    expectedTexts: [
      'This is not inline latex: ',
      "Parser Error: Can't use function '\$' in math mode",
    ],
  ),
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
  'not latex': _LatexSnapshotCase(
    markdown: 'not latex \$300 \$400',
    mathStyles: [],
    expectedTexts: ['not latex \$300 \$400'],
  ),
  'not latex at beginning': _LatexSnapshotCase(
    markdown: '\$300 \$400 not latex',
    mathStyles: [],
    expectedTexts: ['\$300 \$400 not latex'],
  ),
  // Existing parser behaviour locked in by this test: the trailing `$ 400$`
  // substring is matched as inline math while `'not latex 300'` stays plain text.
  'not latex at end': _LatexSnapshotCase(
    markdown: 'not latex 300\$ 400\$',
    mathStyles: [MathStyle.text],
    expectedTex: [' 400'],
    expectedTexts: ['not latex 300'],
  ),
  'block latex with \$ inside': _LatexSnapshotCase(
    markdown: '''
\$\$
\\colorbox{aqua}{\$
\\frac{b}{2}\\sqrt{a^2-\\frac{b^2}{4}}
a\$}
\$\$
''',
    mathStyles: [MathStyle.display],
    expectedTex: [
      '''
\\colorbox{aqua}{\$
\\frac{b}{2}\\sqrt{a^2-\\frac{b^2}{4}}
a\$}''',
    ],
  ),
  'inline latex with \$ inside': _LatexSnapshotCase(
    markdown: 'this is inline latex: \$a\\raisebox{0.25em}{\$b\$}c\$',
    mathStyles: [MathStyle.text],
    expectedTex: [r'a\raisebox{0.25em}{$b$}c'],
    expectedTexts: ['this is inline latex: '],
  ),
  'inline latex with a question mark after': _LatexSnapshotCase(
    markdown: 'this is inline latex: \$x\$?',
    mathStyles: [MathStyle.text],
    expectedTex: ['x'],
    expectedTexts: ['this is inline latex: ', '?'],
  ),
  'inline latex with an exclamation mark after': _LatexSnapshotCase(
    markdown: 'this is inline latex: \$x\$!',
    mathStyles: [MathStyle.text],
    expectedTex: ['x'],
    expectedTexts: ['this is inline latex: ', '!'],
  ),
  'inline latex with a period after': _LatexSnapshotCase(
    markdown: 'this is inline latex: \$x\$.',
    mathStyles: [MathStyle.text],
    expectedTex: ['x'],
    expectedTexts: ['this is inline latex: ', '.'],
  ),
  'inline latex with a comma after': _LatexSnapshotCase(
    markdown: 'this is inline latex: \$x\$,',
    mathStyles: [MathStyle.text],
    expectedTex: ['x'],
    expectedTexts: ['this is inline latex: ', ','],
  ),
  'inline latex with a colon after': _LatexSnapshotCase(
    markdown: 'this is inline latex: \$x\$:',
    mathStyles: [MathStyle.text],
    expectedTex: ['x'],
    expectedTexts: ['this is inline latex: ', ':'],
  ),
  'inline latex \$\$...\$': _LatexSnapshotCase(
    markdown: 'this is not latex: \$\$a\\raisebox{0.25em}{\$b\$}c\$',
    mathStyles: [MathStyle.text],
    expectParseError: true,
    expectedTexts: [
      'this is not latex: ',
      "Parser Error: Can't use function '\$' in math mode",
    ],
  ),
  'inline latex \$...\$\$': _LatexSnapshotCase(
    markdown: 'this is not latex: \$a\\raisebox{0.25em}{\$b\$}c\$\$',
    mathStyles: [MathStyle.text],
    expectParseError: true,
    expectedTexts: [
      'this is not latex: ',
      "Parser Error: Can't use function '\$' in math mode",
    ],
  ),
  'slash \$': _LatexSnapshotCase(
    markdown: 'must include space between latex and end delimiter: \$ \\\$ \$',
    mathStyles: [MathStyle.text],
    expectedTex: [r' \$ '],
    expectedTexts: ['must include space between latex and end delimiter: '],
  ),
  'block slash \$': _LatexSnapshotCase(
    markdown: '''
this is block latex:

\$\$
\\\$\\\$
\$\$
''',
    mathStyles: [MathStyle.display],
    expectedTex: [r'\$\$'],
    expectedTexts: ['this is block latex:'],
  ),
  'inline latex with newline': _LatexSnapshotCase(
    markdown: '''
this is not latex: \$
c = \\pm\\sqrt{a^2 + b^2}
\$
''',
    mathStyles: [],
    expectedTexts: ['this is not latex: \$ c = \\pm\\sqrt{a^2 + b^2}'],
  ),
  'multiple inline latex \$': _LatexSnapshotCase(
    markdown: '''
this is latex: **pi:** \$\\pi\$ **theta:** \$\\theta\$
''',
    mathStyles: [MathStyle.text, MathStyle.text],
    expectedTex: [r'\pi', r'\theta'],
    expectedTexts: ['this is latex: pi: ', ' theta: '],
  ),
  'multiple inline latex \$\$': _LatexSnapshotCase(
    markdown: '''
this is latex: **pi:** \$\$\\pi\$\$ **theta:** \$\$\\theta\$\$
''',
    mathStyles: [MathStyle.display, MathStyle.display],
    expectedTex: [r'\pi', r'\theta'],
    expectedTexts: ['this is latex: pi: ', ' theta: '],
  ),
  'multiple block latex \$': _LatexSnapshotCase(
    markdown: '''
# pi:

\$
\\pi
\$

# theta:

\$
\\theta
\$
''',
    mathStyles: [MathStyle.display, MathStyle.display],
    expectedTex: [r'\pi', r'\theta'],
    expectedTexts: ['pi:', 'theta:'],
  ),
  'multiple block latex \$\$': _LatexSnapshotCase(
    markdown: '''
# pi:

\$\$
\\pi
\$\$

# theta:

\$\$
\\theta
\$\$
''',
    mathStyles: [MathStyle.display, MathStyle.display],
    expectedTex: [r'\pi', r'\theta'],
    expectedTexts: ['pi:', 'theta:'],
  ),
  'OpenAI inline latex': _LatexSnapshotCase(
    markdown: '''
OpenAI inline latex \\( f(x) = \\sum_{i=0}^{n} \\frac{a_i}{1+x} \\)
''',
    mathStyles: [MathStyle.text],
    expectedTex: [r' f(x) = \sum_{i=0}^{n} \frac{a_i}{1+x} '],
    expectedTexts: ['OpenAI inline latex '],
  ),
  'OpenAI block latex': _LatexSnapshotCase(
    markdown: '''
OpenAI block latex:

\\[ c = \\pm\\sqrt{a^2 + b^2} \\]
''',
    mathStyles: [MathStyle.display],
    expectedTex: [r'c = \pm\sqrt{a^2 + b^2}'],
    expectedTexts: ['OpenAI block latex:'],
  ),
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
            tolerance: 0.01,
          );
        }
      }
      await _loadPackageFonts();
    });

    _snapshotCases.forEach((key, testCase) {
      testWidgets(key, (tester) async {
        final GlobalKey goldenKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: goldenKey,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: MarkdownBody(
                          selectable: true,
                          data: testCase.markdown,
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
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(MarkdownBody), findsOneWidget);

        final List<Math> mathWidgets = tester
            .widgetList<Math>(find.byType(Math))
            .toList();
        expect(
          mathWidgets.map((Math m) => m.mathStyle).toList(),
          equals(testCase.mathStyles),
        );
        for (final Math mathWidget in mathWidgets) {
          if (testCase.expectParseError) {
            expect(mathWidget.parseError, isNotNull);
          } else {
            expect(mathWidget.parseError, isNull);
          }
        }
        if (!testCase.expectParseError) {
          expect(
            mathWidgets
                .map((Math m) => m.ast!.greenRoot.toJson().toString())
                .toList(),
            equals(
              testCase.expectedTex
                  .map(
                    (String tex) =>
                        Math.tex(tex).ast!.greenRoot.toJson().toString(),
                  )
                  .toList(),
            ),
          );
        }

        final List<String> renderedTexts = tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map(
              (SelectableText w) => w.textSpan?.toPlainText() ?? w.data ?? '',
            )
            .toList();
        expect(renderedTexts, equals(testCase.expectedTexts));

        if (kGoldensEnabled) {
          await expectLater(
            find.byKey(goldenKey),
            matchesGoldenFile('goldens/$key.png'),
          );
        }
      });
    });
  });
}
