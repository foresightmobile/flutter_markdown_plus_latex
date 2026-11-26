import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// [LocalFileComparator] with a configurable pixel-difference tolerance.
///
/// The golden PNGs in `test/goldens/` capture a keyed tight-cropped
/// `RepaintBoundary` around `MarkdownBody` (padded inside a `maxWidth: 480`
/// container on a white background). The sensitivity floor is set by
/// invisible-math regressions (`0.16%` on `slash $`), not whole-image swaps
/// (`4.83%` lowest non-identical same-size swap between `inline latex 3 $` and
/// `inline latex $$...$` / `$...$$`) or blank-white replacements (`7.8%`–`34.1%`).
/// With `tolerance: 0.001` (0.1%), all measured invisible-math regressions fail
/// while retaining minor headroom.
class GoldenDiffComparator extends LocalFileComparator {
  final double tolerance;

  GoldenDiffComparator(super.testFile, {this.tolerance = 0.001});

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
