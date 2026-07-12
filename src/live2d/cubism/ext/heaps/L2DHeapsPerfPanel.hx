package live2d.cubism.ext.heaps;

#if heaps

import h2d.Object;
import h2d.Scene;
import h2d.Text;
import hxd.res.DefaultFont;

/**
 * Heaps backend performance panel.
 *
 * Renders as a semi-transparent `h2d.Text` overlay with a dark background
 * quad, positioned in the top-left corner of the scene.
 *
 * Usage:
 *   var panel = new L2DHeapsPerfPanel();
 *   panel.attachTo(core, renderer, s2d);   // s2d = h2d.Scene
 *   panel.enabled = true;
 *   panel.visible = true;
 *   // in update loop: panel.update(dt);
 */
class L2DHeapsPerfPanel extends live2d.cubism.ext.L2DPerfPanel
{
    var container:Object;
    var text:Text;
    var displayText:String = "";
    var lastContainerX:Float = 2;
    var lastContainerY:Float = 200;
    public var renderer:live2d.cubism.backend.heaps.HeapsRenderer;

    static final FG_COLOR = 0xFF00FF00;

    public function new()
    {
        super();
    }

    /**
     * @param core     L2DCore instance
     * @param renderer HeapsRenderer instance (for mask RT info)
     * @param parent   h2d.Scene to add to
     */
    public function attachToExt(core:live2d.cubism.L2DCore,
                                 renderer:live2d.cubism.backend.heaps.HeapsRenderer,
                                 parent:h2d.Scene):Void
    {
        attachTo(core, parent);
        this.renderer = renderer;

        var scene:Scene = cast parent;
        container = new Object(scene);
        container.x = lastContainerX;
        container.y = lastContainerY;

        var font = DefaultFont.get();
        text = new Text(font, container);
        text.textColor = FG_COLOR;
        text.x = 4;
        text.y = 2;

        container.visible = false;
    }

    /** Reposition the panel. Call after setPosition and re-attach in attachment callbacks. */
    public function setPosition(x:Float, y:Float):Void
    {
        lastContainerX = x;
        lastContainerY = y;
        if (container != null) { container.x = x; container.y = y; }
    }

    override function onVisibilityChanged(visible:Bool):Void
    {
        if (container != null) container.visible = visible;
    }

    override function onEnableChanged(enabled:Bool):Void
    {
        if (container != null && !enabled) container.visible = false;
    }

    override function refreshDisplayText():Void
    {
        var buf = new StringBuf();
        buf.add("FPS: ");
        buf.add(fps);
        buf.add(" | FT: ");
        var ftRounded = Math.round(frameTime * 10) / 10;
        buf.add(ftRounded);
        buf.add(" ms  Batches: ");
        buf.add(batchCount + " / " + drawableCount + "\n");
        buf.add("MaskRT: ");
        buf.add(maskRTSize);
        buf.add("  Model: " + modelInfo + "\n");
        buf.add(moduleBadges);
        displayText = buf.toString();
    }

    override function syncDisplay():Void
    {
        if (text != null) text.text = displayText;
    }

    override public function detach():Void
    {
        if (container != null)
        {
            container.remove();
            container = null;
        }
        text = null;
        renderer = null;
        super.detach();
    }

    override public function dispose():Void
    {
        detach();
        super.dispose();
    }
}

#end
