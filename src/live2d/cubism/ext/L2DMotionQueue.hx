package live2d.cubism.ext;

import live2d.cubism.L2DCore;
import live2d.cubism.core.CubismAPI;

/**
 * Motion priority queue with idle recovery and completion callbacks.
 *
 * Wraps `L2DCore.startMotion` + `CubismAPI.isMotionFinished` polling into a
 * stateful queue. Higher-priority motions interrupt lower; Force(3) clears
 * the entire queue. When the queue empties, optional idle recovery plays a
 * random motion from an "Idle" group after a configurable delay.
 *
 * **Multi-slot support (v1.1):** Named motion slots allow independent motion
 * playback on different body parts. For example, a "face" slot can play
 * expressions while a "body" slot plays animations — they don't interfere.
 * The "main" slot preserves full backward compatibility with v1.0.
 *
 * Usage:
 * ```haxe
 * var queue = new L2DMotionQueue(core, dispatcher);
 * queue.enableIdleRecovery("Idle", 3.0);
 * queue.onMotionFinished = (group, no, handle) -> trace('Done: $group#$no');
 *
 * // Main slot (backward-compatible):
 * queue.enqueue("TapBody", 0, 3);
 *
 * // Multi-slot:
 * queue.enqueueTo("face", "Expression_Body", 0, 2);
 * queue.enqueueTo("body", "Walk", 0, 2);
 *
 * // In update loop:
 * queue.update(dt);
 * ```
 *
 * Priority values (match Cubism SDK conventions):
 *   1 = Idle (only when queue empty)
 *   2 = Normal (queue)
 *   3 = Force (interrupt current)
 *
 * Note: do NOT call `core.startIdleMotion()` directly when idle recovery is
 * enabled — the queue manages idle motions itself.
 */
class L2DMotionQueue
{
    var core:L2DCore;
    var dispatcher:L2DEventDispatcher;

    // Legacy single-slot fields (delegate to "main" slot)
    var mainSlot:SlotState;

    /** Multi-slot storage. Keyed by slot name (e.g. "main", "face", "body"). */
    var slots:Map<String, SlotState>;

    /** Set these to receive callbacks. They fire in addition to any L2DEventDispatcher dispatch. */
    public dynamic function onMotionBegan(slot:String, group:String, no:Int, handle:Int):Void {}
    public dynamic function onMotionFinished(slot:String, group:String, no:Int, handle:Int):Void {}
    public dynamic function onQueueEmpty(slot:String):Void {}

    public function new(core:L2DCore, ?dispatcher:L2DEventDispatcher)
    {
        this.core = core;
        this.dispatcher = dispatcher;
        this.mainSlot = new SlotState("main");
        this.slots = new Map();
        this.slots.set("main", mainSlot);
    }

    // ===== Legacy API (delegates to "main" slot) =====

    /** Currently playing motion on the main slot, or null if none. */
    public var current(get, never):{group:String, no:Int, priority:Int, handle:Int};
    function get_current()
    {
        if (mainSlot.current == null) return null;
        return {group: mainSlot.current.group, no: mainSlot.current.no,
                priority: mainSlot.current.priority, handle: mainSlot.current.handle};
    }

    /** Whether a motion is currently playing on the main slot. */
    public var hasActiveMotion(get, never):Bool;
    inline function get_hasActiveMotion():Bool return !mainSlot.isIdle();

    /** Number of motions waiting in the main queue. */
    public var pendingCount(get, never):Int;
    inline function get_pendingCount():Int return mainSlot.pending.length;

    /**
     * Enqueue a motion on the main slot.
     * See `enqueueTo` for the full parameter description.
     */
    public function enqueue(group:String, no:Int = 0, priority:Int = 2):MotionHandle
    {
        return enqueueTo("main", group, no, priority);
    }

    /** Clear the main queue and forget the current motion. */
    public function clear():Void
    {
        mainSlot.reset();
    }

