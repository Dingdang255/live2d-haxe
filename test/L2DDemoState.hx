package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import live2d.cubism.flixel.L2DFlixelComponent;
import live2d.cubism.flixel.L2DFlixelManager;
import live2d.cubism.L2DCore;
import live2d.cubism.ext.L2DCallbackAudioSource;
import live2d.cubism.ext.L2DEventDispatcher;
import live2d.cubism.ext.L2DLipSync;
import live2d.cubism.ext.L2DLookAt;
import live2d.cubism.ext.L2DMotionQueue;
import live2d.cubism.ext.L2DParts;

// Compile-time model constants — sub-types of the ModelConstants module.
import ModelConstants.HaruModelConstants;
import ModelConstants.HiyoriModelConstants;
import ModelConstants.MaoModelConstants;
import ModelConstants.MarkModelConstants;
import ModelConstants.NatoriModelConstants;
import ModelConstants.RiceModelConstants;

/**
 * Demo state showing Live2D Cubism usage with Flixel + v0.9 Extension Layer.
 *
 * Controls:
 *   - Click on model hit areas to trigger motions
 *   - Hold mouse (non-Ctrl): Eye tracking
 *   - Ctrl + drag: Move model position
 *   - Mouse wheel: Scale model (Shift for faster)
 *   - E: Random expression
 *   - M: Play motion
 *   B: Toggle breath
 *   P: Toggle physics
 *   T: Toggle first part opacity (L2DParts chain DSL demo)
 *   V: Toggle LipSync (synthesized amplitude demo)
 *   LEFT/RIGHT: Switch model
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

    var dispatcher:L2DEventDispatcher;
    var motionQueue:L2DMotionQueue;
    var lookAt:L2DLookAt;
    /** Parts manager (L2DParts chain DSL + tween). */
    var parts:L2DParts;

    /** LipSync controller (synthesized amplitude demo). */
    var lipSync:L2DLipSync;
    /** Callback audio source for LipSync demo (synthesized amplitude). */
    var audioSource:L2DCallbackAudioSource;

    /** Hit area names for the current model (from compile-time constants). */
    var currentHitAreas:Array<String> = [];
    /** TapBody motion group name for the current model, or null if the model has none. */
    var currentTapBodyGroup:String = null;

    override public function create()
    {
        super.create();
        FlxG.mouse.visible = true;
        dragOffset = FlxPoint.get();

        // Info text
        infoText = new FlxText(10, 10, FlxG.width - 20,
            'Live2D Haxe Demo v1.0\n'
            + 'Click: Hit test + motion\n'
            + 'Hold mouse: Eye tracking\n'
            + 'Ctrl + drag: Move model\n'
            + 'Wheel: Scale (Shift=fast)\n'
            + 'E: Expression | M: Motion\n'
            + 'B: Breath | P: Physics\n'
            + 'T: Toggle first part (L2DParts)\n'
            + 'V: LipSync (synth)\n'
            + 'LEFT/RIGHT: Switch model\n'
            + 'v1.0: LipSync AudioSource + GPU buffer reuse'
        );
        infoText.setFormat(null, 14, 0xFFFFFFFF);
        add(infoText);

        statusText = new FlxText(10, 220, FlxG.width - 20, '');
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
        // LipSync is bound to the old core — discard on model switch
        if (lipSync != null) { lipSync.disable(); lipSync = null; audioSource = null; }

        var modelName = modelList[index];
        l2d = L2DFlixelManager.create('assets/live2d/$modelName/', '$modelName.model3.json');

        if (l2d.model.notNull())
        {
            l2d.x = FlxG.width / 2;
            l2d.y = FlxG.height / 2;
            l2d.scale = (FlxG.height * 0.8) / l2d.modelHeight;

            FlxG.addChildBelowMouse(l2d.getSprite());
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
                trace('[FlixelDemo] Motion finished: $group#$no');
            });
            dispatcher.onHitTest((area, x, y) -> {
                trace('[FlixelDemo] Hit: $area @ ($x, $y)');
            });

            // Motion UserData events: fired when a motion timeline emits a
            // UserData string (e.g. voice/sound trigger). Both subscription
            // channels are shown:
            //   - dynamic `onMotionUserDataEvent` callback (set once)
            //   - typed `onMotionUserData` subscription (token-based)
            dispatcher.onMotionUserDataEvent = (value) -> {
                trace('[FlixelDemo] UserData (dynamic): $value');
            };
            dispatcher.onMotionUserData((value) -> {
                trace('[FlixelDemo] UserData (typed): $value');
            });

            // Print all part names once on load (L2DParts introspection demo)
            if (parts.count > 0)
            {
                var names = [for (i in 0...parts.count) parts.at(i).name];
                trace('[FlixelDemo] Parts (${parts.count}): ${names.join(", ")}');
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

        var mx = FlxG.mouse.x;
        var my = FlxG.mouse.y;
        var ctrlDown = FlxG.keys.pressed.CONTROL;

        // Ctrl + press: begin dragging model position
        if (FlxG.mouse.justPressed && ctrlDown)
        {
            dragging = true;
            dragOffset.set(l2d.x - mx, l2d.y - my);
        }
        if (dragging && FlxG.mouse.pressed)
        {
            l2d.x = dragOffset.x + mx;
            l2d.y = dragOffset.y + my;
        }
        if (FlxG.mouse.justReleased)
        {
            dragging = false;
        }

        // Eye tracking: when left button held without Ctrl, follow mouse; else release to home
        if (FlxG.mouse.pressed && !ctrlDown)
        {
            lookAt.setTarget(mx, my);
        }
        else
        {
            lookAt.release();
        }

        // Click (no Ctrl): hit test via dispatcher, enqueue TapBody on hit
        if (FlxG.mouse.justPressed && !ctrlDown)
        {
            if (currentHitAreas.length > 0 && dispatcher.hitTestAreas(currentHitAreas, mx, my))
            {
                if (currentTapBodyGroup != null)
                {
                    motionQueue.enqueue(currentTapBodyGroup, 0, 3);
                }
            }
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

        // Keyboard actions
        #if FLX_KEYBOARD
        if (FlxG.keys.justPressed.E)
        {
            l2d.core.setRandomExpression();
        }
        if (FlxG.keys.justPressed.M)
        {
            if (currentTapBodyGroup != null)
            {
                motionQueue.enqueue(currentTapBodyGroup, 0, 3);
            }
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
        if (FlxG.keys.justPressed.T)
        {
            // L2DParts chain DSL demo: toggle first part with a short tween.
            if (parts != null && parts.count > 0)
            {
                var p = parts.at(0);
                parts.tween(p.name, p.get() > 0.5 ? 0.0 : 1.0, 0.3);
                statusText.text = 'Part "${p.name}" → ${p.get() > 0.5 ? "hide" : "show"}';
            }
        }
        if (FlxG.keys.justPressed.V)
        {
            // LipSync demo with synthesized amplitude (no wav file needed).
            // To use real audio, replace with:
            //   var source = new L2DFlixelAudioSource("assets/audio/sample.wav");
            //   source.play();
            //   // then in update: source.update(elapsed); lipSync.update(elapsed);
            if (lipSync == null)
            {
                audioSource = new L2DCallbackAudioSource(() -> {
                    var t = haxe.Timer.stamp();
                    var amp = 0.3 + 0.3 * Math.sin(t * 8) + 0.1 * Math.sin(t * 23);
                    return amp < 0 ? 0 : (amp > 1 ? 1 : amp);
                });
                lipSync = new L2DLipSync(l2d.core, audioSource);
            }
            if (lipSync.enabled) lipSync.disable();
            else lipSync.enable();
            statusText.text = 'LipSync (synth): ${lipSync.enabled ? "ON" : "OFF"}';
        }
        #end

        // Update extensions BEFORE native update so setDragging/StartMotion land
        // before core.update(dt) reads them. Order: motionQueue polls completion
        // + UserData events → lookAt writes setDragging → parts tween → native update.
        if (motionQueue != null) motionQueue.update(elapsed);
        if (lookAt != null) lookAt.update(elapsed);
        if (parts != null) parts.update(elapsed);
        if (lipSync != null && lipSync.enabled) lipSync.update(elapsed);

        // Update and render
        L2DFlixelManager.updateAll(elapsed);
        L2DFlixelManager.renderAll();
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
