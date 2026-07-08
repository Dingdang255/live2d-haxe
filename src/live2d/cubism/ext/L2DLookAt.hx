package live2d.cubism.ext;

import live2d.cubism.L2DCore;

/**
 * Smooth mouse/touch → head/eye follow with damping, deadzone, and auto-return.
 *
 * Wraps `L2DCore.setDragging(x, y)` with frame-rate-independent lerp so the
 * head doesn't snap to the cursor. When no target is set (or `release()`
 * is called), the look direction eases back to the model center.
 *
 * Usage:
 * ```haxe
 * var lookAt = new L2DLookAt(core);
 * lookAt.followSpeed = 0.2;  // lerp coefficient, 0..1
 * lookAt.deadzone = 5;       // px
 *
 * // In update loop:
 * lookAt.update(dt);
 *
 * // On mouse move:
 * lookAt.setTarget(mouseX, mouseY);
 *
 * // On mouse leave / release:
 * lookAt.release();  // eases back to model center
 * ```
 *
 * Note: while LookAt is active, do NOT call `core.setDragging()` directly —
 * it will conflict with this class's per-frame update. Use `pause()` /
 * `resume()` to temporarily hand control back to the user.
 */
class L2DLookAt
{
    var core:L2DCore;

    /** Current target screen coordinates, or null if released (returning home). */
    var targetX:Null<Float>;
    var targetY:Null<Float>;

    /** Current "look at" position (eased toward target each frame). */
    var currentX:Float;
    var currentY:Float;

    /** Whether to apply updates to `core.setDragging`. False when paused. */
    var paused:Bool = false;

    /** Whether currentX/Y have been initialized to home. */
    var initialized:Bool = false;

    /**
     * Lerp coefficient (0..1). Higher = snappier follow.
     * At 60 FPS, this is the fraction of the distance covered per frame.
     * Frame-rate-independent: the same value gives consistent feel at 30/60/144 FPS.
     * Recommended range: 0.1 (lazy) to 0.4 (snappy). Default 0.2.
     */
    public var followSpeed:Float = 0.2;

    /**
     * Deadzone radius in screen pixels. If `current` is within this radius of
     * `target`, `setDragging` is not called that frame — prevents micro-jitter
     * from noisy mouse input. Default 5.
     */
    public var deadzone:Float = 5.0;

    /**
     * Return-to-center target X. Defaults to `core.x` (model screen position).
     * Override to anchor the gaze elsewhere (e.g. screen center).
     */
    public var homeX(get, set):Float;
    var _homeX:Null<Float>;
    function get_homeX():Float return _homeX != null ? _homeX : core.x;
    function set_homeX(v:Float):Float { _homeX = v; return v; }

    public var homeY(get, set):Float;
    var _homeY:Null<Float>;
    function get_homeY():Float return _homeY != null ? _homeY : core.y;
    function set_homeY(v:Float):Float { _homeY = v; return v; }

    public function new(core:L2DCore)
    {
        this.core = core;
        this.currentX = core.x;
        this.currentY = core.y;
    }

    /** Set the look-at target. Pass null for either to release (return to home). */
    public function setTarget(?screenX:Float, ?screenY:Float):Void
    {
        this.targetX = screenX;
        this.targetY = screenY;
    }

    /** Release the target — look direction eases back to home. */
    public function release():Void
    {
        this.targetX = null;
        this.targetY = null;
    }

    /** Temporarily stop applying updates to `core.setDragging`. */
    public function pause():Void paused = true;

    /** Resume applying updates. */
    public function resume():Void paused = false;

    /** Jump current directly to target (skip easing for one frame). */
    public function snapToTarget():Void
    {
        if (targetX != null && targetY != null)
        {
            currentX = targetX;
            currentY = targetY;
        }
        else
        {
            currentX = homeX;
            currentY = homeY;
        }
        initialized = true;
        if (!paused) core.setDragging(currentX, currentY);
    }

    /** Main loop update. Call once per frame. */
    public function update(dt:Float):Void
    {
        if (paused) return;

        // Lazy-init current to home so the first frame doesn't snap from (0,0).
        if (!initialized)
        {
            currentX = homeX;
            currentY = homeY;
            initialized = true;
        }

        // Resolve effective target.
        var tx:Float = targetX != null ? targetX : homeX;
        var ty:Float = targetY != null ? targetY : homeY;

        // Deadzone: if current is within deadzone of target, skip update entirely.
        var dx = tx - currentX;
        var dy = ty - currentY;
        if (Math.sqrt(dx * dx + dy * dy) < deadzone) return;

        // Frame-rate-independent lerp: at 60 FPS this equals `followSpeed`,
        // at lower FPS catches up, at higher FPS eases off.
        var factor = 1 - Math.pow(1 - followSpeed, dt * 60);
        if (factor > 1) factor = 1;

        currentX += dx * factor;
        currentY += dy * factor;

        core.setDragging(currentX, currentY);
    }
}