    /** Enable idle recovery on the main slot. */
    public function enableIdleRecovery(idleGroup:String = "Idle", idleDelay:Float = 3.0):Void
    {
        mainSlot.idleRecoveryEnabled = true;
        mainSlot.idleGroup = idleGroup;
        mainSlot.idleDelay = idleDelay;
        mainSlot.idleTimer = 0;
    }

    public function disableIdleRecovery():Void
    {
        mainSlot.idleRecoveryEnabled = false;
    }

    // ===== Multi-slot API (v1.1) =====

    /**
     * Get or create a named slot.
     * The "main" slot always exists. Any other name creates a new slot on first access.
     */
    public function getSlot(name:String):SlotInfo
    {
        if (!slots.exists(name))
        {
            var slot = new SlotState(name);
            slots.set(name, slot);
        }
        var s = slots.get(name);
        return {
            name: s.name,
            hasActive: !s.isIdle(),
            pendingCount: s.pending.length,
            currentGroup: (s.current != null) ? s.current.group : null
        };
    }

    /**
     * Enqueue a motion on a specific slot.
     *
     * @param slot     Slot name (e.g. "main", "face", "body"). Created if not exists.
     * @param group    Motion group name (from model3.json FileReferences.Motions).
     * @param no       Motion index within the group (0 = first).
     * @param priority 3=Force (interrupt), 2=Normal (queue), 1=Idle.
     * @return C-side motion handle if started immediately, or Invalid if queued.
     */
    public function enqueueTo(slot:String, group:String, no:Int = 0, priority:Int = 2):MotionHandle
    {
        var s = ensureSlot(slot);
        return s.enqueue(core, group, no, priority, function(group, no, handle) {
            fireBegan(slot, group, no, handle);
        });
    }

    /** Clear a specific slot's queue and current motion. */
    public function clearSlot(slot:String):Void
    {
        if (slots.exists(slot))
            slots.get(slot).reset();
    }

    /** Enable idle recovery on a specific slot. */
    public function enableSlotIdleRecovery(slot:String, idleGroup:String, idleDelay:Float = 3.0):Void
    {
        var s = ensureSlot(slot);
        s.idleRecoveryEnabled = true;
        s.idleGroup = idleGroup;
        s.idleDelay = idleDelay;
        s.idleTimer = 0;
    }

    /**
     * Enqueue a file-based motion (for VTuber models whose motions are .motion3.json files,
     * not named groups in model3.json).
     *
     * @param slot     Slot name (e.g. "main"). Created if not exists.
     * @param filePath Relative motion file path (e.g. "motions/wave.motion3.json").
     * @param priority 3=Force (interrupt), 2=Normal (queue).
     * @return C-side motion handle if started immediately, or Invalid if queued.
     */
    public function enqueueMotionFile(slot:String, filePath:String, priority:Int = 3):MotionHandle
    {
        var s = ensureSlot(slot);
        return s.enqueueFile(core, filePath, priority, function(group, no, handle) {
            fireBegan(slot, group, no, handle);
        });
    }

    /** Enable idle recovery on a specific slot using a file-based idle motion (VTuber models). */
    public function enableSlotIdleRecoveryFile(slot:String, idleFile:String, idleDelay:Float = 3.0):Void
    {
        var s = ensureSlot(slot);
        s.idleRecoveryEnabled = true;
        s.idleGroup = idleFile;
        s.idleFile = idleFile;
        s.idleDelay = idleDelay;
        s.idleTimer = 0;
    }

