package live2d.cubism.backend.heaps;

#if heaps

import h2d.Drawable;
import h2d.RenderContext;
import h3d.Engine;
import h3d.Buffer;
import h3d.Indexes;
import h3d.prim.Primitive;
import h3d.mat.Texture;
import hxd.FloatBuffer;
import hxd.IndexBuffer;

/**
 * Heaps 2D drawable for Live2D mesh rendering.
 *
 * Wraps a single h3d.prim.Primitive (triangle list with 8-float vertices:
 * x, y, u, v, r, g, b, a) and renders it via h2d.RenderContext.beginDrawObject.
 *
 * Each instance carries its own CubismHeapsShader; uniforms are updated by
 * HeapsRenderer before each draw call. When the shader's toggles are all
 * disabled (useMask=0, useColor=0, opacity=1), it behaves as a passthrough
 * and only Base2d's texture sampling applies — matching the semantics of
 * IL2DRenderer.drawTexturedTriangles.
 *
 * Vertex buffer uses a grow-only Dynamic buffer: GPU buffers are reused across
 * frames and reallocated only when capacity is insufficient. uploadVector
 * uploads in place, avoiding per-frame dispose+realloc overhead.
 */
class L2DMeshDrawable extends Drawable
{
    /** Underlying primitive holding vertex/index buffers. */
    public var primitive(default, null):MeshPrimitive;

    /** Diffuse texture set by HeapsRenderer before draw. */
    public var texture:Texture;

    var cubismShader:CubismHeapsShader;

    public function new(?parent:h2d.Object)
    {
        super(parent);
        primitive = new MeshPrimitive();
        cubismShader = new CubismHeapsShader();
        addShader(cubismShader);
        // Vertex color white; alpha handled by CubismHeapsShader.u_opacity
        color.set(1, 1, 1, 1);
    }

    /** Access the per-instance CubismHeapsShader for uniform updates. */
    public function getCubismShader():CubismHeapsShader
    {
        return cubismShader;
    }

    /** Update geometry with new vertex/uv/index data. Vertices are flat [x0,y0,x1,y1,...]. */
    public function updateMesh(vertices:Array<Float>, uvs:Array<Float>, indices:Array<Int>):Void
    {
        primitive.updateData(vertices, uvs, indices);
    }

    /** Reset shader uniforms to passthrough defaults (no mask, no color, full opacity). */
    public function resetShaderUniforms():Void
    {
        cubismShader.u_useMask = 0;
        cubismShader.u_useColor = 0;
        cubismShader.u_opacity = 1;
        cubismShader.u_isInverted = 0;
        cubismShader.u_convertPremul = 1;
        cubismShader.u_channelFlag.set(1, 0, 0, 0);
        cubismShader.u_maskOffset.set(0, 0);
        cubismShader.u_maskScale.set(1, 1);
        cubismShader.u_mulColor.set(1, 1, 1);
        cubismShader.u_scrColor.set(0, 0, 0);
    }

    override function draw(ctx:RenderContext):Void
    {
        if (texture == null) return;
        if (!ctx.beginDrawObject(this, texture)) return;
        primitive.render(ctx.engine);
    }

    override function sync(ctx:RenderContext):Void
    {
        super.sync(ctx);
        primitive.flush();
    }

    override function onRemove():Void
    {
        super.onRemove();
        primitive.dispose();
    }
}

/**
 * Simple Primitive that holds one triangle list with 8-float stride
 * (x, y, u, v, r, g, b, a) and RawFormat.
 *
 * Uses a grow-only Dynamic buffer: GPU buffers are reused across frames
 * and reallocated only when capacity is insufficient. `uploadVector`
 * uploads in place, and `render` passes an explicit `drawTri` to limit
 * rendering to the active index range.
 */
class MeshPrimitive extends Primitive
{
    static inline var STRIDE:Int = 8;

    var vertexData:FloatBuffer;
    var indexData:IndexBuffer;
    var dirty:Bool = false;
    var allocated:Bool = false;
    var currentVertCount:Int = 0;
    var currentIdxCount:Int = 0;

    public function new()
    {
        vertexData = new FloatBuffer();
        indexData = new IndexBuffer();
    }

