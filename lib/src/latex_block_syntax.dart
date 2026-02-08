import 'package:markdown/markdown.dart';

class LatexBlockSyntax extends BlockSyntax {
  static final RegExp _singleLineBracket = RegExp(r'^\s*\\\[(.*)\\\]\s*$');
  static final RegExp _startBracket = RegExp(r'^\s*\\\[\s*$');
  static final RegExp _endBracket = RegExp(r'^\s*\\\]\s*$');
  static final RegExp _startDollar = RegExp(r'^\s*(\${1,2})\s*$');

  @override
  RegExp get pattern => RegExp(r'^\s*(?:\${1,2}|\\\[)\s*$|^\s*\\\[(.*)\\\]\s*$');

  LatexBlockSyntax() : super();

  @override
  bool canParse(BlockParser parser) {
    final line = parser.current.content;
    return _singleLineBracket.hasMatch(line) ||
        _startBracket.hasMatch(line) ||
        _startDollar.hasMatch(line);
  }

  @override
  List<Line> parseChildLines(BlockParser parser) {
    final line = parser.current.content;

    // Single-line bracket form: \[ ... \]
    final single = _singleLineBracket.firstMatch(line);
    if (single != null) {
      parser.advance();
      return [Line(single.group(1) ?? '')];
    }

    // Multiline bracket form:
    // \[
    //   ...
    // \]
    if (_startBracket.hasMatch(line)) {
      final childLines = <Line>[];
      parser.advance(); // consume \[
      while (!parser.isDone) {
        final current = parser.current.content;
        if (_endBracket.hasMatch(current)) {
          parser.advance(); // consume \]
          break;
        }
        childLines.add(parser.current);
        parser.advance();
      }
      return childLines;
    }

    // Multiline dollar form:
    // $$
    //   ...
    // $$
    // or
    // $
    //   ...
    // $
    final m = _startDollar.firstMatch(line);
    final delimiter = m?.group(1);

    final childLines = <Line>[];
    parser.advance(); // consume opening $ or $$

    while (!parser.isDone) {
      final current = parser.current.content.trim();
      if (delimiter != null && current == delimiter) {
        parser.advance(); // consume closing delimiter
        break;
      }
      childLines.add(parser.current);
      parser.advance();
    }

    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    final lines = parseChildLines(parser);
    final content = lines.map((e) => e.content).join('\n').trim();
    final textElement = Element.text('latex', content);
    textElement.attributes['MathStyle'] = 'display';
    return Element('p', [textElement]);
  }
}
