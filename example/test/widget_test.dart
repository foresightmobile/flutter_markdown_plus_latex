import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('Renders LaTeX markdown example', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Latex Markdown Example'), findsOneWidget);
    expect(find.byType(Markdown), findsOneWidget);
    expect(find.byType(Math), findsWidgets);
  });
}
