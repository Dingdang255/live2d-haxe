package live2d.cubism.heaps;

#if heaps

import h2d.Object;
import h2d.RenderContext;
import h2d.filter.Filter;
import h2d.filter.Group;
import live2d.cubism.L2DCore;
import live2d.cubism.backend.heaps.HeapsRenderer;
import live2d.cubism.core.CubismAPI;
import live2d.cubism.core.L2DModel;
#if sys
import haxe.Json;
import sys.FileSystem;
import sys.io.File as SysFile;
#end

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

    /** Lazily-created filter group for chained filter effects. */
    var filterGroup:Group;

    /** Mirror of `filterGroup`'s contents (Group.filters is private). */
    var filterList:Array<Filter> = [];

    /** Stored model directory (for hot-reload). */
    var _dir:String;

    /** Stored model file name (for hot-reload). */
    var _fileName:String;

    /** Whether hot-reload is enabled. Set to true to start watching model files for changes. */
    public var hotReloadEnabled:Bool = false;

    /** Files watched for mtime changes (model3.json, .moc3, physics, pose, expressions). */
    var watchedFiles:Array<String> = [];

    /** Snapshot mtimes corresponding to `watchedFiles`. */
    var watchedMtimes:Array<Float> = [];

    /** Set when a reload failed (e.g. file mid-write); retried on next frame. */
    var reloadPending:Bool = false;

    /**
     * Create a Live2D model and attach it to the scene.
     * @param dir Path to the model directory (trailing slash required).
     * @param fileName Model setting file name (e.g. `Haru.model3.json`).
     * @param parent Optional parent `h2d.Object` (usually `s2d`).
     */
    public function new(dir:String, fileName:String, ?parent:Object)
    {
        super(parent);
        _dir = dir;
        _fileName = fileName;
        renderer = new HeapsRenderer(this);
        core = new L2DCore(dir, fileName, CubismAPI.getBridge(), renderer);
    }

    // ===== Heaps lifecycle =====

    override function sync(ctx:RenderContext):Void
    {
        #if sys
        if (hotReloadEnabled && core != null && core.model.notNull())
        {
            if (watchedFiles.length == 0) buildWatchList();
            if (reloadPending || checkMtimesChanged()) reload();
        }
        #end

        // core.update+render MUST run before super.sync(ctx): super.sync traverses
        // children (L2DMeshDrawable.sync → primitive.flush) which uploads vertex
        // data to GPU. If core.render runs after, it marks dirty=true and the draw
        // phase re-flushes — causing a double GPU upload per frame. With this order,
        // core.render sets current-frame data (dirty=true) → super.sync flushes once
        // (dirty→false) → draw phase sees dirty=false and skips flush.
        if (core != null && core.model.notNull())
        {
            core.update(hxd.Timer.dt);
            core.render();
        }
        super.sync(ctx);
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

    // ===== Filter chain =====

    /**
     * Add a filter to this model's filter chain. The first call lazily creates
     * an `h2d.filter.Group` and binds it to `this.filter`. Subsequent calls
     * append to the chain — filters are applied in order during the draw phase.
     *
     * Mask rendering is unaffected: masks are rendered off-screen during
     * `sync()` (before `super.sync`), while filters apply during `draw()`,
     * so the two are independent.
     *
     * Note: filters added after the object is added to the scene won't receive
     * a `bind()` call (Heaps `Group` limitation). Built-in filters (Glow, Blur,
     * Outline, ColorMatrix, DropShadow) don't override `bind()`, so this is
     * a non-issue for them.
     */
    public function addFilter(f:Filter):Void
    {
        if (filterGroup == null)
        {
            filterGroup = new Group();
            this.filter = filterGroup;
        }
        filterGroup.add(f);
        filterList.push(f);
    }

    /**
     * Remove a filter from the chain. Returns `true` if the filter was found
     * and removed.
     */
    public function removeFilter(f:Filter):Bool
    {
        if (filterGroup == null) return false;
        var removed = filterGroup.remove(f);
        if (removed) filterList.remove(f);
        return removed;
    }

    /**
     * Remove all filters and unbind the filter group from this object.
     */
    public function clearFilters():Void
    {
        this.filter = null;
        filterGroup = null;
        filterList = [];
    }

    /**
     * Returns a copy of the current filter chain, or an empty array if no
     * filters are set.
     */
    public function getFilters():Array<Filter>
    {
        return [for (f in filterList) f];
    }

    // ===== Hot-reload =====

    #if sys
    /**
     * Build the list of files to watch for hot-reload: model3.json itself,
     * the .moc3 file, and referenced Physics/Pose/Expression files.
     * Motions and textures are excluded (too noisy). Snapshots mtimes.
     */
    function buildWatchList():Void
    {
        watchedFiles = [];
        watchedMtimes = [];

        var modelPath = _dir + _fileName;
        watchedFiles.push(modelPath);

        try
        {
            var content = SysFile.getContent(modelPath);
            var json = Json.parse(content);
            if (json.FileReferences != null)
            {
                if (json.FileReferences.Moc != null)
                    watchedFiles.push(_dir + json.FileReferences.Moc);
                if (json.FileReferences.Physics != null && json.FileReferences.Physics != "")
                    watchedFiles.push(_dir + json.FileReferences.Physics);
                if (json.FileReferences.Pose != null && json.FileReferences.Pose != "")
                    watchedFiles.push(_dir + json.FileReferences.Pose);
                if (json.FileReferences.Expressions != null)
                    for (e in cast(json.FileReferences.Expressions, Array<Dynamic>))
                        if (e.File != null) watchedFiles.push(_dir + e.File);
            }
        }
        catch (e:Dynamic)
        {
            trace("[L2D] hot reload: failed to parse model3.json for watch list: " + e);
        }

        for (f in watchedFiles)
        {
            if (FileSystem.exists(f))
                watchedMtimes.push(FileSystem.stat(f).mtime.getTime());
            else
                watchedMtimes.push(0);
        }
    }

    /** Check if any watched file's mtime has changed since the last snapshot. */
    function checkMtimesChanged():Bool
    {
        for (i in 0...watchedFiles.length)
        {
            var f = watchedFiles[i];
            if (FileSystem.exists(f))
            {
                var mtime = FileSystem.stat(f).mtime.getTime();
                if (mtime != watchedMtimes[i]) return true;
            }
        }
        return false;
    }

    /**
     * Reload the model from disk using construct-new-then-swap.
     * Preserves transform (x/y/scale/alpha). If the new model fails to load
     * (e.g. file is mid-write), sets `reloadPending` to retry next frame.
     */
    function reload():Void
    {
        trace("[L2D] hot reload: attempting...");
        var savedX = core.x;
        var savedY = core.y;
        var savedScale = core.scale;
        var savedAlpha = core.alpha;

        var newRenderer:HeapsRenderer = null;
        var newCore:L2DCore = null;
        try
        {
            newRenderer = new HeapsRenderer(this);
            newCore = new L2DCore(_dir, _fileName, CubismAPI.getBridge(), newRenderer);
        }
        catch (e:Dynamic)
        {
            trace("[L2D] hot reload: load threw (" + e + "), will retry");
            if (newCore != null) newCore.destroy();
            else if (newRenderer != null) newRenderer.destroyContainer();
            reloadPending = true;
            return;
        }

        if (!newCore.model.notNull())
        {
            trace("[L2D] hot reload: model load failed (file may be mid-write), will retry");
            newCore.destroy();
            reloadPending = true;
            return;
        }

        core.destroy();
        renderer = newRenderer;
        core = newCore;

        core.x = savedX;
        core.y = savedY;
        core.scale = savedScale;
        core.alpha = savedAlpha;

        buildWatchList();
        core.startIdleMotion();
        reloadPending = false;
        trace("[L2D] hot reload complete");
    }
    #end
}

#end
