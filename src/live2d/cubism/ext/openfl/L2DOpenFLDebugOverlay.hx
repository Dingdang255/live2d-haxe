package live2d.cubism.ext.openfl;

#if openfl

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import live2d.cubism.L2DCore;
import live2d.cubism.ext.L2DDebugOverlay;

/**
 * OpenFL backend debug overlay.
 *
 * Uses `openfl.display.Shape` for bounds rectangle and `openfl.text.TextField`
 * for parameter labels. Both are attached to the given parent `Sprite`.
 *
 * Text lines are rendered as a single multi-line `TextField` (colors and
 * per-line positions are ignored — all text uses the TextField's format at `10, 10`).
 */
class L2DOpenFLDebugOverlay extends L2DDebugOverlay
{
    var shape:Shape;
    var textField:TextField;

    public function new(core:L2DCore, parent:Sprite)
    {
        super(core);
        shape = new Shape();
        parent.addChild(shape);
        textField = new TextField();
        textField.defaultTextFormat = new TextFormat(null, 12, 0xFFFFFF);
        textField.x = 10;
        textField.y = 10;
        textField.width = 400;
        textField.height = 300;
        textField.selectable = false;
        textField.mouseEnabled = false;
        parent.addChild(textField);
    }

    override function clearRect():Void
    {
        shape.graphics.clear();
        textField.text = '';
    }

    override function drawRect(x:Float, y:Float, w:Float, h:Float, color:Int):Void
    {
        shape.graphics.lineStyle(1, color);
        shape.graphics.drawRect(x, y, w, h);
    }

    override function flushText():Void
    {
        if (textLines.length == 0)
        {
            textField.visible = false;
            return;
        }
        var sb = new StringBuf();
        for (line in textLines)
        {
            sb.add(line.text);
            sb.add('\n');
        }
        textField.text = sb.toString();
        textField.visible = true;
    }

    override public function toggle():Void
    {
        super.toggle();
        shape.visible = visible;
        textField.visible = visible;
    }
}

#end
