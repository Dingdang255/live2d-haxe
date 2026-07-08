package live2d.cubism.ext;

import live2d.cubism.L2DCore;

/**
 * Chainable handle for a single model part.
 *
 * Wraps `L2DCore.getPartOpacity`/`setPartOpacity` with a fluent API
 * so callers can write `parts.part("Hair").set(0.5).show().hide()`.
 */
class L2DPartHandle {
    var core:L2DCore;
    public var index(default, null):Int;
    public var name(default, null):String;

    public function new(core:L2DCore, index:Int, name:String) {
        this.core = core;
        this.index = index;
        this.name = name;
    }

    /** Get current opacity [0, 1]. */
    public function get():Float return core.getPartOpacity(index);

    /** Set opacity [0, 1]. Returns this for chaining. */
    public function set(opacity:Float):L2DPartHandle {
        core.setPartOpacity(index, opacity);
        return this;
    }

    /** Shortcut for set(1). */
    public function show():L2DPartHandle return set(1.0);

    /** Shortcut for set(0). */
    public function hide():L2DPartHandle return set(0.0);

    /** Toggle between 0 and 1. */
    public function toggle():L2DPartHandle {
        return get() > 0.5 ? hide() : show();
    }

    /** Fade to target over `duration` seconds. Returns a tween handle. */
    public function tweenTo(target:Float, duration:Float):L2DPartTween {
        return new L2DPartTween(this, get(), target, duration);
    }
}

/**
 * Eased tween for a single part's opacity.
 *
 * Update every frame via `L2DParts.update(dt)` (the manager owns
 * active tweens) or manually if created standalone. Uses ease-in-out
 * cubic. Fire-and-forget: the tween auto-marks itself `done` on
 * completion and calls `onComplete` if set.
 */
class L2DPartTween {
    var handle:L2DPartHandle;
    var from:Float;
    var to:Float;
    var duration:Float;
    var elapsed:Float = 0;
    public var done(default, null):Bool = false;
    public dynamic function onComplete():Void {}

    public function new(handle:L2DPartHandle, from:Float, to:Float, duration:Float) {
        this.handle = handle;
        this.from = from;
        this.to = to;
        this.duration = duration;
    }

    public function update(dt:Float):Void {
        if (done) return;
        elapsed += dt;
        var t = duration <= 0 ? 1.0 : Math.min(elapsed / duration, 1.0);
        var eased = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
        handle.set(from + (to - from) * eased);
        if (t >= 1.0) {
            done = true;
            onComplete();
        }
    }

    public function cancel():Void { done = true; }
}
