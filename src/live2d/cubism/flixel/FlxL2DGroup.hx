package live2d.cubism.flixel;

#if flixel

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.group.FlxGroup;
import live2d.cubism.ext.L2DEventDispatcher;

/**
 * Multi-model aggregation group for Flixel with automatic mouse dispatch,
 * camera follow, and bounds-based collision helpers.
 *
 * Wraps `FlxGroup` and tracks `L2DFlixelComponent` instances. When
 * `autoMouseHitTest` / `autoMouseDrag` are enabled, the group polls
 * `FlxG.mouse` every frame and dispatches hit tests / drag updates to the
 * topmost component under the cursor.
 *
 * Hit areas are model-specific, so callers must register them per-component
 * via `setHitAreas(component, areas)`. Components without registered hit
 * areas still participate in drag picking (bounds-based) but are skipped
 * by `autoMouseHitTest`.
 *
 * Usage:
 * ```haxe
 * var group = new FlxL2DGroup(dispatcher);
 * var haru = L2DFlixelManager.create('assets/live2d/Haru/', 'Haru.model3.json');
 * group.add(haru);
 * group.setHitAreas(haru, ['Head', 'Body']);
 * add(group);
 * // in update: group.update(elapsed);  // handled by FlxState automatically
 * ```
 */
class FlxL2DGroup extends FlxGroup
{
    /** Managed components (topmost = last). */
    public var components:Array<L2DFlixelComponent> = [];

    /** Shared event dispatcher for hit test / motion events. */
    public var dispatcher(default, null):L2DEventDispatcher;

    /** When true, `justPressed` triggers `dispatcher.hitTestAreas` on the topmost component with registered hit areas. */
    public var autoMouseHitTest:Bool = true;
    /** When true, holding the mouse drags the topmost bounds-hit component via `core.setDragging`. */
    public var autoMouseDrag:Bool = true;

    var dragTarget:L2DFlixelComponent = null;
    var hitAreasMap:Map<L2DFlixelComponent, Array<String>> = new Map();

    /** Optional camera that follows `followTarget`. */
    public var followCamera:FlxCamera = null;
    public var followTarget:L2DFlixelComponent = null;
    public var followLerp:Float = 0.1;

    public function new(?dispatcher:L2DEventDispatcher)
    {
        super();
        this.dispatcher = dispatcher != null ? dispatcher : new L2DEventDispatcher(null);
    }

    /** Add a component to the group. Returns the component for chaining. */
    public function add(component:L2DFlixelComponent):L2DFlixelComponent
    {
        components.push(component);
        super.add(component);
        return component;
    }

    /** Remove a component from the group and forget its hit areas. */
    public function remove(component:L2DFlixelComponent):L2DFlixelComponent
    {
        components.remove(component);
        hitAreasMap.remove(component);
        if (dragTarget == component) dragTarget = null;
        super.remove(component);
        return component;
    }

    /** Register hit area names for a component (enables `autoMouseHitTest` for it). */
    public function setHitAreas(component:L2DFlixelComponent, areas:Array<String>):Void
    {
        hitAreasMap.set(component, areas);
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (autoMouseHitTest) handleMouseHitTest();
        if (autoMouseDrag) handleMouseDrag();
        if (followCamera != null && followTarget != null) updateCameraFollow(elapsed);
    }

    function handleMouseHitTest():Void
    {
        if (!FlxG.mouse.justPressed) return;
        var mx = FlxG.mouse.x;
        var my = FlxG.mouse.y;
        // Topmost first (last in array = rendered on top)
        var i = components.length - 1;
        while (i >= 0)
        {
            var c = components[i];
            if (c.core != null && c.core.model.notNull())
            {
                var areas = hitAreasMap.get(c);
                if (areas != null && areas.length > 0)
                {
                    if (dispatcher.hitTestAreas(areas, mx, my)) return;
                }
            }
            i--;
        }
    }

    function handleMouseDrag():Void
    {
        var mouse = FlxG.mouse;
        if (mouse.justPressed)
        {
            dragTarget = hitTestPoint(mouse.x, mouse.y);
        }
        if (dragTarget != null)
        {
            if (mouse.pressed)
            {
                dragTarget.core.setDragging(mouse.x, mouse.y);
            }
            else
            {
                dragTarget = null;
            }
        }
    }

    function isPointInComponent(c:L2DFlixelComponent, x:Float, y:Float):Bool
    {
        var cx = c.core.x;
        var cy = c.core.y;
        var w = c.core.modelWidth * c.core.scale;
        var h = c.core.modelHeight * c.core.scale;
        return x >= cx - w / 2 && x <= cx + w / 2 && y >= cy - h / 2 && y <= cy + h / 2;
    }

    function updateCameraFollow(elapsed:Float):Void
    {
        if (followTarget == null || followCamera == null) return;
        var tx = followTarget.core.x;
        var ty = followTarget.core.y;
        followCamera.scroll.x = FlxMath.lerp(followCamera.scroll.x, tx - followCamera.width / 2, followLerp);
        followCamera.scroll.y = FlxMath.lerp(followCamera.scroll.y, ty - followCamera.height / 2, followLerp);
    }

    /** Get the screen-space AABB of a component (for FlxCollision integration). */
    public function getComponentBounds(c:L2DFlixelComponent):FlxRect
    {
        var w = c.core.modelWidth * c.core.scale;
        var h = c.core.modelHeight * c.core.scale;
        return FlxRect.get(c.core.x - w / 2, c.core.y - h / 2, w, h);
    }

    /** Find the topmost component whose bounds contain the point. Returns null if none. */
    public function hitTestPoint(x:Float, y:Float):L2DFlixelComponent
    {
        var i = components.length - 1;
        while (i >= 0)
        {
            var c = components[i];
            if (c.core != null && c.core.model.notNull() && isPointInComponent(c, x, y))
            {
                return c;
            }
            i--;
        }
        return null;
    }
}

#end