    /**
     * Immediately interrupt the current motion and start the idle animation.
     *
     * Instead of calling StopAllMotions (which abruptly cuts the old motion),
     * we let the Cubism SDK's native fadeout mechanism handle the transition:
     * StartMotion sets fadeout on the existing wave motion, which naturally
     * fades its parameters from the current target toward baseline over ~1s.
     *
     * To prevent the SaveParameters/LoadParameters feedback loop from
     * freezing old motion parameters (e.g. arm staying at wave position),
     * we call restoreParamSnapshot once to establish the baseline, then
     * applyRecoverySnapshot every frame until the fadeout completes (~1.5s).
     */
    public function forceIdleRecovery(slot:String):Void
    {
        var s = ensureSlot(slot);
        if (!s.idleRecoveryEnabled) return;

        // Fire finished for whatever's currently playing
        if (s.current != null)
            fireFinished(s.name, s.current.group, s.current.no, s.current.handle);

        // Save a copy of the baseline snapshot for per-frame recovery.
        // restoreParamSnapshot below will clear paramSnapshot, so we must
        // copy it first for applyRecoverySnapshot to use during recovery.
        if (s.paramSnapshot != null)
            s.forceRecoverySnapshot = s.paramSnapshot.copy();

        // Restore baseline parameters once (clears paramSnapshot).
        // This sets the model to its pre-motion baseline and persists
        // via SaveParameters so the next frame's LoadParameters gets it.
        s.restoreParamSnapshot(core);

        // Start idle natively with Force priority. The SDK's StartMotion
        // will call SetFadeout on the old wave motion, giving it a natural
        // ~1s fade-out. applyRecoverySnapshot (called in updateSlot every
        // frame during recovery) prevents the SaveParameters/LoadParameters
        // cycle from re-freezing the old motion's parameter values.
        var handle = (s.idleFile != null)
            ? core.startMotionFile(s.idleFile, 3)
            : core.startIdleMotion();

        if (handle >= 0)
        {
            s.current = {group: s.idleGroup, no: -1, priority: 1,
                         handle: handle, isFile: (s.idleFile != null), isIdleRecovery: true};
            fireBegan(s.name, s.idleGroup, -1, handle);
            if (dispatcher != null && s.name == "main")
                dispatcher.dispatch(IdleRecovery(s.idleGroup));
        }

        s.pending = [];
        s.idleTimer = 0;
        // Recovery timer: covers default 1.0s fadeout with 0.5s margin.
        s.forceRecoveryTimer = 1.5;
    }

    // ===== Main loop update =====

    /** Main loop update. Polls motion events and advances all slots. */
    public function update(dt:Float):Void
    {
        // Poll native motion UserData events (drains native queue → dispatches MotionUserData)
        if (dispatcher != null) dispatcher.pollMotionEvents();

        for (slot in slots)
        {
            updateSlot(slot, dt);
        }
    }

