package live2d.cubism.ext.heaps;

#if heaps

import hxd.res.Sound;
import hxd.snd.Channel;
import live2d.cubism.ext.L2DAudioSourceBase;

/**
 * Heaps backend audio source for LipSync.
 *
 * Wraps an `hxd.res.Sound` for actual audio playback while decoding the
 * WAV separately (via `L2DWavFileAudioSource`) for RMS amplitude. The
 * playback position is synced from the Heaps `Channel.position` (seconds)
 * to the WAV decoder each frame via `wav.positionProvider`.
 *
 * Only WAV-format sounds are supported (the RMS decoder requires PCM 16-bit).
 *
 * Usage:
 * ```haxe
 * var sound = hxd.Res.load("assets/audio/voice.wav").toSound();
 * var source = new L2DHeapsAudioSource(sound);
 * var lipSync = new L2DLipSync(core, source);
 * lipSync.enable();
 * source.play();
 * // in update loop:
 * source.update(dt);
 * lipSync.update(dt);
 * ```
 */
class L2DHeapsAudioSource extends L2DAudioSourceBase
{
    /** The Heaps sound resource for playback. */
    public var sound:Sound;

    /** Active playback channel (null when stopped). */
    public var channel:Channel;

    /** Whether to loop playback. */
    public var loop:Bool;

    public function new(sound:Sound, ?loop:Bool = false)
    {
        super(null, sound.entry.getBytes());
        this.sound = sound;
        this.loop = loop;
        wav.positionProvider = () -> channel != null ? channel.position : 0.0;
    }

    /** Start playback. Returns the channel. */
    public function play():Channel
    {
        channel = sound.play(loop);
        return channel;
    }

    /** Stop playback and release the channel. */
    public function stop():Void
    {
        if (channel != null)
        {
            channel.stop();
            channel = null;
        }
    }

    /** Pause playback. */
    public function pause():Void
    {
        if (channel != null) channel.pause = true;
    }

    /** Resume playback after pause. */
    public function resume():Void
    {
        if (channel != null) channel.pause = false;
    }

    /** Playback volume (0..1). Returns 0 if not playing. */
    public var volume(get, set):Float;
    function get_volume():Float { return channel != null ? channel.volume : 0; }
    function set_volume(v:Float):Float
    {
        if (channel != null) channel.volume = v;
        return v;
    }
}

#end
