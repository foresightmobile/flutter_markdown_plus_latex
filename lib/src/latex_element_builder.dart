import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

class LatexElementBuilder extends MarkdownElementBuilder {
  LatexElementBuilder({
    this.textStyle,
    this.textScaleFactor,
  });

  /// The style to apply to the text.
  final TextStyle? textStyle;

  /// The text scale factor to apply to the text.
  final double? textScaleFactor;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final String text = element.textContent;
    if (text.isEmpty) {
      return const SizedBox();
    }

    MathStyle mathStyle;
    switch (element.attributes['MathStyle']) {
      case 'text':
        mathStyle = MathStyle.text;
      case 'display':
        mathStyle = MathStyle.display;
      default:
        mathStyle = MathStyle.text;
    }

    // Block math: scrollable container is appropriate.
    if (mathStyle == MathStyle.display) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.antiAlias,
        child: Math.tex(
          text,
          textStyle: textStyle,
          mathStyle: mathStyle,
          textScaleFactor: textScaleFactor,
        ),
      );
    }

    // Inline math: return Text.rich so flutter_markdown_plus's
    // _mergeInlineChildren can recognise it as a text widget and merge it
    // with adjacent text spans into a single RichText. Returning an opaque
    // widget (e.g. SingleChildScrollView) breaks the merge chain and causes
    // each surrounding text segment to become a full-width RichText, which
    // produces unwanted line breaks around inline math expressions.
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              text,
              textStyle: textStyle,
              mathStyle: mathStyle,
              textScaleFactor: textScaleFactor,
            ),
          ),
        ],
      ),
    );
  }
}
