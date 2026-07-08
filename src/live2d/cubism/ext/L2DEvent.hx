package live2d.cubism.ext;

/**
 * Events dispatched by the extension layer.
 *
 * `MotionBegan`/`MotionFinished`/`IdleRecovery`/`QueueEmpty` are produced
 * by `L2DMotionQueue`. `ExpressionSet` is dispatched when the user calls
 * `L2DEventDispatcher.notifyExpressionSet(id)`. `HitTest` is dispatched by
 * `L2DEventDispatcher.hitTestAreas(...)` on a successful hit.
 * `MotionUserData` is fired when a playing motion's timeline emits a
 * UserData event (voice/sound triggers embedded in `.motion3.json`),
 * polled from native via `L2DEventDispatcher.pollMotionEvents()`.
 */
enum L2DEvent
{
    /** A motion started playing. */
    MotionBegan(group:String, no:Int, handle:Int);
    /** A motion finished playing. */
    MotionFinished(group:String, no:Int, handle:Int);
    /** A motion timeline UserData event fired (e.g. voice/sound trigger). */
    MotionUserData(value:String);
    /** An expression was applied. */
    ExpressionSet(id:String);
    /** A hit area was clicked/tapped. */
    HitTest(areaName:String, screenX:Float, screenY:Float);
    /** Idle recovery kicked in after the queue was empty for a while. */
    IdleRecovery(group:String);
    /** The motion queue became empty (no active or pending motion). */
    QueueEmpty;
}
