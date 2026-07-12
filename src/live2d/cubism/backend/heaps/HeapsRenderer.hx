package live2d.cubism.backend.heaps;

#if heaps

import h2d.BlendMode;
import h2d.Object;
import h2d.RenderContext;
import h3d.mat.Texture;
import hxd.PixelFormat;
import hxd.Pixels;
import live2d.cubism.backend.IL2DRenderer;
import live2d.cubism.backend.L2DDisplayHandle;
import live2d.cubism.backend.L2DTextureHandle;

/**
 * Heaps implementation of IL2DRenderer.
 *
 * Uses h2d.Object as container, L2DMeshDrawable as display object,
 * h3d.mat.Texture as texture, and CubismHeapsShader for mask/color/opacity.
 *
 * Mask rendering:
 *   - Groups 0..2 (SHADER_MASK_MAX_GROUPS=3): rendered into a single mask RT
 *     via renderMaskToBitmapData, sampled in-shader via R/G/B channels.
 *   - Groups 3+: each mask display object gets its own fallback mask RT
 *     (drawSolidTriangles accumulates shapes with Add blend; setMask binds
 *     the RT as the target's u_maskTexture with R-channel flag).
 *     This mirrors the OpenFL backend's s.mask fallback for overflow groups.
 */
class HeapsRenderer implements IL2DRenderer
{
    /** Super-sampling factor for mask render-target anti-aliasing.
        Mask RTs are rendered at FACTOR× logical resolution. Hardware bilinear
        filtering naturally downsamples when the shader samples the RT, giving
        effective SSAA edge smoothing without extra passes or shader changes.
        Set to 1 to disable (no SSAA), 2 for 2× (4 samples per logical pixel). */
    static inline var MASK_SSAA_FACTOR:Int = 2;

    /** Root container added to the scene. */
    public var container(default, null):Object;

    var objectIds:Map<L2DMeshDrawable, Int> = new Map();
    var nextObjectId:Int = 0;

    /** 1x1 white texture used as mask RT placeholder in Stage 1. */
    var whiteMaskTexture:Texture;

    /** Mask render-target texture (reallocated when size changes). */
    var maskRT:Texture;

    /** Dedicated drawables for rendering mask shapes to RT (one per color channel: R, G, B).
        Pre-allocated to avoid GPU buffer allocation per group — each channel owns a stable buffer
        that grows as needed, eliminating the buffer-destroy-and-recreate workaround. */
    var maskDrawables:Array<L2DMeshDrawable>;

    /** Solid-color shaders for mask shape rendering (one per channel). */
    var maskShaders:Array<CubismMaskShader>;

    /** Rotating pool of fallback mask drawables for drawSolidTriangles (groups beyond
        shader-mask channels). Each drawSolidTriangles call takes the next drawable from
        this pool so no two concurrent GPU operations within the same frame share a buffer.
        Eliminates the need to invalidate/destroy-and-recreate buffers between calls. */
    var fallbackPool:Array<L2DMeshDrawable> = [];
    var fallbackShaders:Array<CubismMaskShader> = [];
    var nextFallbackIdx:Int = 0;

    /**
     * Per-mask-display-object fallback mask RTs for mask groups beyond
     * SHADER_MASK_MAX_GROUPS. Each mask display object gets its own RT
     * (same size/offset as the main mask RT) that mask shapes are rendered into.
     */
    var fallbackMaskRTs:Map<L2DMeshDrawable, Texture> = new Map();

    /** Tracks which fallback mask RTs have been cleared this frame. */
    var initializedFallbackRTs:Map<L2DMeshDrawable, Bool> = new Map();

    /** Fallback mask RT dimensions (computed from actual vertex AABB in preRenderFallbackMasks). */
    public var fbMaskMinX:Float = 0;
    public var fbMaskMinY:Float = 0;
    public var fbMaskWidth:Float = 0;
    public var fbMaskHeight:Float = 0;

    /** Cached main mask RT params (size + screen offset) for fallback RT allocation and UV mapping. */
    var maskRTWidth:Int = 0;
    var maskRTHeight:Int = 0;
    var maskRTOffsetX:Float = 0;
    var maskRTOffsetY:Float = 0;

    /** Public mask RT dimensions (for perf panels and debugging). */
    public var currentMaskRTWidth(get, null):Int;
    public var currentMaskRTHeight(get, null):Int;
    function get_currentMaskRTWidth():Int return maskRTWidth;
    function get_currentMaskRTHeight():Int return maskRTHeight;

