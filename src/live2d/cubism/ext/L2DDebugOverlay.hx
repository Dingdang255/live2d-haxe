package live2d.cubism.ext;

import live2d.cubism.L2DCore;
import live2d.cubism.core.CubismAPI;

/**
 * Abstract base class for debug overlays.
 *
 * Provides toggles for drawing the model bounds and parameter values.
 * Subclasses implement `clearRect` / `drawRect` / `drawText` using the
 * backend's drawing primitives (Heaps `h2d.Graphics`, OpenFL `Shape`, etc.).
 *
 * `render()` should be called every frame by the host. It clears the
 * previous frame's drawing then redraws based on the enabled toggles.
 *
 * Usage:
 * ```haxe
 * var overlay = new L2DHeapsDebugOverlay(l2d.core, s2d);
 * overlay.showParams = true;
 * overlay.paramsToShow = ['ParamAngleX', 'ParamAngleY', 'ParamMouthOpenY'];
 * // in update: overlay.render();
 * // toggle with a key: if (Key.isPressed(Key.F1)) overlay.toggle();
 * ```
 */
class L2DDebugOverlay
{
    public var core:L2DCore;
    public var visible:Bool = false;
    public var showBounds:Bool = true;
    public var showParams:Bool = false;
    public var showHitAreas:Bool = false;
    public var paramsToShow:Array<String> = [];
    public var hitAreas:Array<String> = [];

    var textLines:Array<{text:String, x:Float, y:Float, color:Int}> = [];

    public function new(core:L2DCore)
    {
        this.core = core;
    }

    public function toggle():Void
    {
        visible = !visible;
    }

    /** Set hit area names to display (labels only — actual pixel bounds require model3.json parsing). */
    public function setHitAreas(areas:Array<String>):Void
    {
        hitAreas = areas;
    }

    /** Backend-agnostic render. Called every frame by the host. */
    public function render():Void
    {
        if (!visible) return;
        clearRect();
        textLines = [];
        if (showBounds) drawBounds();
        if (showParams) drawParams();
        if (showHitAreas) drawHitAreas();
        flushText();
    }

    function drawBounds():Void
    {
        var w = core.modelWidth * core.scale;
        var h = core.modelHeight * core.scale;
        drawRect(core.x - w / 2, core.y - h / 2, w, h, 0x00FF00);
    }

    function drawParams():Void
    {
        var y = 10;
        for (name in paramsToShow)
        {
            var idx = CubismAPI.findParameterIndex(core.model, name);
            var val = idx >= 0 ? CubismAPI.getParameterValue(core.model, idx) : 0;
            drawText('$name: ${val.toFixed(3)}', 10, y, 0xFFFFFF);
            y += 16;
        }
    }

    function drawHitAreas():Void
    {
        if (hitAreas.length == 0) return;
        var y = 10;
        // Draw on the right side to avoid overlapping params
        var x = 300;
        drawText('Hit Areas:', x, y, 0x00FFFF);
        y += 16;
        for (area in hitAreas)
        {
            drawText('  $area', x, y, 0x00FFFF);
            y += 16;
        }
    }

    // ===== Backend-specific primitives (overridden by subclasses) =====

    function clearRect():Void {}

    function drawRect(x:Float, y:Float, w:Float, h:Float, color:Int):Void {}

    function drawText(text:String, x:Float, y:Float, color:Int):Void
    {
        textLines.push({text: text, x: x, y: y, color: color});
    }

    /** Called after all drawing primitives to flush queued text lines. */
    function flushText():Void {}
}
