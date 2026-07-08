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
 * Usage:
 * ```haxe
 * var queue = new L2DMotionQueue(core, dispatcher);
 * queue.enableIdleRecovery("Idle", 3.0);
 * queue.onMotionFinished = (group, no, handle) -> trace('Done: $group#$no');
 *
 * // In update loop:
 * queue.update(dt);
 *
 * // Triggered by user input:
 * queue.enqueue("TapBody", 0, 3);  // Force: interrupt current
 * queue.enqueue("Talk", 2, 2);     // Normal: queue after current
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

    /** Currently playing motion, or null if none. */
    var current:{group:String, no:Int, priority:Int, handle:Int};

    /** Pending motions awaiting their turn. */
    var pending:Array<{group:String, no:Int, priority:Int}>;

    // Idle recovery state
    var idleRecoveryEnabled:Bool = false;
    var idleGroup:String = "Idle";
    var idleDelay:Float = 3.0;
    var idleTimer:Float = 0.0;

    /** Set these to receive callbacks. They fire in addition to any L2DEventDispatcher dispatch. */
    public dynamic function onMotionBegan(group:String, no:Int, handle:Int):Void {}
    public dynamic function onMotionFinished(group:String, no:Int, handle:Int):Void {}
    public dynamic function onQueueEmpty():Void {}

    public function new(core:L2DCore, ?dispatcher:L2DEventDispatcher)
    {
        this.core = core;
        this.dispatcher = dispatcher;
        this.pending = [];
    }

    /** Whether a motion is currently playing. */
    public var hasActiveMotion(get, never):Bool;
    inline function get_hasActiveMotion():Bool return current != null;

    /** Number of motions waiting in the queue (not counting current). */
    public var pendingCount(get, never):Int;
    inline function get_pendingCount():Int return pending.length;

    /**
     * Enqueue a motion.
     * - Priority 3 (Force): clear current + queue, start immediately.
     * - Priority 2 (Normal): if nothing playing, start immediately; else queue.
     * - Priority 1 (Idle): only enqueue if no current and queue is empty.
     *
     * Returns the C-side motion handle if started now, or `MotionHandle.Invalid`
     * if queued or rejected. Subscribe to `onMotionBegan` to receive the handle
     * when a queued motion actually starts.
     */
    public function enqueue(group:String, no:Int = 0, priority:Int = 2):MotionHandle
    {
        if (priority == 3)
        {
            clear();
        }

        if (priority == 1 && (current != null || pending.length > 0))
        {
            return MotionHandle.Invalid;
        }

        if (current == null)
        {
            var handle = core.startMotion(group, no, priority);
            if (handle < 0) return MotionHandle.Invalid;
            current = {group: group, no: no, priority: priority, handle: handle};
            fireBegan(group, no, handle);
            return handle;
        }
        else
        {
            pending.push({group: group, no: no, priority: priority});
            return MotionHandle.Invalid;
        }
    }

    /** Clear the queue and forget the current motion. Does NOT stop the C-side motion. */
    public function clear():Void
    {
        current = null;
        pending = [];
        idleTimer = 0;
    }

    /** Enable idle recovery: after `idleDelay` seconds of empty queue, play a random motion from `idleGroup`. */
    public function enableIdleRecovery(idleGroup:String = "Idle", idleDelay:Float = 3.0):Void
    {
        this.idleGroup = idleGroup;
        this.idleDelay = idleDelay;
        this.idleRecoveryEnabled = true;
    }

    public function disableIdleRecovery():Void
    {
        idleRecoveryEnabled = false;
    }

    /** Main loop update. Polls current motion completion and triggers idle recovery. */
    public function update(dt:Float):Void
    {
        if (current != null)
        {
            if (CubismAPI.isMotionFinished(core.model, current.handle))
            {
                var finished = current;
                current = null;
                fireFinished(finished.group, finished.no, finished.handle);

                if (pending.length > 0)
                {
                    var next = pending.shift();
                    var handle = core.startMotion(next.group, next.no, next.priority);
                    if (handle >= 0)
                    {
                        current = {group: next.group, no: next.no, priority: next.priority, handle: handle};
                        fireBegan(next.group, next.no, handle);
                    }
                    else
                    {
                        // Start failed; try next frame for remaining queue items.
                        idleTimer = 0;
                    }
                }
                else
                {
                    fireQueueEmpty();
                    idleTimer = 0;
                }
            }
        }
        else if (idleRecoveryEnabled)
        {
            idleTimer += dt;
            if (idleTimer >= idleDelay)
            {
                var handle = core.startIdleMotion();
                if (handle >= 0)
                {
                    current = {group: idleGroup, no: -1, priority: 1, handle: handle};
                    fireBegan(idleGroup, -1, handle);
                    if (dispatcher != null)
                        dispatcher.dispatch(IdleRecovery(idleGroup));
                }
                idleTimer = 0;
            }
        }
    }

    // ===== Internal =====

    function fireBegan(group:String, no:Int, handle:Int):Void
    {
        onMotionBegan(group, no, handle);
        if (dispatcher != null)
            dispatcher.dispatch(MotionBegan(group, no, handle));
    }

    function fireFinished(group:String, no:Int, handle:Int):Void
    {
        onMotionFinished(group, no, handle);
        if (dispatcher != null)
            dispatcher.dispatch(MotionFinished(group, no, handle));
    }

    function fireQueueEmpty():Void
    {
        onQueueEmpty();
        if (dispatcher != null)
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
