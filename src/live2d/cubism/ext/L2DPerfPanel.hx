package live2d.cubism.ext;

/**
 * Abstract base class for performance panels.
 *
 * Collects runtime rendering stats from an `L2DCore` instance and presents
 * them as on-screen text via backend-specific display objects.
 *
 * Usage:
 *   var panel = new L2DHeapsPerfPanel();
 *   panel.enabled = true;    // starts collecting
 *   panel.visible = true;    // shows on screen
 *   panel.attachTo(core, s2d);
 *   // in update loop: panel.update(dt);
 */
class L2DPerfPanel
{
    /** Master switch — when false, no collection or rendering occurs. */
    public var enabled(default, set):Bool = false;
    /** Whether the panel text is visible on screen. */
    public var visible(default, set):Bool = false;

    public function new()
    {
    }

    /** Smoothed frame time in milliseconds (moving average, alpha=0.1). */
	public var frameTime(default, null):Float = 0;
	/** Real-time frames per second (computed from 1/dt). */
	public var fps(default, null):Int = 0;
	/** Number of active batches in the last frame. */
    public var batchCount(default, null):Int = 0;
    /** Number of drawables in the model. */
    public var drawableCount(default, null):Int = 0;
    /** Mask RT dimensions (e.g. "235x480"), or "N/A". */
    public var maskRTSize(default, null):String = "N/A";
    /** Model name + pixel dimensions (e.g. "Haru 1200x1800"). */
    public var modelInfo(default, null):String = "";
    /** Active module badges (e.g. "B P L" for Breath Physics LipSync). */
    public var moduleBadges(default, null):String = "";

    var core:live2d.cubism.L2DCore;
    var disposed:Bool = false;

    // Moving average smoothing alpha (0 = no history, 1 = instant, 0.1 = heavy smoothing)
    static inline var FRAME_TIME_SMOOTH = 0.1;

    function set_enabled(v:Bool):Bool
    {
        if (enabled == v) return v;
        enabled = v;
        onEnableChanged(v);
        return v;
    }

    function set_visible(v:Bool):Bool
    {
        if (visible == v) return v;
        visible = v;
        onVisibilityChanged(v);
        return v;
    }

    /**
     * Attach to an L2DCore for data collection.
     * Optionally pass a backend-specific parent object (e.g. h2d.Scene,
     * openfl.display.DisplayObjectContainer, flixel.FlxState).
     */
    public function attachTo(core:live2d.cubism.L2DCore, ?parent:Dynamic):Void
    {
        this.core = core;
        modelInfo = core.modelFileName + " " + core.modelWidth + "x" + core.modelHeight;
    }

    /** Called each frame — collects stats and updates display text. */
    public function update(dt:Float):Void
    {
        if (!enabled || disposed || core == null) return;

        // Smooth frame time
		if (frameTime == 0)
			frameTime = dt * 1000;
		else
			frameTime = frameTime * (1 - FRAME_TIME_SMOOTH) + (dt * 1000) * FRAME_TIME_SMOOTH;

		// FPS from dt (smoothed)
		if (dt > 0)
			fps = Math.round(1.0 / dt);

        // Stats from core
        batchCount = core.batchCount;
        drawableCount = core.drawableCount;

        // Mask RT size from core (universal across all backends)
        if (core.maskRTWidth > 0)
            maskRTSize = core.maskRTWidth + "x" + core.maskRTHeight;

        // Module badges (single-letter abbreviations)
        var buf = new StringBuf();
        if (core.breathEnabled) buf.add("B ");
        if (core.physicsEnabled) buf.add("P ");
        if (core.lipSyncEnabled) buf.add("L ");
        if (core.expressionEnabled) buf.add("E ");
        if (core.eyeBlinkEnabled) buf.add("Bk ");
        if (core.poseEnabled) buf.add("Ps ");
        moduleBadges = buf.toString();

        // Build display text
        refreshDisplayText();

        // Update backend-specific display object
        if (visible) syncDisplay();
    }

    function refreshDisplayText():Void
    {
        // Override in subclass to format text
    }

    /** Detach and clean up. Subclasses must call super.detach(). */
    public function detach():Void
    {
        enabled = false;
        visible = false;
        core = null;
    }

    /** Dispose all resources. */
    public function dispose():Void
    {
        if (disposed) return;
        disposed = true;
        detach();
    }

    // ===== Abstract callbacks (override in backend subclasses) =====

    function onEnableChanged(enabled:Bool):Void {}
    function onVisibilityChanged(visible:Bool):Void {}
    function syncDisplay():Void {}
}
