import 'package:flutter_test/flutter_test.dart';
import 'package:callibrate/core/utils/calibration_math.dart';

void main() {
  group('CalibrationStats.empty()', () {
    test('returns zero values', () {
      final stats = CalibrationStats.empty();
      expect(stats.brierScore, 0);
      expect(stats.logLoss, 0);
      expect(stats.totalCount, 0);
      expect(stats.bins, isEmpty);
    });
  });

  group('CalibrationStats.compute()', () {
    test('returns empty stats for empty input', () {
      final stats = CalibrationStats.compute([]);
      expect(stats.totalCount, 0);
      expect(stats.bins, isEmpty);
    });

    test('perfect forecast (p=1 when outcome=1) gives brier=0', () {
      final pairs = [
        (probability: 0.99, outcome: 1.0),
        (probability: 0.99, outcome: 1.0),
        (probability: 0.01, outcome: 0.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      // Brier score should be very small for near-perfect forecasts
      expect(stats.brierScore, lessThan(0.01));
      expect(stats.totalCount, 3);
    });

    test('worst forecast (p=1 when outcome=0) gives high brier', () {
      final pairs = [
        (probability: 0.99, outcome: 0.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      // Brier score should be close to 1 (= 0.99^2 ≈ 0.98)
      expect(stats.brierScore, greaterThan(0.9));
    });

    test('random forecast at 50% gives brier ~0.25', () {
      // For p=0.5 always: brier = (0.5-1)^2 = 0.25 or (0.5-0)^2 = 0.25
      final pairs = [
        (probability: 0.5, outcome: 1.0),
        (probability: 0.5, outcome: 0.0),
        (probability: 0.5, outcome: 1.0),
        (probability: 0.5, outcome: 0.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      expect(stats.brierScore, closeTo(0.25, 0.001));
    });

    test('brier score is between 0 and 1 for valid inputs', () {
      final pairs = [
        (probability: 0.3, outcome: 1.0),
        (probability: 0.7, outcome: 0.0),
        (probability: 0.6, outcome: 1.0),
        (probability: 0.4, outcome: 0.0),
        (probability: 0.8, outcome: 1.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      expect(stats.brierScore, greaterThanOrEqualTo(0.0));
      expect(stats.brierScore, lessThanOrEqualTo(1.0));
    });

    test('log loss is non-negative', () {
      final pairs = [
        (probability: 0.7, outcome: 1.0),
        (probability: 0.3, outcome: 0.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      expect(stats.logLoss, greaterThanOrEqualTo(0.0));
    });

    test('total count matches input length', () {
      final pairs = List.generate(
        10,
        (i) => (probability: 0.5, outcome: i % 2 == 0 ? 1.0 : 0.0),
      );
      final stats = CalibrationStats.compute(pairs);
      expect(stats.totalCount, 10);
    });

    test('bins have correct bin centers', () {
      // Put items in first bin (0–10%)
      final pairs = [
        (probability: 0.05, outcome: 1.0),
        (probability: 0.08, outcome: 0.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      expect(stats.bins, isNotEmpty);
      // First bin center should be 0.05
      final firstBin = stats.bins.first;
      expect(firstBin.binCenter, closeTo(0.05, 0.01));
    });

    test('hit rate in bin is between 0 and 1', () {
      final pairs = [
        (probability: 0.55, outcome: 1.0),
        (probability: 0.56, outcome: 0.0),
        (probability: 0.57, outcome: 1.0),
        (probability: 0.58, outcome: 1.0),
        (probability: 0.59, outcome: 0.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      for (final bin in stats.bins) {
        expect(bin.hitRate, greaterThanOrEqualTo(0.0));
        expect(bin.hitRate, lessThanOrEqualTo(1.0));
      }
    });

    test('bins only contain non-empty bins', () {
      // Only probability in range 50–60%
      final pairs = [
        (probability: 0.55, outcome: 1.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      // Should only have one bin
      expect(stats.bins.length, 1);
      expect(stats.bins.first.count, 1);
      expect(stats.bins.first.hitRate, 1.0);
    });

    test('bin count accumulates correctly', () {
      final pairs = [
        (probability: 0.25, outcome: 1.0),
        (probability: 0.28, outcome: 0.0),
        (probability: 0.22, outcome: 1.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      // All in bin 20–30%
      expect(stats.bins.length, 1);
      expect(stats.bins.first.count, 3);
      expect(stats.bins.first.hitRate, closeTo(2 / 3, 0.001));
    });

    test('multiple bins are in ascending order of bin center', () {
      final pairs = [
        (probability: 0.15, outcome: 1.0),
        (probability: 0.55, outcome: 0.0),
        (probability: 0.85, outcome: 1.0),
      ];
      final stats = CalibrationStats.compute(pairs);
      expect(stats.bins.length, 3);
      for (var i = 1; i < stats.bins.length; i++) {
        expect(stats.bins[i].binCenter,
            greaterThan(stats.bins[i - 1].binCenter));
      }
    });
  });
}
