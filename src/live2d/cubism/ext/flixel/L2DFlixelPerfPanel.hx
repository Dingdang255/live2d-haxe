package live2d.cubism.ext.flixel;

#if flixel

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

/**
 * Flixel backend performance panel.
 *
 * Renders as a `FlxText` with a semi-transparent dark background sprite,
 * positioned at the top-right corner.
 *
 * Usage:
 *   var panel = new L2DFlixelPerfPanel();
 *   panel.attachTo(core, state);     // state = FlxState
 *   panel.enabled = true;
 *   panel.visible = true;
 *   // in update loop: panel.update(dt);
 */
class L2DFlixelPerfPanel extends live2d.cubism.ext.L2DPerfPanel
{
    var bg:FlxSprite;
    var tf:FlxText;
    var displayText:String = "";
    var state:flixel.FlxState;

    static final FG_COLOR = 0xFF00FF00;
    static final BG_COLOR = 0xAA111111;

    public function new()
    {
        super();
    }

    override public function attachTo(core:live2d.cubism.L2DCore, ?parent:Dynamic):Void
    {
        // Clean up old display objects before re-attaching to new model
        detachDisplayObjects();

        super.attachTo(core, parent);

        state = cast parent;

        bg = new FlxSprite(FlxG.width - 192, 4);
        bg.makeGraphic(184, 100, BG_COLOR);
        bg.scrollFactor.set(0, 0);
        bg.visible = false;

        tf = new FlxText(FlxG.width - 188, 6, 180, "", 10);
        tf.setFormat(null, 10, FG_COLOR);
        tf.scrollFactor.set(0, 0);
        tf.visible = false;

        state.add(bg);
        state.add(tf);

        // Sync new display objects with current visibility state after re-attach
        onVisibilityChanged(this.visible);
    }

    /** Remove display objects from the current state without clearing references elsewhere. */
    function detachDisplayObjects():Void
    {
        if (bg != null && state != null)
        {
            state.remove(bg);
            bg = null;
        }
        if (tf != null && state != null)
        {
            state.remove(tf);
            tf = null;
        }
    }

    override function onVisibilityChanged(visible:Bool):Void
    {
        if (bg != null) bg.visible = visible;
        if (tf != null) tf.visible = visible;
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
		buf.add(batchCount + " / " + drawableCount + "\n");
		buf.add("MaskRT: ");
		buf.add(maskRTSize + "\n");
		buf.add("Model: " + modelInfo + "\n");
		buf.add(moduleBadges);
		displayText = buf.toString();
	}

    override function syncDisplay():Void
    {
        if (tf != null) tf.text = displayText;
    }

    override public function detach():Void
    {
        if (bg != null)
        {
            if (state != null) state.remove(bg);
            bg = null;
        }
        if (tf != null)
        {
            if (state != null) state.remove(tf);
            tf = null;
        }
        state = null;
        super.detach();
    }

    override public function dispose():Void
    {
        detach();
        super.dispose();
    }
}

#end
