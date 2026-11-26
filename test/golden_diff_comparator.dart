import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// [LocalFileComparator] with a configurable pixel-difference tolerance.
///
/// The golden PNGs in `test/goldens/` capture a keyed tight-cropped
/// `RepaintBoundary` around `MarkdownBody` (padded inside a `maxWidth: 480`
/// container on a white background). With `tolerance: 0.01` (1%), this remains
/// well below the measured whole-content swap floor (~6.9% on same-dimension
/// pairs) and blank-white replacement floor (~7.8%–21.4%).
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
