/// One microphone level reading with the time it actually happened.
///
/// Unlike a bare dB value, [timestampMs] is the estimated time of the audio the
/// reading describes (monotonic epoch milliseconds, `MonotonicClock.epochMs`), not the time the plugin
/// delivered it. Several samples can arrive in one burst; their timestamps are
/// still spaced by the real sub-block duration.
class AudioLevelSample {
  /// Level on the app's 30–110 dB scale (same mapping as the legacy stream).
  final double db;

  /// Estimated time of the end of the audio block, epoch milliseconds.
  final int timestampMs;

  /// True when the block reached (almost) digital full scale, so the real peak
  /// may be higher than [db] shows.
  final bool clipped;

  /// Index of the plugin chunk this sample came from (0 when not chunked).
  final int chunkIndex;

  const AudioLevelSample({
    required this.db,
    required this.timestampMs,
    this.clipped = false,
    this.chunkIndex = 0,
  });

  @override
  String toString() =>
      'AudioLevelSample(db: $db, t: $timestampMs, clipped: $clipped, chunk: $chunkIndex)';
}
