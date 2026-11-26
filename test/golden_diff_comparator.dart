import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

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