    function updateSlot(s:SlotState, dt:Float):Void
    {
        // During force idle recovery, reapply the baseline snapshot every frame
        // BEFORE native Update() runs. This breaks the SaveParameters/LoadParameters
        // feedback loop: without this, the old motion's fadeout writes parameter
        // values (e.g. arm=1.0 from wave), SaveParameters captures them, and
        // next frame's LoadParameters restores them — freezing the parameter.
        //
        // By resetting to baseline each frame here, LoadParameters always gets
        // baseline values, and the fadeout blend naturally converges toward
        // baseline as the old motion's fadeWeight decreases.
        if (s.forceRecoveryTimer > 0)
        {
            s.forceRecoveryTimer -= dt;
            s.applyRecoverySnapshot(core);
            if (s.forceRecoveryTimer <= 0)
                s.forceRecoverySnapshot = null; // recovery period ended, free snapshot
        }

        // Advance the natural fade-out (from finished motion params to baseline).
        // Runs BEFORE core.update() so idle's fade-in writes on top of our
        // interpolated values. Only params that actually changed are touched,
        // so idle-controlled params are left alone.
        if (s.naturalFadeOutTimer > 0)
            s.updateNaturalFadeOut(core, dt);

        if (s.current != null)
        {
            // Idle recovery motions (VTuber idle loops with "Loop": true):
            // never poll isMotionFinished — the native SDK may erroneously
            // report finished for looping file-based motions. Idle motions
            // loop forever until interrupted by a Force(3) enqueue / reset().
            if (s.current.isIdleRecovery) return;

            if (CubismAPI.isMotionFinished(core.model, s.current.handle))
            {
                var finished = s.current;
                s.current = null;
                fireFinished(s.name, finished.group, finished.no, finished.handle);

                if (s.pending.length > 0)
                {
                    var next = s.pending.shift();
                    s.saveParamSnapshot(core);
                    var handle = next.isFile
                        ? core.startMotionFile(next.group, next.priority)
                        : core.startMotion(next.group, next.no, next.priority);
                    if (handle >= 0)
                    {
                        s.current = {group: next.group, no: next.no, priority: next.priority,
                                     handle: handle, isFile: next.isFile, isIdleRecovery: false};
                        fireBegan(s.name, next.group, next.no, handle);
                    }
                    else
                    {
                        s.restoreParamSnapshot(core);
                        s.idleTimer = 0;
                    }
                }
                else
                {
                    fireQueueEmpty(s.name);
                    if (s.idleRecoveryEnabled)
                    {
                        // Natural completion: start idle immediately and begin
                        // interpolating wave-affected parameters toward baseline
                        // in parallel (see updateNaturalFadeOut in updateSlot).
                        // This avoids both the abrupt snap (old restoreParamSnapshot)
                        // and the frozen arm (skipping restore entirely).
                        s.startNaturalFadeOut(core);

                        var handle = (s.idleFile != null)
                            ? core.startMotionFile(s.idleFile, 1)
                            : core.startIdleMotion();
                        if (handle >= 0)
                        {
                            s.current = {group: s.idleGroup, no: -1, priority: 1, handle: handle,
                                         isFile: (s.idleFile != null), isIdleRecovery: true};
                            fireBegan(s.name, s.idleGroup, -1, handle);
                            if (dispatcher != null && s.name == "main")
                                dispatcher.dispatch(IdleRecovery(s.idleGroup));
                        }
                        s.idleTimer = 0;
                    }
                    else
                    {
                        s.restoreParamSnapshot(core);
                    }
                }
            }
        }
        else if (s.idleRecoveryEnabled)
        {
            s.idleTimer += dt;
            if (s.idleTimer >= s.idleDelay)
            {
                // Use file-based idle for VTuber models, group-based for standard
                var handle = (s.idleFile != null)
                    ? core.startMotionFile(s.idleFile, 1)
                    : core.startIdleMotion();
                if (handle >= 0)
                {
                    s.current = {group: s.idleGroup, no: -1, priority: 1, handle: handle,
                                 isFile: (s.idleFile != null), isIdleRecovery: true};
                    fireBegan(s.name, s.idleGroup, -1, handle);
                    if (dispatcher != null && s.name == "main")
                        dispatcher.dispatch(IdleRecovery(s.idleGroup));
                }
                s.idleTimer = 0;
            }
        }
    }

    // ===== Internal =====

    function ensureSlot(name:String):SlotState
    {
        if (!slots.exists(name))
        {
            var s = new SlotState(name);
            slots.set(name, s);
            return s;
        }
        return slots.get(name);
    }

    function fireBegan(slot:String, group:String, no:Int, handle:Int):Void
    {
        onMotionBegan(slot, group, no, handle);
        if (dispatcher != null && slot == "main")
            dispatcher.dispatch(MotionBegan(group, no, handle));
    }

    function fireFinished(slot:String, group:String, no:Int, handle:Int):Void
    {
        onMotionFinished(slot, group, no, handle);
        if (dispatcher != null && slot == "main")
            dispatcher.dispatch(MotionFinished(group, no, handle));
    }

    function fireQueueEmpty(slot:String):Void
    {
        onQueueEmpty(slot);
        if (dispatcher != null && slot == "main")
            dispatcher.dispatch(QueueEmpty);
    }
}

/**
 * Opaque motion handle. Wraps the C-side motion queue entry handle.
 * -1 (Invalid) means "queued but not started yet" or "rejected".
 */
abstract MotionHandle(Int) from Int to Int
{
    public static inline var Invalid:MotionHandle = -1;

    public inline function isValid():Bool return this >= 0;
}

/** Read-only info about a motion slot (returned by getSlot). */
typedef SlotInfo =
{
    var name:String;
    var hasActive:Bool;
    var pendingCount:Int;
    var currentGroup:Null<String>;
}

