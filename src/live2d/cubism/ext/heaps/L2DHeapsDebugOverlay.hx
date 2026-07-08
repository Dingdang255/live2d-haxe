package live2d.cubism.ext.heaps;

#if heaps

import h2d.Graphics;
import h2d.Object;
import h2d.Text;
import hxd.res.DefaultFont;
import live2d.cubism.L2DCore;
import live2d.cubism.ext.L2DDebugOverlay;

/**
 * Heaps backend debug overlay.
 *
 * Uses `h2d.Graphics` for bounds rectangle and `h2d.Text` for parameter
 * labels. Both are attached to the given parent `h2d.Object` (usually `s2d`).
 *
 * Text lines are rendered as a single multi-line `h2d.Text` (colors and
 * per-line positions are ignored — all text uses the Text's color at `10, 10`).
 */
class L2DHeapsDebugOverlay extends L2DDebugOverlay
{
    var graphics:Graphics;
    var text:Text;

    public function new(core:L2DCore, parent:Object)
    {
        super(core);
        graphics = new Graphics(parent);
        text = new Text(DefaultFont.get(), parent);
        text.textColor = 0xFFFFFF;
        text.x = 10;
        text.y = 10;
        text.visible = false;
    }

    override function clearRect():Void
    {
        graphics.clear();
        text.text = '';
    }

    override function drawRect(x:Float, y:Float, w:Float, h:Float, color:Int):Void
    {
        graphics.lineStyle(1, color);
        graphics.drawRect(x, y, w, h);
    }

    override function flushText():Void
    {
        if (textLines.length == 0)
        {
            text.visible = false;
            return;
        }
        var sb = new StringBuf();
        for (line in textLines)
        {
            sb.add(line.text);
            sb.add('\n');
        }
        text.text = sb.toString();
        text.visible = true;
    }

    override public function toggle():Void
    {
        super.toggle();
        graphics.visible = visible;
        text.visible = visible;
    }
}

#end