    /** Optional texture loader override (defaults to PNG decode via format.png). */
    public var textureLoader:String->L2DTextureHandle;

    public function new(?parent:Object)
    {
        container = new Object();
        if (parent != null) parent.addChild(container);
        textureLoader = defaultTextureLoader;
        whiteMaskTexture = Texture.fromColor(0xFFFFFFFF, 1.0);
        maskDrawables = [];
        maskShaders = [];
        for (i in 0...3)
        {
            var md = new L2DMeshDrawable();
            md.visible = false;
            md.texture = whiteMaskTexture;
            var ms = new CubismMaskShader();
            md.addShader(ms);
            // L2DMeshDrawable constructor force-adds CubismHeapsShader, but mask
            // drawable only needs CubismMaskShader (solid color fill). Remove it
            // to avoid CubismHeapsShader zeroing the mask shape alpha.
            md.removeShader(md.getCubismShader());
            maskDrawables.push(md);
            maskShaders.push(ms);
        }
    }

    /** Lazily-created 1x1 white texture used as default mask sampler binding. */
    function getWhiteMaskTexture():Texture
    {
        if (whiteMaskTexture == null || whiteMaskTexture.isDisposed())
            whiteMaskTexture = Texture.fromColor(0xFFFFFFFF, 1.0);
        return whiteMaskTexture;
    }

    // ===== Texture management =====

    public function loadTexture(path:String):L2DTextureHandle
    {
        return textureLoader(path);
    }

    public function destroyTexture(tex:L2DTextureHandle):Void
    {
        var t:Texture = cast tex;
        if (t != null && !t.isDisposed()) t.dispose();
    }

    function defaultTextureLoader(path:String):L2DTextureHandle
    {
        #if sys
        if (!sys.FileSystem.exists(path)) return null;
        var bytes = sys.io.File.getBytes(path);
        var png = new format.png.Reader(new haxe.io.BytesInput(bytes));
        png.checkCRC = false;
        var pdata = png.read();
        var header = format.png.Tools.getHeader(pdata);
        var w = header.width;
        var h = header.height;
        var pixels = Pixels.alloc(w, h, PixelFormat.BGRA);
        format.png.Tools.extract32(pdata, pixels.bytes, false);
        var tex = Texture.fromPixels(pixels);
        tex.filter = h3d.mat.Data.Filter.Linear;
        return tex;
        #else
        return null;
        #end
    }

    // ===== Display object management =====

    public function createContainer():L2DDisplayHandle
    {
        // container is created in constructor; just return it
        return container;
    }

    public function destroyContainer():Void
    {
        if (container != null)
        {
            container.removeChildren();
            if (container.parent != null) container.parent.removeChild(container);
            container = null;
        }
        if (maskDrawables != null)
        {
            for (md in maskDrawables) @:privateAccess md.onRemove();
            maskDrawables = null;
        }
        maskShaders = null;
        if (fallbackPool != null)
        {
            for (md in fallbackPool) @:privateAccess md.onRemove();
            fallbackPool = null;
        }
        fallbackShaders = null;
        nextFallbackIdx = 0;
        if (maskRT != null)
        {
            if (!maskRT.isDisposed()) L2DHeapsMaskRTCache.release(maskRT, maskRT.width, maskRT.height);
            maskRT = null;
        }
        if (whiteMaskTexture != null)
        {
            whiteMaskTexture.dispose();
            whiteMaskTexture = null;
        }
        for (rt in fallbackMaskRTs)
        {
            if (rt != null && !rt.isDisposed()) rt.dispose();
        }
        fallbackMaskRTs = new Map();
        initializedFallbackRTs = new Map();
        maskRTWidth = 0;
        maskRTHeight = 0;
        maskRTOffsetX = 0;
        maskRTOffsetY = 0;
        objectIds = new Map();
        nextObjectId = 0;
    }

    public function createDisplayObject():L2DDisplayHandle
    {
        var d = new L2DMeshDrawable(container);
        d.visible = false;
        d.getCubismShader().u_maskTexture = getWhiteMaskTexture();
        var id = nextObjectId++;
        objectIds.set(d, id);
        return d;
    }

