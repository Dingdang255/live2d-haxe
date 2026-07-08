package live2d.cubism.ext.flixel;

#if flixel

import flixel.FlxG;
import live2d.cubism.ext.IL2DInputAdapter;

/**
 * Flixel input adapter — polling-based.
 *
 * Flixel uses polling (`FlxG.mouse.pressed`, `justPressed`, `justReleased`)
 * rather than event listeners. This adapter stores callbacks and checks
 * mouse state in `update()`, which the user must call from their
 * `FlxState.update(elapsed)`.
 *
 * Usage:
 * ```haxe
 * var adapter = new L2DFlixelInputAdapter();
 * adapter.bindMove((x, y) -> lookAt.setTarget(x, y));
 * adapter.bindDown((x, y) -> dispatcher.hitTestAreas(['Head'], x, y));
 *
 * override function update(elapsed:Float) {
 *     super.update(elapsed);
 *     adapter.update();  // poll FlxG.mouse
 * }
 * ```
 */
class L2DFlixelInputAdapter implements IL2DInputAdapter
{
    var moveCb:(x:Float, y:Float) -> Void;
    var downCb:(x:Float, y:Float) -> Void;
    var upCb:(x:Float, y:Float) -> Void;

    public function new() {}

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
        moveCb = null;
        downCb = null;
        upCb = null;
    }

    /**
     * Poll `FlxG.mouse` and fire callbacks. Call this from `FlxState.update`.
     * - `bindMove` fires when the mouse button is held (following the
     *   "hold to track" pattern used in the existing Flixel demo).
     * - `bindDown` fires on the frame the button is pressed.
     * - `bindUp` fires on the frame the button is released.
     */
    public function update():Void
    {
        if (FlxG.mouse.pressed && moveCb != null)
        {
            moveCb(FlxG.mouse.x, FlxG.mouse.y);
        }
        if (FlxG.mouse.justPressed && downCb != null)
        {
            downCb(FlxG.mouse.x, FlxG.mouse.y);
        }
        if (FlxG.mouse.justReleased && upCb != null)
        {
            upCb(FlxG.mouse.x, FlxG.mouse.y);
        }
    }
}

#end
