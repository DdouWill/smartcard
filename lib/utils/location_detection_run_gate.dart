/// Coordinates foreground GPS/location detection runs.
///
/// A lifecycle resume, timer tick, and manual refresh can all request location
/// detection at nearly the same time. The app should not start unbounded
/// parallel GPS lookups, but it also should not drop a resume request while a
/// slow lookup is already running. This gate keeps one active run and folds any
/// overlapping requests into one pending rerun.
class LocationDetectionRunGate {
  bool _isRunning = false;
  bool _hasPendingRerun = false;

  bool get isRunning => _isRunning;

  /// Returns true when the caller should start a detection run now.
  ///
  /// If a run is already active, this records that one more run should happen
  /// after the active run finishes and returns false.
  bool requestStart() {
    if (_isRunning) {
      _hasPendingRerun = true;
      return false;
    }

    _isRunning = true;
    return true;
  }

  /// Marks the active run as finished and returns whether a queued rerun exists.
  ///
  /// When a queued rerun exists, the gate deliberately stays in the running
  /// state so another overlapping request during the rerun is folded into the
  /// next single pending rerun instead of starting a parallel lookup.
  bool finishAndConsumePendingRerun() {
    if (_hasPendingRerun) {
      _hasPendingRerun = false;
      return true;
    }

    _isRunning = false;
    return false;
  }
}
