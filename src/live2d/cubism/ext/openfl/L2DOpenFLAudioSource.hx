package live2d.cubism.ext.openfl;

#if openfl

import haxe.io.Bytes;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import live2d.cubism.ext.L2DAudioSourceBase;

/**
 * OpenFL backend audio source for LipSync.
 *
 * Wraps an `openfl.media.Sound` for actual audio playback while decoding
 * the WAV separately (via `L2DWavFileAudioSource`) for RMS amplitude.
 * The playback position is synced from `SoundChannel.position`
 * (milliseconds → seconds) to the WAV decoder each frame.
 *
 * Only WAV-format sounds are supported (the RMS decoder requires PCM 16-bit).
 *
 * OpenFL's `SoundChannel` has no native pause — this class implements
 * pause by saving the position and stopping, then resuming from the
 * saved position.
 *
 * Usage:
 * ```haxe
 * var sound = Sound.fromFile("assets/audio/voice.wav");
 * var wavBytes = sys.io.File.getBytes("assets/audio/voice.wav");
 * var source = new L2DOpenFLAudioSource(sound, wavBytes);
 * var lipSync = new L2DLipSync(core, source);
 * lipSync.enable();
 * source.play();
 * // in update loop:
 * source.update(dt);
 * lipSync.update(dt);
 * ```
 */
class L2DOpenFLAudioSource extends L2DAudioSourceBase
{
    /** The OpenFL sound for playback. */
    public var sound:Sound;

    /** Active playback channel (null when stopped/paused). */
    public var soundChannel:SoundChannel;

    var startTime:Float;
    var pausePosition:Float;
    var _volume:Float = 1.0;

    /**
     * @param sound OpenFL Sound for playback.
     * @param wavBytes Raw WAV file bytes for RMS decoding.
     * @param startTime Start offset in milliseconds.
     */
    public function new(sound:Sound, wavBytes:Bytes, ?startTime:Float = 0)
    {
        super(null, wavBytes);
        this.sound = sound;
        this.startTime = startTime;
        this.pausePosition = startTime;
        wav.positionProvider = () -> soundChannel != null ? soundChannel.position / 1000.0 : 0.0;
    }

    /** Start playback from the start time. Returns the channel. */
    public function play():SoundChannel
    {
        pausePosition = startTime;
        soundChannel = sound.play(startTime, 0, new SoundTransform(_volume));
        return soundChannel;
    }

    /** Stop playback. */
    public function stop():Void
    {
        if (soundChannel != null)
        {
            soundChannel.stop();
            soundChannel = null;
        }
        pausePosition = startTime;
    }

    /** Pause playback (saves position, stops channel). */
    public function pause():Void
    {
        if (soundChannel != null)
        {
            pausePosition = soundChannel.position;
            soundChannel.stop();
            soundChannel = null;
        }
    }

    /** Resume playback from the paused position. */
    public function resume():Void
    {
        if (soundChannel == null)
        {
            soundChannel = sound.play(pausePosition, 0, new SoundTransform(_volume));
        }
    }

    /** Playback volume (0..1). */
    public var volume(get, set):Float;
    function get_volume():Float { return _volume; }
    function set_volume(v:Float):Float
    {
        _volume = v;
        if (soundChannel != null)
        {
            var st = soundChannel.soundTransform;
            st.volume = v;
            soundChannel.soundTransform = st;
        }
        return v;
    }
}

#end
