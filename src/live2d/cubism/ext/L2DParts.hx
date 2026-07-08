package live2d.cubism.ext;

import live2d.cubism.L2DCore;
import live2d.cubism.ext.L2DPartHandle.L2DPartTween;

/**
 * Manager for all parts of a model.
 *
 * Caches `L2DPartHandle` instances at construction time (one per part
 * index), exposes name-based lookup, and owns active tweens so callers
 * only need to call `update(dt)` once per frame.
 *
 * Usage:
 * ```haxe
 * var parts = new L2DParts(core);
 * parts.tween("PartHair", 0.0, 0.3); // fade hair out over 0.3s
 * // in update loop:
 * parts.update(dt);
 * ```
 */
class L2DParts {
    var core:L2DCore;
    var handles:Array<L2DPartHandle> = [];
    var tweens:Array<L2DPartTween> = [];
    var nameToIndex:Map<String, Int> = new Map();

    public function new(core:L2DCore) {
        this.core = core;
        var count = core.getPartCount();
        for (i in 0...count) {
            var name = core.getPartId(i);
            handles.push(new L2DPartHandle(core, i, name));
            nameToIndex.set(name, i);
        }
    }

    /** Get a part handle by name. Returns null if not found. */
    public function part(name:String):L2DPartHandle {
        if (!nameToIndex.exists(name)) return null;
        return handles[nameToIndex.get(name)];
    }

    /** Get a part handle by index. */
    public function at(index:Int):L2DPartHandle {
        return handles[index];
    }

    /** Total part count. */
    public var count(get, never):Int;
    inline function get_count():Int return handles.length;

    /** Start a tween on a part. Returns the tween handle, or null if name not found. */
    public function tween(name:String, target:Float, duration:Float):L2DPartTween {
        var h = part(name);
        if (h == null) return null;
        var t = h.tweenTo(target, duration);
        tweens.push(t);
        return t;
    }

    /** Update all active tweens. Call every frame. */
    public function update(dt:Float):Void {
        if (tweens.length == 0) return;
        var i = tweens.length - 1;
        while (i >= 0) {
            tweens[i].update(dt);
            if (tweens[i].done) tweens.splice(i, 1);
            i--;
        }
    }

    /** Reset all parts to default opacity (calls core.resetPose()). Cancels active tweens. */
    public function reset():Void {
        for (t in tweens) t.cancel();
        tweens = [];
        core.resetPose();
    }

    /** Cancel all active tweens without resetting opacity. */
    public function cancelAllTweens():Void {
        for (t in tweens) t.cancel();
        tweens = [];
    }
}