/** Internal state for a single motion slot. */
private class SlotState
{
    public var name:String;
    public var current:{group:String, no:Int, priority:Int, handle:Int, ?isFile:Bool, ?isIdleRecovery:Bool};
    public var pending:Array<{group:String, no:Int, priority:Int, ?isFile:Bool}>;

    public var idleRecoveryEnabled:Bool = false;
    public var idleGroup:String = "Idle";
    public var idleDelay:Float = 3.0;
    public var idleTimer:Float = 0.0;
    /** File path for file-based idle recovery (VTuber models). Uses startMotionFile instead of startRandomMotion. */
    public var idleFile:String = null;

    /** Parameter snapshot taken before a non-idle motion starts. Restored when the slot empties. */
    public var paramSnapshot:Array<Float> = null;

    /** Timer for force idle recovery fade-out period (seconds). When > 0, baseline
     *  parameters are reapplied each frame before native Update() to break the
     *  SaveParameters/LoadParameters feedback loop that would otherwise freeze
     *  old motion parameters (e.g. arm staying up after wave is interrupted). */
    public var forceRecoveryTimer:Float = 0;

    /** Baseline snapshot kept alive during force recovery. Used by applyRecoverySnapshot
     *  every frame until forceRecoveryTimer expires. */
    public var forceRecoverySnapshot:Array<Float> = null;

    /** Timer for natural-completion fade-out (seconds). When > 0, parameters
     *  that the finished motion modified are smoothly interpolated from their
     *  last-frame values toward the baseline snapshot, parallel to the idle
     *  motion's fade-in. Duration matches the SDK default FadeInTime (1.0s). */
    public var naturalFadeOutTimer:Float = 0;
    public var naturalFadeOutDuration:Float = 1.0;

    /** Parameter values captured when the non-idle motion finished naturally.
     *  Used as the interpolation start point for naturalFadeOut. */
    public var naturalFadeOutStart:Array<Float> = null;

    public function new(name:String)
    {
        this.name = name;
        this.pending = [];
    }

    public inline function isIdle():Bool return current == null && pending.length == 0;

    public function reset():Void
    {
        current = null;
        pending = [];
        idleTimer = 0;
        forceRecoveryTimer = 0;
        forceRecoverySnapshot = null;
        naturalFadeOutTimer = 0;
        naturalFadeOutStart = null;
        // Keep paramSnapshot — it preserves the pre-motion-chain baseline state.
        // It is only cleared by restoreParamSnapshot when the slot fully empties.
    }

    /** Save all current model parameter values as a snapshot for later restore.
     *  Does NOT overwrite if a snapshot already exists — the first snapshot
     *  in a motion chain (taken before the first non-idle motion) is the
     *  baseline to restore when the chain empties. */
    public function saveParamSnapshot(core:L2DCore):Void
    {
        if (paramSnapshot != null) return; // already have a baseline, don't overwrite
        var bridge = CubismAPI.getBridge();
        var count = bridge.getParameterCount(core.model);
        if (count <= 0) return;
        var snap = [];
        for (i in 0...count)
            snap.push(bridge.getParameterValue(core.model, i));
        paramSnapshot = snap;
    }

    /** Restore parameter values from a previously saved snapshot.
     *  Clears the snapshot after restoring (one-shot use). */
    public function restoreParamSnapshot(core:L2DCore):Void
    {
        if (paramSnapshot == null) return;
        var bridge = CubismAPI.getBridge();
        for (i in 0...paramSnapshot.length)
            bridge.setParameterValue(core.model, i, paramSnapshot[i], 1.0);
        paramSnapshot = null;
    }

    /** Apply the recovery snapshot to model parameters WITHOUT clearing it.
     *  Called every frame during force idle recovery to break the
     *  SaveParameters/LoadParameters feedback loop that would otherwise
     *  freeze old motion parameter values. */
    public function applyRecoverySnapshot(core:L2DCore):Void
    {
        if (forceRecoverySnapshot == null) return;
        var bridge = CubismAPI.getBridge();
        for (i in 0...forceRecoverySnapshot.length)
            bridge.setParameterValue(core.model, i, forceRecoverySnapshot[i], 1.0);
        // Do NOT clear — we need it every frame during recovery
    }

