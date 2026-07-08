package;

#if heaps

import h2d.Text;
import hxd.App;
import hxd.Key;
import hxd.Window;
import hxd.res.DefaultFont;
import live2d.cubism.ext.L2DEventDispatcher;
import live2d.cubism.ext.L2DLookAt;
import live2d.cubism.ext.L2DMotionQueue;
import live2d.cubism.ext.L2DParts;
import live2d.cubism.ext.heaps.L2DHeapsInputAdapter;
import live2d.cubism.heaps.L2DHeapsObject;

// Compile-time model constants — sub-types of the ModelConstants module.
import ModelConstants.HaruModelConstants;
import ModelConstants.HiyoriModelConstants;
import ModelConstants.MaoModelConstants;
import ModelConstants.MarkModelConstants;
import ModelConstants.NatoriModelConstants;
import ModelConstants.RiceModelConstants;

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
 *   T: toggle first part opacity (L2DParts chain DSL demo)
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

    var dispatcher:L2DEventDispatcher;
    var motionQueue:L2DMotionQueue;
    var lookAt:L2DLookAt;
    /** Parts manager (L2DParts chain DSL + tween). */
    var parts:L2DParts;

    /** Event-based mouse input adapter (demonstrates IL2DInputAdapter). */
    var input:L2DHeapsInputAdapter;
    /** Whether the left mouse button is currently held (tracked from adapter events). */
    var mouseDown:Bool = false;
    /** Whether Ctrl was held when the current press began (distinguishes drag vs. follow). */
    var mouseDownCtrl:Bool = false;
    /** Last mouse position from adapter (stage coords), consumed in update(). */
    var lastMouseX:Float = 0;
    var lastMouseY:Float = 0;

    /** Hit area names for the current model (from compile-time constants). */
    var currentHitAreas:Array<String> = [];
    /** TapBody motion group name for the current model, or null if the model has none. */
    var currentTapBodyGroup:String = null;

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
        infoText.text = 'Live2D Haxe - Heaps Demo v0.9\n'
            + 'Click: Hit test + motion\n'
            + 'Hold mouse: Eye tracking\n'
            + 'Ctrl + drag: Move model\n'
            + 'Wheel: Scale (Shift=fast)\n'
            + 'E: Expression | M: Motion\n'
            + 'B: Breath | P: Physics | L: LipSync\n'
            + 'T: Toggle first part (L2DParts)\n'
            + 'LEFT/RIGHT: Switch model\n'
            + 'Extensions: MotionQueue + LookAt + EventDispatcher + InputAdapter + Parts + UserData';

        statusText = new Text(font, s2d);
        statusText.textColor = 0xFFCCCCCC;
        statusText.x = 8;
        statusText.y = 160;

        // Event-based mouse input via IL2DInputAdapter (Heaps implementation).
        // Keyboard input still uses hxd.Key polling — the adapter only normalizes
        // pointer events, demonstrating how to decouple input collection from
        // L2D logic (the same callbacks could feed L2DLookAt/L2DEventDispatcher
        // on any backend by swapping the adapter implementation).
        input = new L2DHeapsInputAdapter();
        input.bindDown((x, y) -> {
            mouseDown = true;
            mouseDownCtrl = Key.isDown(Key.CTRL);
            lastMouseX = x;
            lastMouseY = y;
            if (l2d == null || !l2d.model.notNull()) return;
            if (mouseDownCtrl)
            {
                // Begin dragging
                dragging = true;
                dragOffsetX = l2d.core.x - x;
                dragOffsetY = l2d.core.y - y;
            }
            else
            {
                // Click (no Ctrl): hit test via dispatcher, enqueue TapBody on hit
                if (currentHitAreas.length > 0 && dispatcher.hitTestAreas(currentHitAreas, x, y))
                {
                    if (currentTapBodyGroup != null) motionQueue.enqueue(currentTapBodyGroup, 0, 3);
                }
            }
        });
        input.bindUp((x, y) -> {
            mouseDown = false;
            dragging = false;
        });
        input.bindMove((x, y) -> {
            lastMouseX = x;
            lastMouseY = y;
        });

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
            l2d.core.startIdleMotion();

            // Recreate extensions bound to the new core
            dispatcher = new L2DEventDispatcher(l2d.core);
            motionQueue = new L2DMotionQueue(l2d.core, dispatcher);
            // Note: native Update() already auto-plays random Idle when motion queue
            // is empty, so we do NOT call motionQueue.enableIdleRecovery() here —
            // enabling it would race with the native auto-idle and produce
            // "can't start motion" warnings. motionQueue is used only for
            // sequencing user-triggered motions (e.g. TapBody).
            lookAt = new L2DLookAt(l2d.core);
            parts = new L2DParts(l2d.core);

            dispatcher.onMotionFinished((group, no, handle) -> {
                trace('[HeapsDemo] Motion finished: $group#$no');
            });
            dispatcher.onHitTest((area, x, y) -> {
                trace('[HeapsDemo] Hit: $area @ ($x, $y)');
            });

            // Motion UserData events: fired when a motion timeline emits a
            // UserData string (e.g. voice/sound trigger). Both subscription
            // channels are shown:
            //   - dynamic `onMotionUserDataEvent` callback (set once)
            //   - typed `onMotionUserData` subscription (token-based)
            dispatcher.onMotionUserDataEvent = (value) -> {
                trace('[HeapsDemo] UserData (dynamic): $value');
            };
            dispatcher.onMotionUserData((value) -> {
                trace('[HeapsDemo] UserData (typed): $value');
            });

            // Print all part names once on load (L2DParts introspection demo)
            if (parts.count > 0)
            {
                var names = [for (i in 0...parts.count) parts.at(i).name];
                trace('[HeapsDemo] Parts (${parts.count}): ${names.join(", ")}');
            }

            // Select compile-time constants for the current model.
            // Each *ModelConstants class is @:build-generated from the model's
            // model3.json, so field names are checked at compile time.
            switch (modelName)
            {
                case 'Haru':
                    currentHitAreas = [HaruModelConstants.HitAreas.Head, HaruModelConstants.HitAreas.Body];
                    currentTapBodyGroup = HaruModelConstants.Motions.TapBody;
                case 'Hiyori':
                    currentHitAreas = [HiyoriModelConstants.HitAreas.Body];
                    currentTapBodyGroup = HiyoriModelConstants.Motions.TapBody;
                case 'Mao':
                    currentHitAreas = [MaoModelConstants.HitAreas.Head, MaoModelConstants.HitAreas.Body];
                    currentTapBodyGroup = MaoModelConstants.Motions.TapBody;
                case 'Mark':
                    currentHitAreas = [];
                    currentTapBodyGroup = null;
                case 'Natori':
                    currentHitAreas = [NatoriModelConstants.HitAreas.Head, NatoriModelConstants.HitAreas.Body];
                    currentTapBodyGroup = NatoriModelConstants.Motions.TapBody;
                case 'Rice':
                    currentHitAreas = [RiceModelConstants.HitAreas.Body];
                    currentTapBodyGroup = RiceModelConstants.Motions.TapBody;
                default:
                    currentHitAreas = [];
                    currentTapBodyGroup = null;
            }

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

        var mx = lastMouseX;
        var my = lastMouseY;

        // Dragging: when a Ctrl+press began a drag, follow the mouse position
        // (lastMouseX/Y are kept current by the adapter's bindMove callback).
        if (dragging)
        {
            l2d.core.x = dragOffsetX + mx;
            l2d.core.y = dragOffsetY + my;
        }

        // Eye tracking: when left button held without Ctrl, follow mouse; else release to home.
        // (mouseDown/mouseDownCtrl are tracked from the adapter's bindDown/bindUp events.)
        if (mouseDown && !mouseDownCtrl)
        {
            lookAt.setTarget(mx, my);
        }
        else
        {
            lookAt.release();
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
            l2d.core.setRandomExpression();
            updateStatus('Expression: random');
        }
        if (Key.isPressed(Key.M))
        {
            if (currentTapBodyGroup != null)
            {
                motionQueue.enqueue(currentTapBodyGroup, 0, 3);
            }
        }
        if (Key.isPressed(Key.B))
        {
            l2d.core.setBreathEnabled(!l2d.core.breathEnabled);
            updateStatus('Breath: ${l2d.core.breathEnabled}');
        }
        if (Key.isPressed(Key.P))
        {
            l2d.core.setPhysicsEnabled(!l2d.core.physicsEnabled);
            updateStatus('Physics: ${l2d.core.physicsEnabled}');
        }
        if (Key.isPressed(Key.L))
        {
            l2d.core.setLipSyncEnabled(!l2d.core.lipSyncEnabled);
            updateStatus('LipSync: ${l2d.core.lipSyncEnabled}');
        }
        if (Key.isPressed(Key.T))
        {
            // L2DParts chain DSL demo: toggle first part with a short tween.
            if (parts != null && parts.count > 0)
            {
                var p = parts.at(0);
                parts.tween(p.name, p.get() > 0.5 ? 0.0 : 1.0, 0.3);
                updateStatus('Part "${p.name}" → ${p.get() > 0.5 ? "hide" : "show"}');
            }
        }

        // Update extensions (order: motionQueue polls completion + UserData events → lookAt writes setDragging → parts tween)
        if (motionQueue != null) motionQueue.update(dt);
        if (lookAt != null) lookAt.update(dt);
        if (parts != null) parts.update(dt);
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

