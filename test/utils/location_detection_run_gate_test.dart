import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/utils/location_detection_run_gate.dart';

void main() {
  group('LocationDetectionRunGate', () {
    test('queues one rerun when detection is requested while already running',
        () {
      final gate = LocationDetectionRunGate();

      expect(gate.requestStart(), isTrue);
      expect(gate.isRunning, isTrue);

      expect(gate.requestStart(), isFalse);
      expect(gate.requestStart(), isFalse);

      expect(gate.finishAndConsumePendingRerun(), isTrue);
      expect(gate.isRunning, isTrue);

      expect(gate.requestStart(), isFalse);
      expect(gate.finishAndConsumePendingRerun(), isTrue);
      expect(gate.isRunning, isTrue);

      expect(gate.finishAndConsumePendingRerun(), isFalse);
      expect(gate.isRunning, isFalse);
    });

    test('allows a new run after the previous run has finished', () {
      final gate = LocationDetectionRunGate();

      expect(gate.requestStart(), isTrue);
      expect(gate.finishAndConsumePendingRerun(), isFalse);

      expect(gate.requestStart(), isTrue);
      expect(gate.finishAndConsumePendingRerun(), isFalse);
    });
  });
}