    /** Capture current parameter values as the start point for a natural
     *  fade-out animation. Called when a non-idle motion finishes naturally
     *  (rather than being force-interrupted). */
    public function startNaturalFadeOut(core:L2DCore):Void
    {
        var bridge = CubismAPI.getBridge();
        var count = bridge.getParameterCount(core.model);
        if (count <= 0) return;
        var start = [];
        for (i in 0...count)
            start.push(bridge.getParameterValue(core.model, i));
        naturalFadeOutStart = start;
        naturalFadeOutTimer = naturalFadeOutDuration;
    }

    /** Advance the natural fade-out by dt seconds. Interpolates parameters
     *  from their post-motion values toward the baseline snapshot, using
     *  sine easing for a smooth deceleration. Called every frame from
     *  updateSlot until naturalFadeOutTimer reaches 0. */
    public function updateNaturalFadeOut(core:L2DCore, dt:Float):Void
    {
        if (naturalFadeOutTimer <= 0 || naturalFadeOutStart == null || paramSnapshot == null)
            return;

        naturalFadeOutTimer -= dt;
        var t = 1.0 - naturalFadeOutTimer / naturalFadeOutDuration;
        if (t > 1.0) t = 1.0;
        var ease = Math.sin(t * Math.PI / 2);

        var bridge = CubismAPI.getBridge();
        var len = naturalFadeOutStart.length;
        if (paramSnapshot.length < len) len = paramSnapshot.length;

        if (naturalFadeOutTimer <= 0)
        {
            // Final frame: snap precisely to baseline and clean up
            for (i in 0...len)
                bridge.setParameterValue(core.model, i, paramSnapshot[i], 1.0);
            naturalFadeOutStart = null;
        }
        else
        {
            // Blend only params that actually changed, to avoid
            // unnecessary writes and let idle control its own params freely.
            for (i in 0...len)
            {
                var start = naturalFadeOutStart[i];
                var target = paramSnapshot[i];
                if (Math.abs(start - target) < 0.001) continue;
                var v = start + (target - start) * ease;
                bridge.setParameterValue(core.model, i, v, 1.0);
            }
        }
    }

    public function enqueue(core:L2DCore, group:String, no:Int, priority:Int,
                             onBegan:(String, Int, Int) -> Void):MotionHandle
    {
        if (priority == 3) reset();

        if (priority == 1 && current != null) return MotionHandle.Invalid;

        if (current == null)
        {
            if (priority > 1) saveParamSnapshot(core);
            var handle = core.startMotion(group, no, priority);
            if (handle < 0) return MotionHandle.Invalid;
            current = {group: group, no: no, priority: priority, handle: handle, isIdleRecovery: (priority == 1)};
            onBegan(group, no, handle);
            return handle;
        }
        else
        {
            pending.push({group: group, no: no, priority: priority});
            return MotionHandle.Invalid;
        }
    }

    /** Enqueue a file-based motion (VTuber models). Uses core.startMotionFile instead of core.startMotion. */
    public function enqueueFile(core:L2DCore, filePath:String, priority:Int,
                                 onBegan:(String, Int, Int) -> Void):MotionHandle
    {
        if (priority == 3) reset();

        if (current == null)
        {
            if (priority > 1) saveParamSnapshot(core);
            var handle = core.startMotionFile(filePath, priority);
            if (handle < 0) return MotionHandle.Invalid;
            current = {group: filePath, no: -1, priority: priority, handle: handle, isFile: true, isIdleRecovery: (priority == 1)};
            onBegan(filePath, -1, handle);
            return handle;
        }
        else
        {
            pending.push({group: filePath, no: -1, priority: priority, isFile: true});
            return MotionHandle.Invalid;
        }
    }
}
