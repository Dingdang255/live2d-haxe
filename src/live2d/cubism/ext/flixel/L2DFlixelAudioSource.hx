package live2d.cubism.ext.flixel;

#if flixel

import flixel.FlxG;
import flixel.system.FlxSound;
import live2d.cubism.ext.L2DAudioSourceBase;

/**
 * Flixel backend audio source for LipSync.
 *
 * Wraps a `flixel.system.FlxSound` for actual audio playback while decoding
 * the WAV separately (via `L2DWavFileAudioSource`) for RMS amplitude.
 * The playback position is synced from `FlxSound.time` (milliseconds → seconds)
 * to the WAV decoder each frame.
 *
 * Only WAV-format sounds are supported (the RMS decoder requires PCM 16-bit).
 *
 * Usage:
 * ```haxe
 * var source = new L2DFlixelAudioSource("assets/audio/voice.wav");
 * var lipSync = new L2DLipSync(core, source);
 * lipSync.enable();
 * source.play();
 * // in update loop:
 * source.update(dt);
 * lipSync.update(dt);
 * ```
 */
class L2DFlixelAudioSource extends L2DAudioSourceBase
{
    /** The Flixel sound object for playback. */
    public var flxSound:FlxSound;

    /**
     * @param wavPath Path to the WAV file (used for both playback and RMS decoding).
     * @param loop Whether to loop playback.
     */
    public function new(wavPath:String, ?loop:Bool = false)
    {
        super(wavPath);
        flxSound = FlxG.sound.load(wavPath, 1.0, loop);
        wav.positionProvider = () -> flxSound != null ? flxSound.time / 1000.0 : 0.0;
    }

    /** Start playback. */
    public function play():Void
    {
        flxSound.play();
    }

    /** Stop playback. */
    public function stop():Void
    {
        flxSound.stop();
    }

    /** Pause playback. */
    public function pause():Void
    {
        flxSound.pause();
    }

    /** Resume playback after pause. */
    public function resume():Void
    {
        flxSound.resume();
    }

    /** Playback volume (0..1). */
    public var volume(get, set):Float;
    function get_volume():Float { return flxSound.volume; }
    function set_volume(v:Float):Float
    {
        flxSound.volume = v;
        return v;
    }
}

#end
