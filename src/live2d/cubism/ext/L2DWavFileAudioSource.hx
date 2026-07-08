package live2d.cubism.ext;

import haxe.io.Bytes;
import haxe.io.BytesInput;

/**
 * Pure Haxe WAV file decoder + RMS amplitude source for LipSync.
 *
 * Loads a `.wav` file (PCM 16-bit mono/stereo), decodes into normalized
 * samples `[-1, 1]`, and provides real-time amplitude via sliding-window
 * RMS. No backend audio playback — this is a "data-driven" amplitude
 * source for lip sync without actual audio output.
 *
 * Two modes of playback position tracking:
 *
 * 1. **Self-advancing** (default): `update(dt)` advances the position
 *    by `dt` seconds each frame. Set `looping = false` to stop at the end.
 * 2. **External sync**: Set `positionProvider` to a callback that returns
 *    the current playback time in seconds (e.g. from a backend
 *    `SoundChannel.position / 1000`). The position is synced to the
 *    external source each frame, ensuring lip sync stays in sync with
 *    actual audio playback.
 *
 * Usage (self-advancing):
 * ```haxe
 * var wav = new L2DWavFileAudioSource('assets/voice/haru_01.wav');
 * wav.looping = false; // don't loop
 * var lipSync = new L2DLipSync(core, wav);
 * lipSync.enable();
 * wav.update(dt);
 * lipSync.update(dt);
 * ```
 *
 * Usage (synced to OpenFL SoundChannel):
 * ```haxe
 * var wav = new L2DWavFileAudioSource('assets/voice/haru_01.wav');
 * var sound = Sound.fromFile('assets/voice/haru_01.wav');
 * var channel = sound.play(0, 0); // no loop
 * wav.positionProvider = () -> channel.position / 1000.0;
 * var lipSync = new L2DLipSync(core, wav);
 * lipSync.enable();
 * // in update loop:
 * wav.update(dt);      // syncs position from SoundChannel
 * lipSync.update(dt);  // reads getAmplitude() → drives mouth
 * ```
 */
class L2DWavFileAudioSource implements IL2DAudioSource
{
    /** Decoded samples normalized to [-1, 1]. */
    var samples:Array<Float> = [];
    /** Current playback position (in samples, not frames). */
    var position:Int = 0;
    /** RMS window size in frames (mono samples or stereo frame count). */
    var windowSize:Int = 1024;
    var sampleRate:Int = 44100;
    var channels:Int = 1;

    /**
     * Whether to loop when reaching the end in self-advancing mode.
     * Default true. Ignored when `positionProvider` is set (sync follows
     * the external source, which handles its own looping).
     */
    public var looping:Bool = true;

    /**
     * Optional external position provider (returns time in seconds).
     * When set, `update(dt)` syncs the internal position to this value
     * instead of advancing by `dt`. Use this to sync lip sync RMS to
     * actual audio playback (e.g. `() -> soundChannel.position / 1000`).
     * Set to `null` to use self-advancing mode.
     */
    public var positionProvider:Null<Void -> Float> = null;

    /** Whether playback has reached the end (non-looping mode only). */
    public var finished(get, never):Bool;
    inline function get_finished():Bool
    {
        return samples.length > 0 && !looping && position >= samples.length - 1;
    }

    /**
     * Load a WAV file from `path`. Requires `sys` target.
     * Pass `null` to create an empty source (for `fromBytes`).
     */
    public function new(?path:String)
    {
        if (path != null)
        {
            #if sys
            var bytes = sys.io.File.getBytes(path);
            parseWav(bytes);
            #else
            throw "L2DWavFileAudioSource(path) requires sys target; use fromBytes() on non-sys targets";
            #end
        }
    }

    /** Create from in-memory bytes (works on all targets). */
    public static function fromBytes(bytes:Bytes):L2DWavFileAudioSource
    {
        var src = new L2DWavFileAudioSource();
        src.parseWav(bytes);
        return src;
    }

    function parseWav(bytes:Bytes):Void
    {
        var input = new BytesInput(bytes);
        input.bigEndian = false;

        // RIFF header
        var riff = input.readString(4);
        if (riff != "RIFF") throw "Not a RIFF file";
        input.readInt32(); // file size (ignored)
        var wave = input.readString(4);
        if (wave != "WAVE") throw "Not a WAVE file";

        // Read chunks
        while (input.position < bytes.length)
        {
            var chunkId = input.readString(4);
            var chunkSize = input.readInt32();

            if (chunkId == "fmt ")
            {
                var audioFormat = input.readUInt16();
                channels = input.readUInt16();
                sampleRate = input.readInt32();
                input.readInt32();  // byte rate
                input.readUInt16(); // block align
                var bitsPerSample = input.readUInt16();
                if (audioFormat != 1 || bitsPerSample != 16)
                {
                    throw 'Only PCM 16-bit supported, got format=$audioFormat bits=$bitsPerSample';
                }
                // Skip extra format bytes if present
                if (chunkSize > 16) input.read(chunkSize - 16);
            }
            else if (chunkId == "data")
            {
                var sampleCount = Std.int(chunkSize / 2);
                samples = [];
                for (i in 0...sampleCount)
                {
                    var s = input.readInt16();
                    samples.push(s / 32768.0);
                }
            }
            else
            {
                // Skip unknown chunk
                if (chunkSize > 0) input.read(chunkSize);
            }
        }
    }

    /**
     * Advance or sync playback position.
     *
     * - If `positionProvider` is set: syncs to the external time.
     * - Otherwise: advances by `dt` seconds (looping or stopping at end).
     */
    public function update(dt:Float):Void
    {
        if (samples.length == 0) return;

        if (positionProvider != null)
        {
            // External sync mode: use provided time (seconds)
            var timeSec = positionProvider();
            position = Std.int(timeSec * sampleRate * channels);
            if (position < 0) position = 0;
            // In looping mode, wrap around; otherwise clamp to end
            if (position >= samples.length)
            {
                if (looping) position = position % samples.length;
                else position = samples.length - 1;
            }
        }
        else
        {
            // Self-advancing mode
            var advance = Std.int(sampleRate * dt * channels);
            position += advance;
            if (position >= samples.length)
            {
                if (looping) position = position % samples.length;
                else position = samples.length - 1;
            }
        }
    }

    public function getAmplitude():Float
    {
        if (samples.length == 0) return 0;
        var start = position;
        var end = Std.int(Math.min(position + windowSize * channels, samples.length));
        var sum = 0.0;
        var n = 0;
        for (i in start...end)
        {
            sum += samples[i] * samples[i];
            n++;
        }
        if (n == 0) return 0;
        var rms = Math.sqrt(sum / n);
        // Normalize to [0, 1] — typical speech RMS is 0.05~0.3
        return Math.min(rms * 3.0, 1.0);
    }

    /** Set the RMS window size in frames (mono samples or stereo frames). */
    public function setWindowSize(frames:Int):Void
    {
        windowSize = frames;
    }

    /** Reset playback position to the beginning. */
    public function rewind():Void
    {
        position = 0;
    }

    /** Current playback position in seconds. */
    public var currentTime(get, never):Float;
    inline function get_currentTime():Float
    {
        return (samples.length == 0) ? 0 : (position / channels) / sampleRate;
    }

    /** Total duration in seconds. */
    public var duration(get, never):Float;
    inline function get_duration():Float
    {
        return (samples.length == 0) ? 0 : (samples.length / channels) / sampleRate;
    }
}
