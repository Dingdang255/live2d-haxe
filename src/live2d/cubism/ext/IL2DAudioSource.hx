package live2d.cubism.ext;

/**
 * Audio amplitude source for LipSync.
 *
 * Implementations return the current frame's volume (0.0~1.0) so that
 * `L2DLipSync` can drive `L2DCore.setLipSyncValue` in a backend-agnostic way.
 *
 * Built-in implementations:
 * - `L2DCallbackAudioSource` — user supplies `() -> Float` (no file needed).
 * - `L2DWavFileAudioSource` — pure Haxe WAV decoder with RMS amplitude.
 * - `L2DAudioSourceBase` + three backend subclasses:
 *   `L2DHeapsAudioSource` (hxd.snd.Channel), `L2DOpenFLAudioSource`
 *   (openfl.media.SoundChannel), `L2DFlixelAudioSource` (FlxSound).
 *   These decode WAV separately for RMS and sync playback position from
 *   the backend's playing channel, since no backend exposes real amplitude
 *   on cpp targets.
 *
 * NOTE: `L2DLipSync.update` only calls `source.getAmplitude()`. When using
 * `L2DAudioSourceBase` or `L2DWavFileAudioSource`, you MUST call
 * `source.update(dt)` yourself each frame before `lipSync.update(dt)`.
 */
interface IL2DAudioSource
{
    /**
     * Returns current amplitude in [0, 1]. No audio = 0.
     * Implementations should clamp out-of-range values.
     */
    function getAmplitude():Float;
}