    public function resetDisplayObject(obj:L2DDisplayHandle):Void
    {
        var d:L2DMeshDrawable = cast obj;
        d.visible = false;
        d.alpha = 1.0;
        d.blendMode = Alpha;
        d.color.set(1, 1, 1, 1);
        d.texture = null;
        d.primitive.clear();
        d.resetShaderUniforms();
        d.getCubismShader().u_convertPremul = 1; // Alpha by default

        // Mark fallback mask RT as needing re-clear next frame
        if (fallbackMaskRTs.exists(d))
        {
            initializedFallbackRTs.set(d, false);
        }
    }

    public function setVisible(obj:L2DDisplayHandle, visible:Bool):Void
    {
        var d:L2DMeshDrawable = cast obj;
        d.visible = visible;
    }

    public function setAlpha(obj:L2DDisplayHandle, alpha:Float):Void
    {
        var d:L2DMeshDrawable = cast obj;
        d.alpha = alpha;
    }

    public function setBlendMode(obj:L2DDisplayHandle, blendValue:Int):Void
    {
        var d:L2DMeshDrawable = cast obj;
        d.blendMode = blendModeFromValue(blendValue);
        // u_convertPremul selects the shader mask+conversion path:
        //   0 = Multiply/Screen path (premul→non-premul before mask, lerp to white/black)
        //   1 = Alpha/Add path (mask scales alpha, premul→non-premul at end)
        d.getCubismShader().u_convertPremul = switch (d.blendMode) {
            case Multiply, Screen: 0;
            default: 1;
        };
    }

    public function setColorTransform(obj:L2DDisplayHandle,
        mulR:Float, mulG:Float, mulB:Float, mulA:Float,
        addR:Float, addG:Float, addB:Float, addA:Float):Void
    {
        // Heaps Base2d only supports multiply via drawable.color; add offset ignored in Stage 1.
        var d:L2DMeshDrawable = cast obj;
        d.color.set(mulR, mulG, mulB, mulA);
    }

    public function resetColorTransform(obj:L2DDisplayHandle):Void
    {
        var d:L2DMeshDrawable = cast obj;
        d.color.set(1, 1, 1, 1);
    }

    public function setMask(obj:L2DDisplayHandle, mask:L2DDisplayHandle, ?isInverted:Bool = false):Void
    {
        // Fallback mask path: bind the mask display object's RT as the target's
        // mask texture in the shader. Uses R channel only (channelFlag = [1,0,0,0]).
        var d:L2DMeshDrawable = cast obj;
        var maskD:L2DMeshDrawable = cast mask;

        var rt = fallbackMaskRTs.get(maskD);
        if (rt == null || rt.isDisposed()) return;

        // Use fallback mask dimensions (set by preRenderFallbackMasks) for UV mapping
        // so the shader samples the correct region of the fallback mask RT.
        var useFb = (fbMaskWidth > 0);
        var offX:Float = useFb ? fbMaskMinX : maskRTOffsetX;
        var offY:Float = useFb ? fbMaskMinY : maskRTOffsetY;
        var scaleX:Float = useFb ? fbMaskWidth : maskRTWidth;
        var scaleY:Float = useFb ? fbMaskHeight : maskRTHeight;

        var sh = d.getCubismShader();
        sh.u_useMask = 1;
        sh.u_maskTexture = rt;
        sh.u_channelFlag.set(1, 0, 0, 0);
        sh.u_maskOffset.set(offX, offY);
        sh.u_maskScale.set(scaleX, scaleY);
        sh.u_isInverted = (isInverted != null && isInverted) ? 1 : 0;
    }

    public function getFallbackMaskTexture(obj:L2DDisplayHandle):L2DTextureHandle
    {
        var d:L2DMeshDrawable = cast obj;
        return fallbackMaskRTs.get(d);
    }

    public function setFallbackMaskDimensions(minX:Float, minY:Float, width:Float, height:Float):Void
    {
        fbMaskMinX = minX;
        fbMaskMinY = minY;
        fbMaskWidth = width;
        fbMaskHeight = height;
    }

    public function clearMask(obj:L2DDisplayHandle):Void
    {
        var d:L2DMeshDrawable = cast obj;
        var sh = d.getCubismShader();
        sh.u_useMask = 0;
        sh.u_maskTexture = getWhiteMaskTexture();
        sh.u_channelFlag.set(1, 0, 0, 0);
        sh.u_maskOffset.set(0, 0);
        sh.u_maskScale.set(1, 1);
        sh.u_isInverted = 0;
    }

    // ===== Shader Mask =====

    public function supportsShaderMask():Bool
    {
        return true;
    }

