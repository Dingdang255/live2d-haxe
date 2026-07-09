package live2d.cubism.ext;

import haxe.io.Bytes;

/**
 * Shared base class for backend-specific audio sources used by LipSync.
 *
 * Since no backend (Heaps/OpenFL/Flixel) exposes real-time amplitude on
 * cpp targets, all backend sources share the same strategy: decode the
 * WAV separately for RMS amplitude (via `L2DWavFileAudioSource`) and
 * sync the playback position from the backend's playing channel via
 * `wav.positionProvider`.
 *
 * Subclasses (L2DHeapsAudioSource, L2DOpenFLAudioSource, L2DFlixelAudioSource)
 * set `wav.positionProvider` in their constructor to bridge the backend's
 * playback position (in seconds) to the WAV decoder.
 *
 * Usage in update loop:
 * ```haxe
 * source.update(dt);      // syncs wav position from backend
 * lipSync.update(dt);     // reads getAmplitude() → drives mouth
 * ```
 *
 * NOTE: `L2DLipSync.update` only calls `source.getAmplitude()`, not
 * `source.update(dt)`. You MUST call `source.update(dt)` yourself each
 * frame before `lipSync.update(dt)`.
 */
class L2DAudioSourceBase implements IL2DAudioSource
{
    /** Underlying WAV decoder that provides RMS amplitude. Subclasses set `wav.positionProvider` to sync with backend playback. */
    public var wav:L2DWavFileAudioSource;

    /**
     * @param path Optional WAV file path (requires sys target).
     * @param bytes Optional in-memory WAV bytes (used when path is null).
     */
    public function new(?path:String, ?bytes:Bytes)
    {
        if (path != null)
            wav = new L2DWavFileAudioSource(path);
        else if (bytes != null)
            wav = L2DWavFileAudioSource.fromBytes(bytes);
        else
            wav = new L2DWavFileAudioSource();
    }

    /**
     * Sync playback position from the backend and advance the WAV decoder.
     * Call this each frame BEFORE `lipSync.update(dt)`.
     */
    public function update(dt:Float):Void
    {
        wav.update(dt);
    }

    public function getAmplitude():Float
    {
        return wav.getAmplitude();
    }

    /** Reset WAV playback position to the beginning. */
    public function rewind():Void
    {
        wav.rewind();
    }

    /** Current WAV playback position in seconds. */
    public var currentTime(get, never):Float;
    inline function get_currentTime():Float { return wav.currentTime; }

    /** Total WAV duration in seconds. */
    public var duration(get, never):Float;
    inline function get_duration():Float { return wav.duration; }

    /** Whether to loop the WAV when reaching the end (self-advancing mode only). */
    public var looping(get, set):Bool;
    inline function get_looping():Bool { return wav.looping; }
    inline function set_looping(v:Bool):Bool { wav.looping = v; return v; }
}
