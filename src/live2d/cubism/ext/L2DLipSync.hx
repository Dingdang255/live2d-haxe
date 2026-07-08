package live2d.cubism.ext;

import live2d.cubism.L2DCore;

/**
 * Audio-driven lip sync controller with attack/release smoothing.
 *
 * Reads amplitude from an `IL2DAudioSource` each frame, applies a curve
 * mapping, then eases the result toward the target using separate
 * attack (opening) and release (closing) coefficients. The smoothed
 * value is written to `L2DCore.setLipSyncValue`.
 *
 * While enabled, this class takes over lip sync from the C-side wav
 * file handler: `enable()` switches to external mode by calling
 * `core.setLipSyncValue(0.0)` (which sets `_useExternalLipSync = true`
 * in native code). `disable()` reverts to wav mode by passing a
 * negative value to `setLipSyncValue`.
 *
 * NOTE: `enable()` does NOT call `setLipSyncEnabled(false)` — that would
 * disable the entire lip sync block in native `Update()`, preventing
 * the external value from being applied. The native code checks
 * `_lipSyncEnabled` first, then `_useExternalLipSync` to decide whether
 * to use the external value or the wav file handler.
 *
 * Usage:
 * ```haxe
 * var source = new L2DCallbackAudioSource(() -> computeRMS());
 * var lipSync = new L2DLipSync(core, source);
 * lipSync.attack = 0.5;   // snappier opening
 * lipSync.release = 0.15; // slower closing
 * lipSync.enable();
 *
 * // in update loop:
 * lipSync.update(dt);
 *
 * // to stop:
 * lipSync.disable();  // reverts to wav file mode
 * ```
 */
class L2DLipSync
{
    var core:L2DCore;
    var source:IL2DAudioSource;

    /** Whether this controller is currently driving `core.setLipSyncValue`. */
    public var enabled(default, null):Bool = false;

    /** Current smoothed mouth open amount in [0, maxValue]. */
    public var current(default, null):Float = 0;

    /**
     * Attack coefficient (mouth opening speed), 0..1.
     * Higher = snappier opening. Applied when `target > current`.
     */
    public var attack:Float = 0.4;

    /**
     * Release coefficient (mouth closing speed), 0..1.
     * Higher = snappier closing. Applied when `target < current`.
     * Typically lower than `attack` for a natural look.
     */
    public var release:Float = 0.2;

    /**
     * Volume-to-mouth mapping curve exponent.
     * `> 1` = more aggressive (quiet sounds still open the mouth noticeably),
     * `< 1` = gentler. Default 1.5.
     */
    public var curve:Float = 1.5;

    /** Maximum mouth open value. Default 1.0. */
    public var maxValue:Float = 1.0;

    /**
     * Optional callback to check if a motion with mouth keyframes is
     * currently playing. When set and returns `true`, `update()` skips
     * applying the external lip sync value, letting the motion's own
     * mouth parameter keyframes take priority.
     *
     * Example: sync with `L2DMotionQueue`:
     * ```haxe
     * lipSync.motionActiveProvider = () -> motionQueue.current != null;
     * ```
     */
    public var motionActiveProvider:Null<Void -> Bool> = null;

    public function new(core:L2DCore, source:IL2DAudioSource)
    {
        this.core = core;
        this.source = source;
    }

    /**
     * Enable this controller.
     * Switches native lip sync to external mode (via `setLipSyncValue(0.0)`)
     * so that `update(dt)` can drive the mouth parameter each frame.
     * Does NOT disable `lipSyncEnabled` — the native lip sync block must
     * remain active for the external value to be applied.
     */
    public function enable():Void
    {
        if (enabled) return;
        core.setLipSyncValue(0.0); // switch to external mode
        enabled = true;
    }

    /**
     * Disable this controller.
     * Reverts to the C-side wav file handler mode by passing a
     * negative value to `setLipSyncValue`.
     */
    public function disable():Void
    {
        if (!enabled) return;
        core.setLipSyncValue(-1); // revert to wav file handler mode
        enabled = false;
        current = 0;
    }

    /**
     * Main loop update. Reads amplitude, applies curve + attack/release
     * smoothing, writes the result to `core.setLipSyncValue`.
     *
     * Skipped (no-op) when:
     * - Not enabled
     * - `motionActiveProvider` is set and returns `true` (motion takes priority)
     */
    public function update(dt:Float):Void
    {
        if (!enabled) return;

        // If a motion with mouth keyframes is playing, let it take priority
        if (motionActiveProvider != null && motionActiveProvider())
        {
            // Reset to 0 so when motion ends, we start from a clean state
            core.setLipSyncValue(0.0);
            return;
        }

        var raw = source.getAmplitude();
        var target = Math.pow(raw, curve) * maxValue;

        var coeff = target > current ? attack : release;
        // Frame-rate-independent lerp: at 60 FPS this equals `coeff`.
        var factor = 1 - Math.pow(1 - coeff, dt * 60);
        if (factor > 1) factor = 1;

        current += (target - current) * factor;
        if (current < 0) current = 0;
        if (current > maxValue) current = maxValue;

        core.setLipSyncValue(current);
    }
}
