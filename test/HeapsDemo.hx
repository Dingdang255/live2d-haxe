package;

#if heaps

import h2d.Text;
import hxd.App;
import hxd.Key;
import hxd.Window;
import hxd.res.DefaultFont;
import live2d.cubism.heaps.L2DHeapsObject;

/**
 * Heaps Demo for Live2D Cubism.
 *
 * Uses L2DHeapsObject for clean, framework-idiomatic integration.
 * The model auto-updates and renders in sync(ctx); this demo only
 * handles input and model switching.
 *
 * Controls:
 *   Click (no Ctrl): hit test + play TapBody motion
 *   Hold mouse (no Ctrl): eye tracking
 *   Ctrl + drag: move model
 *   Wheel: scale (Shift = faster)
 *   E: random expression
 *   M: play TapBody motion
 *   B / P / L: toggle Breath / Physics / LipSync
 *   LEFT / RIGHT: switch model
 */
class HeapsDemo extends App
{
    static var MODEL_LIST:Array<String> = ['Haru', 'Hiyori', 'Mao', 'Mark', 'Natori', 'Rice'];

    var l2d:L2DHeapsObject;
    var currentModelIndex:Int = 0;

    var infoText:Text;
    var statusText:Text;

    var dragging:Bool = false;
    var dragOffsetX:Float = 0;
    var dragOffsetY:Float = 0;

    static function main()
    {
        new HeapsDemo();
    }

    override function init()
    {
        engine.backgroundColor = 0xFF222222;
        Window.getInstance().title = 'Live2D Haxe - Heaps Demo';

        var font = DefaultFont.get();
        infoText = new Text(font, s2d);
        infoText.textColor = 0xFFFFFFFF;
        infoText.x = 8;
        infoText.y = 8;
        infoText.text = 'Live2D Haxe - Heaps Demo v0.7\n'
            + 'Click: Hit test + motion\n'
            + 'Hold mouse: Eye tracking\n'
            + 'Ctrl + drag: Move model\n'
            + 'Wheel: Scale (Shift=fast)\n'
            + 'E: Expression | M: Motion\n'
            + 'B: Breath | P: Physics | L: LipSync\n'
            + 'LEFT/RIGHT: Switch model';

        statusText = new Text(font, s2d);
        statusText.textColor = 0xFFCCCCCC;
        statusText.x = 8;
        statusText.y = 160;

        loadModel(currentModelIndex);
    }

    function loadModel(index:Int)
    {
        if (l2d != null)
        {
            l2d.remove();
            l2d = null;
        }

        var modelName = MODEL_LIST[index];
        l2d = new L2DHeapsObject(
            'assets/live2d/$modelName/',
            '$modelName.model3.json',
            s2d
        );

        if (l2d.model.notNull())
        {
            l2d.core.x = s2d.width / 2;
            l2d.core.y = s2d.height / 2;
            l2d.core.scale = (s2d.height * 0.8) / l2d.modelHeight;
            l2d.startIdleMotion();
            updateStatus('Model: $modelName | Scale: ${l2d.core.scale:.2f} | ${l2d.modelWidth}x${l2d.modelHeight}');
            trace('[HeapsDemo] Loaded $modelName: ${l2d.modelWidth}x${l2d.modelHeight}, scale=${l2d.core.scale}');
        }
        else
        {
            updateStatus('ERROR: Failed to load model $modelName');
            trace('[HeapsDemo] ERROR: Failed to load model $modelName');
        }
    }

    function updateStatus(msg:String)
    {
        statusText.text = msg;
    }

    override function update(dt:Float)
    {
        super.update(dt);

        if (Key.isPressed(Key.LEFT))
        {
            currentModelIndex--;
            if (currentModelIndex < 0) currentModelIndex = MODEL_LIST.length - 1;
            loadModel(currentModelIndex);
        }
        if (Key.isPressed(Key.RIGHT))
        {
            currentModelIndex++;
            if (currentModelIndex >= MODEL_LIST.length) currentModelIndex = 0;
            loadModel(currentModelIndex);
        }

        if (l2d == null || !l2d.model.notNull()) return;

        var mx = s2d.mouseX;
        var my = s2d.mouseY;
        var ctrlDown = Key.isDown(Key.CTRL);

        // Ctrl + press: begin dragging model position
        if (Key.isPressed(Key.MOUSE_LEFT) && ctrlDown)
        {
            dragging = true;
            dragOffsetX = l2d.core.x - mx;
            dragOffsetY = l2d.core.y - my;
        }
        if (dragging && Key.isDown(Key.MOUSE_LEFT))
        {
            l2d.core.x = dragOffsetX + mx;
            l2d.core.y = dragOffsetY + my;
        }
        if (!Key.isDown(Key.MOUSE_LEFT))
        {
            dragging = false;
        }

        // Eye tracking: when left button held without Ctrl, track mouse; else return to center
        if (Key.isDown(Key.MOUSE_LEFT) && !ctrlDown)
        {
            l2d.setDragging(mx, my);
        }
        else
        {
            l2d.setDragging(l2d.core.x, l2d.core.y);
        }

        // Click (no Ctrl): hit test
        if (Key.isPressed(Key.MOUSE_LEFT) && !ctrlDown)
        {
            var areas = ['Head', 'Body', 'Hair'];
            for (area in areas)
            {
                if (l2d.hitTest(area, mx, my))
                {
                    trace('[HeapsDemo] Hit: $area');
                    l2d.startMotion('TapBody', 0, 3);
                    break;
                }
            }
        }

        // Mouse wheel: scale (Key.MOUSE_WHEEL_UP = zoom out, DOWN = zoom in per Heaps convention)
        var wheelUp = Key.isPressed(Key.MOUSE_WHEEL_UP);
        var wheelDown = Key.isPressed(Key.MOUSE_WHEEL_DOWN);
        if (wheelUp || wheelDown)
        {
            var delta = wheelUp ? 1 : -1;
            var step = 12 * (Key.isDown(Key.SHIFT) ? 3 : 1);
            l2d.core.scale += delta * step;
            var minScale = (s2d.height * 0.3) / l2d.modelHeight;
            var maxScale = (s2d.height * 3.0) / l2d.modelHeight;
            if (l2d.core.scale < minScale) l2d.core.scale = minScale;
            if (l2d.core.scale > maxScale) l2d.core.scale = maxScale;
            updateStatus('Model: ${MODEL_LIST[currentModelIndex]} | Scale: ${l2d.core.scale:.2f}');
        }

        // Keyboard actions
        if (Key.isPressed(Key.E))
        {
            l2d.setRandomExpression();
            updateStatus('Expression: random');
        }
        if (Key.isPressed(Key.M))
        {
            l2d.startMotion('TapBody', 0, 3);
        }
        if (Key.isPressed(Key.B))
        {
            l2d.setBreathEnabled(!l2d.core.breathEnabled);
            updateStatus('Breath: ${l2d.core.breathEnabled}');
        }
        if (Key.isPressed(Key.P))
        {
            l2d.setPhysicsEnabled(!l2d.core.physicsEnabled);
            updateStatus('Physics: ${l2d.core.physicsEnabled}');
        }
        if (Key.isPressed(Key.L))
        {
            l2d.setLipSyncEnabled(!l2d.core.lipSyncEnabled);
            updateStatus('LipSync: ${l2d.core.lipSyncEnabled}');
        }
    }

    override function onResize()
    {
        super.onResize();
        if (l2d != null && l2d.model.notNull())
        {
            l2d.core.x = s2d.width / 2;
            l2d.core.y = s2d.height / 2;
        }
    }
}

#end
