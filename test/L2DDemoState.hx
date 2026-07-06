package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import live2d.cubism.flixel.L2DFlixelComponent;
import live2d.cubism.flixel.L2DFlixelManager;
import live2d.cubism.L2DCore;

/**
 * Demo state showing basic Live2D Cubism usage with Flixel.
 *
 * Controls:
 *   - Click on model hit areas to trigger motions
 *   - Hold mouse (non-Ctrl): Eye tracking
 *   - Ctrl + drag: Move model position
 *   - Mouse wheel: Scale model (Shift for faster)
 *   - E: Random expression
 *   - M: Play motion
 *   - B: Toggle breath
 *   - P: Toggle physics
 *   - L: Toggle lip sync
 *   - LEFT/RIGHT: Switch model
 */
class L2DDemoState extends FlxState
{
    var modelList:Array<String> = ['Haru', 'Hiyori', 'Mao', 'Mark', 'Natori', 'Rice'];
    var currentModelIndex:Int = 0;

    var l2d:L2DFlixelComponent;
    var infoText:FlxText;
    var statusText:FlxText;
    var dragging:Bool = false;
    var dragOffset:FlxPoint;

    override public function create()
    {
        super.create();
        FlxG.mouse.visible = true;
        dragOffset = FlxPoint.get();

        // Info text
        infoText = new FlxText(10, 10, FlxG.width - 20,
            'Live2D Haxe Demo v0.5\n'
            + 'Click: Hit test + motion\n'
            + 'Hold mouse: Eye tracking\n'
            + 'Ctrl + drag: Move model\n'
            + 'Wheel: Scale (Shift=fast)\n'
            + 'E: Expression | M: Motion\n'
            + 'B: Breath | P: Physics | L: LipSync\n'
            + 'LEFT/RIGHT: Switch model'
        );
        infoText.setFormat(null, 14, 0xFFFFFFFF);
        add(infoText);

        statusText = new FlxText(10, 200, FlxG.width - 20, '');
        statusText.setFormat(null, 12, 0xFFCCCCCC);
        add(statusText);

        loadModel(currentModelIndex);
    }

    function loadModel(index:Int)
    {
        // Remove old model
        if (l2d != null)
        {
            FlxG.removeChild(l2d.getSprite());
            L2DFlixelManager.destroy(l2d);
            l2d = null;
        }

        var modelName = modelList[index];
        l2d = L2DFlixelManager.create('assets/live2d/$modelName/', '$modelName.model3.json');

        if (l2d.model.notNull())
        {
            l2d.x = FlxG.width / 2;
            l2d.y = FlxG.height / 2;
            l2d.scale = (FlxG.height * 0.8) / l2d.modelHeight;

            FlxG.addChildBelowMouse(l2d.getSprite());
            l2d.startIdleMotion();

            statusText.text = 'Model: $modelName | Scale: ${l2d.scale:.1f} | Bounds: ${l2d.modelWidth} x ${l2d.modelHeight}';
        }
        else
        {
            statusText.text = 'ERROR: Failed to load model $modelName';
        }
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        // Model switching
        if (FlxG.keys.justPressed.LEFT)
        {
            currentModelIndex--;
            if (currentModelIndex < 0) currentModelIndex = modelList.length - 1;
            loadModel(currentModelIndex);
        }
        if (FlxG.keys.justPressed.RIGHT)
        {
            currentModelIndex++;
            if (currentModelIndex >= modelList.length) currentModelIndex = 0;
            loadModel(currentModelIndex);
        }

        if (l2d == null || l2d.model.isNull()) return;

        // Eye tracking - set dragging BEFORE update so current frame responds
        if (FlxG.mouse.pressed && !FlxG.keys.pressed.CONTROL)
        {
            l2d.setDragging(FlxG.mouse.x, FlxG.mouse.y);
        }
        else
        {
            l2d.setDragging(l2d.x, l2d.y);
        }

        // Update and render
        L2DFlixelManager.updateAll(elapsed);
        L2DFlixelManager.renderAll();

        // Hit test on click
        if (FlxG.mouse.justPressed && !FlxG.keys.pressed.CONTROL)
        {
            var areas = ['Head', 'Body', 'Hair'];
            for (area in areas)
            {
                if (l2d.hitTest(area, FlxG.mouse.x, FlxG.mouse.y))
                {
                    trace('[Demo] Hit: $area');
                    l2d.startMotion('TapBody', 0, 3);
                    break;
                }
            }
        }

        // Ctrl + drag: move model position
        if (FlxG.mouse.justPressed && FlxG.keys.pressed.CONTROL)
        {
            dragging = true;
            dragOffset.set(l2d.x - FlxG.mouse.x, l2d.y - FlxG.mouse.y);
        }
        if (dragging && FlxG.mouse.pressed)
        {
            l2d.x = dragOffset.x + FlxG.mouse.x;
            l2d.y = dragOffset.y + FlxG.mouse.y;
        }
        if (FlxG.mouse.justReleased)
        {
            dragging = false;
        }

        // Mouse wheel: scale
        if (FlxG.mouse.wheel != 0)
        {
            var s = l2d.scale;
            s += FlxG.mouse.wheel * (6 * (FlxG.keys.pressed.SHIFT ? 3 : 1));
            if (s < (FlxG.height * 0.8) / l2d.modelHeight) s = (FlxG.height * 0.8) / l2d.modelHeight;
            l2d.scale = s;
            statusText.text = 'Model: ${modelList[currentModelIndex]} | Scale: ${l2d.scale:.1f}';
        }

        // Keyboard
        #if FLX_KEYBOARD
        if (FlxG.keys.justPressed.E)
        {
            l2d.setRandomExpression();
        }
        if (FlxG.keys.justPressed.M)
        {
            l2d.startMotion('TapBody', 0, 3);
        }
        // Framework behavior toggles
        if (FlxG.keys.justPressed.B)
        {
            l2d.core.setBreathEnabled(!l2d.core.breathEnabled);
            statusText.text = 'Breath: ${l2d.core.breathEnabled}';
        }
        if (FlxG.keys.justPressed.P)
        {
            l2d.core.setPhysicsEnabled(!l2d.core.physicsEnabled);
            statusText.text = 'Physics: ${l2d.core.physicsEnabled}';
        }
        if (FlxG.keys.justPressed.L)
        {
            l2d.core.setLipSyncEnabled(!l2d.core.lipSyncEnabled);
            statusText.text = 'LipSync: ${l2d.core.lipSyncEnabled}';
        }
        #end
    }

    override public function destroy()
    {
        if (l2d != null && l2d.getSprite() != null)
        {
            FlxG.removeChild(l2d.getSprite());
        }
        L2DFlixelManager.destroyAll();
        L2DFlixelManager.clearTextureCache();
        FlxG.mouse.visible = false;
        super.destroy();
    }
}
