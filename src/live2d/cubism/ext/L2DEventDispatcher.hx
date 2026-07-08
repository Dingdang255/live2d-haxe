package live2d.cubism.ext;

import live2d.cubism.L2DCore;

/**
 * Haxe-side event dispatcher for the extension layer.
 *
 * Typed callback subscription (one method per event variant) + token-based
 * unsubscribe. Extensions (L2DMotionQueue, etc.) call `dispatch(event)` to
 * fan out to listeners.
 *
 * Usage:
 * ```haxe
 * var dispatcher = new L2DEventDispatcher(core);
 * var token = dispatcher.onMotionFinished((group, no, handle) -> {
 *     trace('Motion finished: $group#$no');
 * });
 * // ...later:
 * dispatcher.off(token);
 * ```
 *
 * For hit testing multiple areas at once, use `hitTestAreas(...)` which
 * dispatches `HitTest` on the first area that hits.
 */
class L2DEventDispatcher
{
    var core:L2DCore;

    var motionBeganCbs:Array<{token:Int, cb:(group:String, no:Int, handle:Int) -> Void}>;
    var motionFinishedCbs:Array<{token:Int, cb:(group:String, no:Int, handle:Int) -> Void}>;
    var motionUserDataCbs:Array<{token:Int, cb:(value:String) -> Void}>;
    var expressionSetCbs:Array<{token:Int, cb:(id:String) -> Void}>;
    var hitTestCbs:Array<{token:Int, cb:(areaName:String, screenX:Float, screenY:Float) -> Void}>;
    var idleRecoveryCbs:Array<{token:Int, cb:(group:String) -> Void}>;
    var queueEmptyCbs:Array<{token:Int, cb:() -> Void}>;

    var nextToken:Int = 0;

    public function new(core:L2DCore)
    {
        this.core = core;
        motionBeganCbs = [];
        motionFinishedCbs = [];
        motionUserDataCbs = [];
        expressionSetCbs = [];
        hitTestCbs = [];
        idleRecoveryCbs = [];
        queueEmptyCbs = [];
    }

    // ===== Subscription (typed per event variant) =====

    public function onMotionBegan(cb:(group:String, no:Int, handle:Int) -> Void):Int
    {
        var token = nextToken++;
        motionBeganCbs.push({token: token, cb: cb});
        return token;
    }

    public function onMotionFinished(cb:(group:String, no:Int, handle:Int) -> Void):Int
    {
        var token = nextToken++;
        motionFinishedCbs.push({token: token, cb: cb});
        return token;
    }

    public function onMotionUserData(cb:(value:String) -> Void):Int
    {
        var token = nextToken++;
        motionUserDataCbs.push({token: token, cb: cb});
        return token;
    }

    public function onExpressionSet(cb:(id:String) -> Void):Int
    {
        var token = nextToken++;
        expressionSetCbs.push({token: token, cb: cb});
        return token;
    }

    public function onHitTest(cb:(areaName:String, screenX:Float, screenY:Float) -> Void):Int
    {
        var token = nextToken++;
        hitTestCbs.push({token: token, cb: cb});
        return token;
    }

    public function onIdleRecovery(cb:(group:String) -> Void):Int
    {
        var token = nextToken++;
        idleRecoveryCbs.push({token: token, cb: cb});
        return token;
    }

    public function onQueueEmpty(cb:() -> Void):Int
    {
        var token = nextToken++;
        queueEmptyCbs.push({token: token, cb: cb});
        return token;
    }

    /** Cancel a previously registered listener by its token. */
    public function off(token:Int):Void
    {
        removeTokenAny(motionBeganCbs, token);
        removeTokenAny(motionFinishedCbs, token);
        removeTokenAny(motionUserDataCbs, token);
        removeTokenAny(expressionSetCbs, token);
        removeTokenAny(hitTestCbs, token);
        removeTokenAny(idleRecoveryCbs, token);
        removeTokenAny(queueEmptyCbs, token);
    }

    /** Remove all listeners (useful when re-initializing a scene). */
    public function clear():Void
    {
        motionBeganCbs = [];
        motionFinishedCbs = [];
        motionUserDataCbs = [];
        expressionSetCbs = [];
        hitTestCbs = [];
        idleRecoveryCbs = [];
        queueEmptyCbs = [];
    }

    // ===== Dispatch (called by extensions) =====

    public function dispatch(event:L2DEvent):Void
    {
        switch (event)
        {
            case MotionBegan(group, no, handle):
                for (l in motionBeganCbs) l.cb(group, no, handle);
            case MotionFinished(group, no, handle):
                for (l in motionFinishedCbs) l.cb(group, no, handle);
            case MotionUserData(value):
                for (l in motionUserDataCbs) l.cb(value);
            case ExpressionSet(id):
                for (l in expressionSetCbs) l.cb(id);
            case HitTest(areaName, screenX, screenY):
                for (l in hitTestCbs) l.cb(areaName, screenX, screenY);
            case IdleRecovery(group):
                for (l in idleRecoveryCbs) l.cb(group);
            case QueueEmpty:
                for (l in queueEmptyCbs) l.cb();
        }
    }

    // ===== Convenience: expression notification =====

    /** Dispatch `ExpressionSet(id)`. Call after `core.setExpression(id)`. */
    public function notifyExpressionSet(id:String):Void
    {
        dispatch(ExpressionSet(id));
    }

    // ===== Motion UserData event polling =====

    /** Optional direct callback (alternative to onMotionUserData subscription). */
    public dynamic function onMotionUserDataEvent(value:String):Void {}

    /**
     * Poll native motion UserData events and dispatch them.
     * Call every frame (e.g. from L2DMotionQueue.update) to drain the
     * native event queue. Each event fires both `onMotionUserDataEvent`
     * (dynamic callback) and `MotionUserData` (typed subscription).
     */
    public function pollMotionEvents():Void
    {
        if (core == null || core.model.isNull()) return;
        var buf = haxe.io.Bytes.alloc(4096);
        var count = core.pollMotionEvents(buf, buf.length);
        if (count <= 0) return;
        // Parse null-separated strings (double-null terminated)
        var pos = 0;
        while (pos < buf.length)
        {
            var end = pos;
            while (end < buf.length && buf.get(end) != 0) end++;
            if (end == pos) break; // empty string = end of list
            var value = buf.getString(pos, end - pos);
            onMotionUserDataEvent(value);
            dispatch(MotionUserData(value));
            pos = end + 1; // skip null terminator
        }
    }

    // ===== Convenience: hit test multiple areas =====

    /**
     * Hit test `areas` in order. Dispatches `HitTest` for the first area
     * that hits and returns true. Returns false if none hit.
     */
    public function hitTestAreas(areas:Array<String>, screenX:Float, screenY:Float):Bool
    {
        for (area in areas)
        {
            if (core.hitTest(area, screenX, screenY))
            {
                dispatch(HitTest(area, screenX, screenY));
                return true;
            }
        }
        return false;
    }

    // ===== Internal =====

    /** Removes the listener with the given token from `arr`, if present. */
    static function removeTokenAny(arr:Array<Dynamic>, token:Int):Void
    {
        var i = arr.length - 1;
        while (i >= 0)
        {
            if (arr[i].token == token)
            {
                arr.splice(i, 1);
                return;
            }
            i--;
        }
    }
}
