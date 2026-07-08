package live2d.cubism.ext.heaps;

#if heaps

import hxd.Event;
import hxd.Window;
import live2d.cubism.ext.IL2DInputAdapter;

/**
 * Heaps input adapter — event-based.
 *
 * Wraps `hxd.Window` event system and forwards mouse events as unified
 * `(x, y)` screen coordinates via callbacks. Coordinates are window-relative
 * (stage pixel coordinates), matching what `L2DHeapsObject` expects.
 *
 * Usage:
 * ```haxe
 * var adapter = new L2DHeapsInputAdapter();
 * adapter.bindMove((x, y) -> lookAt.setTarget(x, y));
 * adapter.bindDown((x, y) -> dispatcher.hitTestAreas(['Head'], x, y));
 * // on cleanup:
 * adapter.dispose();
 * ```
 */
class L2DHeapsInputAdapter implements IL2DInputAdapter
{
    var moveCb:(x:Float, y:Float) -> Void;
    var downCb:(x:Float, y:Float) -> Void;
    var upCb:(x:Float, y:Float) -> Void;

    var eventHandler:Event -> Void;

    public function new()
    {
        eventHandler = handleEvent;
        Window.getInstance().addEventTarget(eventHandler);
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

    public function dispose()
    {
        Window.getInstance().removeEventTarget(eventHandler);
        eventHandler = null;
        moveCb = null;
        downCb = null;
        upCb = null;
    }

    function handleEvent(e:Event):Void
    {
        switch (e.kind)
        {
            case EMove:
                if (moveCb != null) moveCb(e.relX, e.relY);
            case EPush:
                if (downCb != null) downCb(e.relX, e.relY);
            case ERelease, EReleaseOutside:
                if (upCb != null) upCb(e.relX, e.relY);
            default:
        }
    }
}

#end
