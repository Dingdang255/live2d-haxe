package live2d.cubism.ext;

/**
 * Audio amplitude source for LipSync.
 *
 * Implementations return the current frame's volume (0.0~1.0) so that
 * `L2DLipSync` can drive `L2DCore.setLipSyncValue` in a backend-agnostic way.
 *
 * The three built-in backends (OpenFL `SoundChannel`, Flixel `FlxSound`,
 * Heaps `hxd.snd.Channel`) do not expose amplitude measurement, so v0.8
 * only ships `L2DCallbackAudioSource` (user supplies `() -> Float`).
 * Backend-specific AudioSources (wav decode + RMS) are deferred to v0.9
 * or community contributions.
 */
interface IL2DAudioSource
{
    /**
     * Returns current amplitude in [0, 1]. No audio = 0.
     * Implementations should clamp out-of-range values.
     */
    function getAmplitude():Float;
}
