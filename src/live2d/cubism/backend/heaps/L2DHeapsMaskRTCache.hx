package live2d.cubism.backend.heaps;

#if heaps

import h3d.mat.Texture;

/**
 * Pool for reusable mask render-target textures, keyed by (width × height).
 *
 * Each `L2DHeapsObject` needs its own mask RT instance (concurrent models
 * cannot share a single RT — model B's sync phase would overwrite model A's
 * masks before A's draw phase samples them). However, when a model is
 * destroyed and later a new model of the same mask RT size is created, the
 * old RT can be reused from the pool instead of allocating a new GPU texture.
 *
 * This avoids alloc/dispose churn during model swaps (e.g. cycling through
 * the 6 demo models in HeapsDemo) while keeping each concurrent model's
 * mask RT independent.
 *
 * Thread safety: Heaps/HL is single-threaded — no locking needed.
 */
class L2DHeapsMaskRTCache
{
    /** Freed RTs keyed by "WxH", ready for reuse. */
    static var pool:Map<String, Array<Texture>> = new Map();

    static function key(w:Int, h:Int):String
    {
        return w + "x" + h;
    }

    /**
     * Check out a mask RT of the given size. Reuses a freed RT from the
     * pool if available; otherwise allocates a new GPU texture.
     */
    static public function get(w:Int, h:Int):Texture
    {
        var k = key(w, h);
        var arr = pool.get(k);
        if (arr != null && arr.length > 0)
        {
            var rt = arr.pop();
            if (arr.length == 0) pool.remove(k);
            return rt;
        }
        return new Texture(w, h, [Target]);
    }

    /**
     * Return a mask RT to the pool for future reuse. Does NOT dispose —
     * the GPU texture stays allocated until `disposeAll()` is called.
     * Call this instead of `rt.dispose()` when a renderer is destroyed.
     */
    static public function release(rt:Texture, w:Int, h:Int):Void
    {
        if (rt == null || rt.isDisposed()) return;
        var k = key(w, h);
        var arr = pool.get(k);
        if (arr == null)
        {
            arr = [];
            pool.set(k, arr);
        }
        arr.push(rt);
    }

    /**
     * Dispose all pooled RTs. Call on application shutdown or GPU context loss.
     */
    static public function disposeAll():Void
    {
        for (arr in pool)
        {
            for (rt in arr)
            {
                if (rt != null && !rt.isDisposed()) rt.dispose();
            }
        }
        pool = new Map();
    }
}

#end