    public function renderMaskToBitmapData(
        maskShapes:Array<{groupIndex:Int, channelFlag:Array<Float>,
                          vertices:Array<Array<Float>>, indices:Array<Array<Int>>}>,
        width:Int, height:Int, offsetX:Float, offsetY:Float
    ):L2DTextureHandle
    {
        if (width <= 0 || height <= 0) return getWhiteMaskTexture();

        // Cache params for fallback mask RT allocation and UV mapping.
        // These are the LOGICAL size — uniforms use them for UV computation.
        // The physical RT is MASK_SSAA_FACTOR× larger (SSAA).
        maskRTWidth = width;
        maskRTHeight = height;
        maskRTOffsetX = offsetX;
        maskRTOffsetY = offsetY;

        // Reset fallback drawable rotation for this frame — each drawSolidTriangles
        // call gets a unique drawable to prevent shared-buffer GPU data races.
        nextFallbackIdx = 0;

        // (Re)allocate RT texture at SSAA-scaled size if changed
        var physW = width * MASK_SSAA_FACTOR;
        var physH = height * MASK_SSAA_FACTOR;
        if (maskRT == null || maskRT.isDisposed() || maskRT.width != physW || maskRT.height != physH)
        {
            if (maskRT != null && !maskRT.isDisposed()) L2DHeapsMaskRTCache.release(maskRT, maskRT.width, maskRT.height);
            maskRT = L2DHeapsMaskRTCache.get(physW, physH);
            maskRT.filter = Linear; // bilinear for SSAA downsample in shader
        }

        var ctx:RenderContext = @:privateAccess container.getScene().ctx;
        var engine = ctx.engine;

        ctx.pushTarget(maskRT);
        engine.clear(0);

        // Mask group colors: R, G, B channels (matching channelFlag ordering)
        var groupColors = [
            { r: 1.0, g: 0.0, b: 0.0 },
            { r: 0.0, g: 1.0, b: 0.0 },
            { r: 0.0, g: 0.0, b: 1.0 }
        ];

        maskDrawables[0].blendMode = Add;
		maskDrawables[0].color.set(1, 1, 1, 1);
		maskDrawables[0].alpha = 1.0;
		maskDrawables[1].blendMode = Add;
		maskDrawables[1].color.set(1, 1, 1, 1);
		maskDrawables[1].alpha = 1.0;
		maskDrawables[2].blendMode = Add;
		maskDrawables[2].color.set(1, 1, 1, 1);
		maskDrawables[2].alpha = 1.0;

        for (shape in maskShapes)
        {
            var gi = shape.groupIndex;
            var gc = (gi >= 0 && gi < groupColors.length) ? groupColors[gi] : { r: 1.0, g: 1.0, b: 1.0 };

            // Use the pre-allocated drawable/shader for this channel (groupIndex 0/1/2)
            // Falls back to index 0 for groups beyond the first 3 channels
            var poolIdx = (gi >= 0 && gi < maskDrawables.length) ? gi : 0;
            var md = maskDrawables[poolIdx];
            var ms = maskShaders[poolIdx];

            ms.u_color.set(gc.r, gc.g, gc.b, 1.0);

            // Merge all sub-shapes in this group into one vertex/index list
            var mergedVerts:Array<Float> = new Array();
            var mergedUVs:Array<Float> = new Array();
            var mergedIndices:Array<Int> = new Array();
            var vertBase = 0;

            for (i in 0...shape.vertices.length)
            {
                var verts = shape.vertices[i];
                var idxs = shape.indices[i];

                for (v in 0...Std.int(verts.length / 2))
                {
                    mergedVerts.push((verts[v * 2] - offsetX) * MASK_SSAA_FACTOR);
                    mergedVerts.push((verts[v * 2 + 1] - offsetY) * MASK_SSAA_FACTOR);
                    mergedUVs.push(0.0);
                    mergedUVs.push(0.0);
                }

                for (n in 0...idxs.length)
                {
                    mergedIndices.push(idxs[n] + vertBase);
                }
                vertBase += Std.int(verts.length / 2);
            }

            if (mergedIndices.length == 0) continue;

            md.updateMesh(mergedVerts, mergedUVs, mergedIndices);
            md.primitive.flush();
            @:privateAccess md.draw(ctx);
            // No invalidateBuffer needed: each channel owns a stable buffer that
            // grows as needed; glBufferSubData on a different buffer cannot race
            // with a pending draw on a different buffer.
            // No wait needed: each group's drawable has its own independent GPU
            // buffer, so there's no shared-buffer data race.
        }

        ctx.popTarget();

        return maskRT;
    }

