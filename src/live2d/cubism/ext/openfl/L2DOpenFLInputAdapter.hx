package live2d.cubism.ext.openfl;

#if openfl

import openfl.display.Sprite;
import openfl.events.MouseEvent;
import live2d.cubism.ext.IL2DInputAdapter;

/**
 * OpenFL input adapter — event-based.
 *
 * Wraps `openfl.display.Sprite` mouse events and forwards them as
 * unified `(x, y)` screen coordinates via callbacks.
 *
 * Usage:
 * ```haxe
 * var adapter = new L2DOpenFLInputAdapter(sprite);
 * adapter.bindMove((x, y) -> lookAt.setTarget(x, y));
 * adapter.bindDown((x, y) -> dispatcher.hitTestAreas(['Head'], x, y));
 * // on cleanup:
 * adapter.dispose();
 * ```
 */
class L2DOpenFLInputAdapter implements IL2DInputAdapter
{
    var sprite:Sprite;

    var moveCb:(x:Float, y:Float) -> Void;
    var downCb:(x:Float, y:Float) -> Void;
    var upCb:(x:Float, y:Float) -> Void;

    public function new(sprite:Sprite)
    {
        this.sprite = sprite;
        sprite.addEventListener(MouseEvent.MOUSE_MOVE, handleMove);
        sprite.addEventListener(MouseEvent.MOUSE_DOWN, handleDown);
        sprite.addEventListener(MouseEvent.MOUSE_UP, handleUp);
    }

    public function bindMove(callback:(x:Float, y:Float) -> Void):Void
    {
        this.moveCb = callback;
    }

    public function bindDown(callback:(x:Float, y:Float) -> Void):Void
    {
        this.downCb = callback;
    }

    public function bindUp(callback:(x:Float, y:Float) -> Void):Void
    {
        this.upCb = callback;
    }

    public function dispose():Void
    {
        sprite.removeEventListener(MouseEvent.MOUSE_MOVE, handleMove);
        sprite.removeEventListener(MouseEvent.MOUSE_DOWN, handleDown);
        sprite.removeEventListener(MouseEvent.MOUSE_UP, handleUp);
        moveCb = null;
        downCb = null;
        upCb = null;
    }

    function handleMove(e:MouseEvent):Void
    {
        if (moveCb != null) moveCb(e.stageX, e.stageY);
    }

    function handleDown(e:MouseEvent):Void
    {
        if (downCb != null) downCb(e.stageX, e.stageY);
    }

    function handleUp(e:MouseEvent):Void
    {
        if (upCb != null) upCb(e.stageX, e.stageY);
    }
}

#end
