package live2d.cubism.ext.openfl;

#if openfl

import openfl.display.DisplayObjectContainer;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.display.Sprite;

/**
 * OpenFL backend performance panel.
 *
 * Renders as a semi-transparent `TextField` overlay positioned at the
 * top-right corner of the stage (or a custom parent).
 *
 * Usage:
 *   var panel = new L2DOpenFLPerfPanel();
 *   panel.attachTo(core, stage);     // stage = openfl.display.Stage
 *   panel.enabled = true;
 *   panel.visible = true;
 *   // in update loop: panel.update(dt);
 */
class L2DOpenFLPerfPanel extends live2d.cubism.ext.L2DPerfPanel
{
    var container:Sprite;
    var tf:TextField;
    var displayText:String = "";

    static final FG_COLOR = 0x00FF00;
    static final BG_COLOR = 0x111111;

    public function new()
    {
        super();
    }

    override public function attachTo(core:live2d.cubism.L2DCore, ?parent:Dynamic):Void
    {
        // Clean up old display objects before re-attaching to new model
        detachDisplayObjects();

        super.attachTo(core, parent);

        var stage:DisplayObjectContainer = cast parent;
        container = new Sprite();
        container.x = 8;
        container.y = 8;

        tf = new TextField();
        tf.selectable = false;
        tf.mouseEnabled = false;
        tf.width = 300;
        tf.height = 120;
        tf.background = true;
        tf.backgroundColor = BG_COLOR;
        tf.defaultTextFormat = new TextFormat("_sans", 12, FG_COLOR);
        container.addChild(tf);

        container.visible = false;
        stage.addChild(container);

        // Sync new display objects with current visibility state after re-attach
        onVisibilityChanged(this.visible);
    }

    /** Remove display objects from the current parent without clearing references elsewhere. */
    function detachDisplayObjects():Void
    {
        if (container != null)
        {
            if (container.parent != null) container.parent.removeChild(container);
            container = null;
        }
        tf = null;
    }

    override function onVisibilityChanged(visible:Bool):Void
    {
        if (container != null) container.visible = visible;
    }

    override function refreshDisplayText():Void
    {
        var buf = new StringBuf();
        buf.add("FPS: ");
        buf.add(fps);
        buf.add(" | FT: ");
		var ftRounded = Math.round(frameTime * 10) / 10;
		buf.add(ftRounded);
        buf.add(" ms\n");
        buf.add("Batches: ");
        buf.add(batchCount + " | Drawables: " + drawableCount + "\n");
        buf.add("MaskRT: ");
        buf.add(maskRTSize + " | Model: " + modelInfo + "\n");
        buf.add("Modules: ");
        buf.add(moduleBadges);
        tf.autoSize = openfl.text.TextFieldAutoSize.LEFT;
        displayText = buf.toString();
    }

    override function syncDisplay():Void
    {
        if (tf != null) tf.text = displayText;
    }

    override public function detach():Void
    {
        if (container != null)
        {
            if (container.parent != null) container.parent.removeChild(container);
            container = null;
        }
        tf = null;
        super.detach();
    }

    override public function dispose():Void
    {
        detach();
        super.dispose();
    }
}

#end