    public function drawShaderTexturedTriangles(obj:L2DDisplayHandle,
        texture:L2DTextureHandle,
        vertices:Array<Float>, uvs:Array<Float>, indices:Array<Int>,
        ?maskTexture:L2DTextureHandle,
        ?channelFlag:Array<Float>,
        ?maskOffset:Array<Float>, ?maskScale:Array<Float>,
        ?isInverted:Bool,
        ?mulColor:Array<Float>,
        ?scrColor:Array<Float>,
        ?opacity:Float):Void
    {
        var d:L2DMeshDrawable = cast obj;
        d.texture = cast texture;

        var sh = d.getCubismShader();

        // Mask uniforms (always set to avoid stale state)
        var useMask = (maskTexture != null && channelFlag != null);
        if (useMask)
        {
            sh.u_useMask = 1;
            sh.u_maskTexture = cast maskTexture;
            sh.u_channelFlag.set(channelFlag[0], channelFlag[1], channelFlag[2], channelFlag[3]);
            if (maskOffset != null)
                sh.u_maskOffset.set(maskOffset[0], maskOffset[1]);
            else
                sh.u_maskOffset.set(0, 0);
            if (maskScale != null)
                sh.u_maskScale.set(maskScale[0], maskScale[1]);
            else
                sh.u_maskScale.set(1, 1);
            sh.u_isInverted = (isInverted != null && isInverted) ? 1 : 0;
        }
        else
        {
            sh.u_useMask = 0;
            sh.u_maskTexture = getWhiteMaskTexture();
            sh.u_channelFlag.set(1, 0, 0, 0);
            sh.u_maskOffset.set(0, 0);
            sh.u_maskScale.set(1, 1);
            sh.u_isInverted = 0;
        }

        // Multiply/Screen color uniforms (always set)
        var useColor = (mulColor != null && scrColor != null);
        if (useColor)
        {
            sh.u_useColor = 1;
            sh.u_mulColor.set(mulColor[0], mulColor[1], mulColor[2]);
            sh.u_scrColor.set(scrColor[0], scrColor[1], scrColor[2]);
        }
        else
        {
            sh.u_useColor = 0;
            sh.u_mulColor.set(1, 1, 1);
            sh.u_scrColor.set(0, 0, 0);
        }

        // Opacity (always set)
        sh.u_opacity = (opacity != null) ? opacity : 1.0;

        d.updateMesh(vertices, uvs, indices);
    }

    // ===== Drawing (fallback non-shader path) =====

    public function drawTexturedTriangles(obj:L2DDisplayHandle,
        texture:L2DTextureHandle,
        vertices:Array<Float>, uvs:Array<Float>, indices:Array<Int>):Void
    {
        var d:L2DMeshDrawable = cast obj;
        d.texture = cast texture;
        // Reset shader to passthrough (opacity/alpha handled by obj.alpha via Base2d)
        d.resetShaderUniforms();
        d.getCubismShader().u_maskTexture = getWhiteMaskTexture();
        d.updateMesh(vertices, uvs, indices);
    }

    function getFallbackDrawable():{drawable:L2DMeshDrawable, shader:CubismMaskShader}
    {
        // Grow pool when all entries are exhausted within this frame.
        // nextFallbackIdx is reset to 0 at the start of each renderMaskToBitmapData
        // call, so no modulo wrapping — each drawSolidTriangles within a frame
        // gets a unique drawable with its own independent GPU buffer.
        while (nextFallbackIdx >= fallbackPool.length)
        {
            expandFallbackPool();
        }
        var idx = nextFallbackIdx;
        nextFallbackIdx++;
        return {drawable: fallbackPool[idx], shader: fallbackShaders[idx]};
    }

    function expandFallbackPool():Void
    {
        var md = new L2DMeshDrawable();
        var ms = new CubismMaskShader();
        md.addShader(ms);
        md.removeShader(md.getCubismShader());
        fallbackPool.push(md);
        fallbackShaders.push(ms);
    }

