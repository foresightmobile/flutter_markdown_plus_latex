import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// [LocalFileComparator] with a configurable pixel-difference tolerance.
///
/// NOTE: The existing golden PNGs in `test/goldens/` capture an 800x600 surface
/// where rendered text and math cover <= ~1% of pixels, so the inherited 0.05
/// (5%) tolerance cannot catch content regressions on its own (non-golden widget
/// assertions in `flutter_markdown_latex_test.dart` enforce correctness today).
/// A follow-up PR after #18 merges will switch to tight-cropped
/// `RepaintBoundary` goldens regenerated via CI `workflow_dispatch` with a
/// tighter tolerance.
class GoldenDiffComparator extends LocalFileComparator {
  final double tolerance;

  GoldenDiffComparator(super.testFile, {this.tolerance = 0.005});

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (!result.passed && result.diffPercent > tolerance) {
      final String error = await generateFailureOutput(result, golden, basedir);
      result.dispose();
      throw FlutterError(error);
    }
    if (!result.passed) {
      log(
        'A tolerable difference of ${result.diffPercent * 100}% was found when comparing $golden.',
      );
    }
    final bool matched = result.passed || result.diffPercent <= tolerance;
    result.dispose();
    return matched;
  }
}