    public function updateData(vertices:Array<Float>, uvs:Array<Float>, indices:Array<Int>):Void
    {
        var vertCount = Std.int(vertices.length / 2);
        var needed = vertCount * STRIDE;
        if (vertexData.length != needed)
        {
            vertexData = new FloatBuffer(needed);
        }
        var vi:Int = 0;
        for (i in 0...vertCount)
        {
            vertexData[vi++] = vertices[i * 2];
            vertexData[vi++] = vertices[i * 2 + 1];
            vertexData[vi++] = uvs[i * 2];
            vertexData[vi++] = uvs[i * 2 + 1];
            // White vertex color; tinting handled by shader uniforms
            vertexData[vi++] = 1.0;
            vertexData[vi++] = 1.0;
            vertexData[vi++] = 1.0;
            vertexData[vi++] = 1.0;
        }

        var idxCount = indices.length;
        if (indexData.length != idxCount)
        {
            indexData = new IndexBuffer(idxCount);
            // grow() already zeroed; we still need to write below
        }
        for (i in 0...idxCount)
        {
            indexData[i] = indices[i];
        }

        dirty = true;
    }

    /** Upload vertex/index data to GPU. Grow-only: buffers are reused across frames
        and reallocated only when capacity is insufficient. Called from L2DMeshDrawable.sync. */
    public function flush():Void
    {
        if (!dirty) return;
        if (vertexData.length == 0) return;

        var vertCount = Std.int(vertexData.length / STRIDE);
        var idxCount = indexData.length;
        currentVertCount = vertCount;
        currentIdxCount = idxCount;

        // Buffer: grow-only — reallocate only when capacity insufficient
        if (buffer == null || buffer.isDisposed() || buffer.vertices < vertCount)
        {
            if (buffer != null && !buffer.isDisposed()) buffer.dispose();
            // RawFormat = map buffer directly to shader inputs (no pos/normal/uv prefix assumption)
            // Dynamic = optimized for frequent re-upload (streaming)
            buffer = new Buffer(vertCount, STRIDE, [h3d.BufferFlag.RawFormat, h3d.BufferFlag.Dynamic]);
        }
        buffer.uploadVector(vertexData, 0, vertCount);

        // Indexes: grow-only — reallocate only when capacity insufficient
        if (indexes == null || indexes.isDisposed() || indexes.count < idxCount)
        {
            if (indexes != null && !indexes.isDisposed()) indexes.dispose();
            indexes = new Indexes(idxCount);
        }
        indexes.upload(indexData, 0, idxCount);

        dirty = false;
        allocated = true;
    }

    override function alloc(engine:Engine):Void
    {
        flush();
    }

    /** Force GPU buffer reallocation on next flush. Disposes current buffers
        so the next group using shared primitive gets a fresh allocation,
        preventing GPU data races when multiple groups reuse the same primitive. */
    public function invalidateBuffer():Void
    {
        if (buffer != null && !buffer.isDisposed())
        {
            buffer.dispose();
            buffer = null;
        }
        if (indexes != null && !indexes.isDisposed())
        {
            indexes.dispose();
            indexes = null;
        }
        dirty = true;
    }

    override function render(engine:Engine):Void
    {
        if (vertexData.length == 0) return;
        if (dirty || buffer == null || buffer.isDisposed())
        {
            flush();
        }
        if (buffer == null || indexes == null) return;
        // Pass explicit drawTri to limit rendering to uploaded indices only —
        // buffer/indexes may be over-allocated (grow-only), so without this,
        // stale garbage indices beyond currentIdxCount would be rendered.
        engine.renderIndexed(buffer, indexes, 0, Std.int(currentIdxCount / 3));
    }

    override function dispose():Void
    {
        if (buffer != null)
        {
            buffer.dispose();
            buffer = null;
        }
        if (indexes != null)
        {
            indexes.dispose();
            indexes = null;
        }
        super.dispose();
    }

    /** Clear vertex/index data and free GPU buffers. */
    public function clear():Void
    {
        vertexData = new FloatBuffer();
        indexData = new IndexBuffer();
        if (buffer != null && !buffer.isDisposed())
        {
            buffer.dispose();
            buffer = null;
        }
        if (indexes != null && !indexes.isDisposed())
        {
            indexes.dispose();
            indexes = null;
        }
        dirty = false;
        allocated = false;
        currentVertCount = 0;
        currentIdxCount = 0;
    }
}

#end
