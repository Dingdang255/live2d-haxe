package live2d.cubism.ext;

/**
 * Callback-based `IL2DAudioSource` — the simplest default implementation.
 *
 * Wraps a user-supplied `() -> Float` getter that returns the current
 * audio amplitude. Covers the common case where the user already has an
 * amplitude value (e.g. from a microphone RMS calculation, an analyser
 * node, or a manual timeline).
 *
 * Usage:
 * ```haxe
 * var source = new L2DCallbackAudioSource(() -> myAmplitude);
 * var lipSync = new L2DLipSync(core, source);
 * lipSync.enable();
 * // in update loop:
 * lipSync.update(dt);
 * ```
 */
class L2DCallbackAudioSource implements IL2DAudioSource
{
    var getter:() -> Float;

    public function new(getter:() -> Float)
    {
        this.getter = getter;
    }

    public function getAmplitude():Float
    {
        var v = getter();
        if (v < 0) v = 0;
        if (v > 1) v = 1;
        return v;
    }
}
