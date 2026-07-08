package live2d.cubism.heaps;

#if heaps

import h2d.Object;
import h2d.RenderContext;
import live2d.cubism.L2DCore;
import live2d.cubism.backend.heaps.HeapsRenderer;
import live2d.cubism.core.CubismAPI;
import live2d.cubism.core.L2DModel;

/**
 * Heaps framework integration for Live2D models.
 *
 * Wraps `L2DCore` as an `h2d.Object` using the Heaps rendering backend.
 * The object auto-updates and renders in `sync(ctx)`, so adding it to
 * the scene graph is enough — no manual `update`/`render` calls needed.
 *
 * Usage:
 * ```haxe
 * var l2d = new L2DHeapsObject('assets/live2d/Haru/', 'Haru.model3.json', s2d);
 * l2d.core.x = s2d.width / 2;
 * l2d.core.y = s2d.height / 2;
 * l2d.core.scale = (s2d.height * 0.8) / l2d.core.modelHeight;
 * l2d.core.startIdleMotion();
 * ```
 *
 * Transform note: `h2d.Object` already has `x`, `y`, `alpha` fields and `scale(v)`
 * method (multiplicative scaling). To avoid double-transform (L2DCore applies
 * `core.x/y/scale` in vertex computation, and the container inherits this object's
 * transform), this object keeps its own `x`, `y`, `scaleX`, `scaleY`, `alpha` at
 * identity. Set model position, scale, and opacity via `core.x`, `core.y`,
 * `core.scale`, `core.alpha`. Do NOT use `scaleX`/`scaleY` or `scale(v)` method.
 */
class L2DHeapsObject extends Object
{
    /** Underlying L2DCore. Exposed for advanced access (x, y, alpha, model, ...). */
    public var core(default, null):L2DCore;

    /** Heaps renderer instance backing this object. */
    var renderer:HeapsRenderer;

    /**
     * Create a Live2D model and attach it to the scene.
     * @param dir Path to the model directory (trailing slash required).
     * @param fileName Model setting file name (e.g. `Haru.model3.json`).
     * @param parent Optional parent `h2d.Object` (usually `s2d`).
     */
    public function new(dir:String, fileName:String, ?parent:Object)
    {
        super(parent);
        renderer = new HeapsRenderer(this);
        core = new L2DCore(dir, fileName, CubismAPI.getBridge(), renderer);
    }

    // ===== Heaps lifecycle =====

    override function sync(ctx:RenderContext):Void
    {
        super.sync(ctx);
        if (core != null && core.model.notNull())
        {
            core.update(hxd.Timer.dt);
            core.render();
        }
    }

    override function onRemove():Void
    {
        if (core != null)
        {
            core.destroy();
            core = null;
        }
        super.onRemove();
    }

    // ===== Model info =====

    /** Underlying model handle. */
    public var model(get, never):L2DModel;
    inline function get_model():L2DModel return core.model;

    /** Directory the model was loaded from. */
    public var modelDir(get, never):String;
    inline function get_modelDir():String return core.modelDir;

    /** Model setting file name. */
    public var modelFileName(get, never):String;
    inline function get_modelFileName():String return core.modelFileName;

    /** Computed model width (canvas units). */
    public var modelWidth(get, never):Float;
    inline function get_modelWidth():Float return core.modelWidth;

    /** Computed model height (canvas units). */
    public var modelHeight(get, never):Float;
    inline function get_modelHeight():Float return core.modelHeight;
}

#end