    public function drawSolidTriangles(obj:L2DDisplayHandle,
        vertices:Array<Float>, indices:Array<Int>):Void
    {
        // Fallback mask path: render solid-color triangles into a per-mask-obj RT.
        // Uses a rotating pool of drawables so each GPU operation has its own
        // independent buffer — no invalidate/destroy-and-recreate needed.
        var d:L2DMeshDrawable = cast obj;

        // Use fallback mask AABB if set (preRenderFallbackMasks computed actual vertex bounds)
        var useFb = (fbMaskWidth > 0);
        var rtW:Int = useFb ? Math.ceil(fbMaskWidth) : maskRTWidth;
        var rtH:Int = useFb ? Math.ceil(fbMaskHeight) : maskRTHeight;
        var offX:Float = useFb ? fbMaskMinX : maskRTOffsetX;
        var offY:Float = useFb ? fbMaskMinY : maskRTOffsetY;

        if (rtW <= 0 || rtH <= 0) return;

        var vertCount = Std.int(vertices.length / 2);
        if (vertCount == 0) return;

        // Get or (re)allocate fallback mask RT for this mask display object
        var rt = fallbackMaskRTs.get(d);
        var physW = rtW * MASK_SSAA_FACTOR;
        var physH = rtH * MASK_SSAA_FACTOR;
        if (rt == null || rt.isDisposed() || rt.width != physW || rt.height != physH)
        {
            if (rt != null && !rt.isDisposed()) rt.dispose();
            rt = new Texture(physW, physH, [Target]);
            rt.filter = Linear; // bilinear for SSAA downsample in shader
            fallbackMaskRTs.set(d, rt);
            initializedFallbackRTs.set(d, false);
        }

        var ctx:RenderContext = @:privateAccess container.getScene().ctx;
        var engine = ctx.engine;

        // Clear RT on first use this frame (accumulates subsequent draws via Add blend)
        if (!initializedFallbackRTs.get(d))
        {
            ctx.pushTarget(rt);
            engine.clear(0);
            ctx.popTarget();
            initializedFallbackRTs.set(d, true);
        }

        // Convert screen-space vertices to RT-local vertices
        var rtVerts:Array<Float> = new Array();
        var rtUVs:Array<Float> = new Array();
        rtVerts[vertCount * 2 - 1] = 0;
        rtUVs[vertCount * 2 - 1] = 0;

        for (v in 0...vertCount)
        {
            rtVerts[v * 2] = (vertices[v * 2] - offX) * MASK_SSAA_FACTOR;
            rtVerts[v * 2 + 1] = (vertices[v * 2 + 1] - offY) * MASK_SSAA_FACTOR;
            rtUVs[v * 2] = 0.0;
            rtUVs[v * 2 + 1] = 0.0;
        }

        // Render solid red (R channel) triangles into the fallback mask RT
        // using a rotating pool drawable — no buffer sharing with main path
        var fb = getFallbackDrawable();
        var md = fb.drawable;
        var ms = fb.shader;
        md.texture = getWhiteMaskTexture();
        md.blendMode = Add;
        md.color.set(1, 1, 1, 1);
        md.alpha = 1.0;
        ms.u_color.set(1, 0, 0, 1);

        md.updateMesh(rtVerts, rtUVs, indices);
        md.primitive.flush();

        ctx.pushTarget(rt);
        @:privateAccess md.draw(ctx);
        ctx.popTarget();
        // No invalidateBuffer needed: each call gets its own drawable from the
        // rotating fallback pool, so there's no shared-buffer data race within
        // the frame. GPU buffers are grow-only and reused across frames.
    }

    // ===== Display list =====

    public function setChildIndex(child:L2DDisplayHandle, index:Int):Void
    {
        var d:L2DMeshDrawable = cast child;
        if (d.parent != container) return;
        // Direct array manipulation to avoid onRemove side effects from removeChild.
        @:privateAccess {
            container.children.remove(d);
            container.children.insert(index, d);
        }
    }

    public function getObjectId(obj:L2DDisplayHandle):Int
    {
        var d:L2DMeshDrawable = cast obj;
        return objectIds.exists(d) ? objectIds.get(d) : 0;
    }

    public function getContainer():L2DDisplayHandle
    {
        return container;
    }

    // ===== Helpers =====

    static function blendModeFromValue(val:Int):BlendMode
    {
        return switch (val)
        {
            case 0: Alpha;    // Normal
            case 1: Add;      // Additive
            case 2: Multiply; // Multiply (Cubism: GL_DST_COLOR, GL_ZERO)
            case 3: Add;      // Add (alt encoding)
            case 6: Multiply; // Multiply (alt encoding)
            case 10: Screen;  // Screen
            default: Alpha;
        }
    }


}

#end
