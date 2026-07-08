package live2d.cubism.ext;

/**
 * Input adapter abstraction.
 *
 * Bridges framework-specific input events (OpenFL `MouseEvent`, Flixel
 * `FlxG.mouse`, Heaps `hxd.Event`) into unified `(x, y)` screen coordinates
 * that can be fed to `L2DLookAt.setTarget` or `L2DEventDispatcher.hitTestAreas`.
 *
 * Community backends implement this interface so their input system can
 * plug into the extension layer. The three built-in backends ship with
 * ready-to-use implementations in `ext.openfl`, `ext.flixel`, and
 * `ext.heaps` packages.
 *
 * Usage:
 * ```haxe
 * var adapter = new L2DHeapsInputAdapter();
 * adapter.bindMove((x, y) -> lookAt.setTarget(x, y));
 * adapter.bindDown((x, y) -> dispatcher.hitTestAreas(['Head', 'Body'], x, y));
 * // dispose on cleanup:
 * adapter.dispose();
 * ```
 *
 * Note: Flixel's `L2DFlixelInputAdapter` is polling-based (not event-based)
 * and requires the user to call `adapter.update()` in their `FlxState.update`.
 */
interface IL2DInputAdapter
{
    /** Bind mouse/touch move callback. Pass null to clear. */
    function bindMove(callback:(x:Float, y:Float) -> Void):Void;

    /** Bind pointer down callback. Pass null to clear. */
    function bindDown(callback:(x:Float, y:Float) -> Void):Void;

    /** Bind pointer up callback. Pass null to clear. */
    function bindUp(callback:(x:Float, y:Float) -> Void):Void;

    /** Release all bindings and remove event listeners. */
    function dispose():Void;
}
