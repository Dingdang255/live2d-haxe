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
    /** Root container added to the scene. */
    public var container(default, null):Object;

    var objectIds:Map<L2DMeshDrawable, Int> = new Map();
    var nextObjectId:Int = 0;

    /** 1x1 white texture used as mask RT placeholder in Stage 1. */
    var whiteMaskTexture:Texture;

    /** Mask render-target texture (reallocated when size changes). */
    var maskRT:Texture;

    /** Dedicated drawable for rendering mask shapes to RT. Not added to container. */
    var maskDrawable:L2DMeshDrawable;

    /** Solid-color shader for mask shape rendering. */
    var maskShader:CubismMaskShader;

    /**
     * Per-mask-display-object fallback mask RTs for mask groups beyond
     * SHADER_MASK_MAX_GROUPS. Each mask display object gets its own RT
     * (same size/offset as the main mask RT) that mask shapes are rendered into.
     */
    var fallbackMaskRTs:Map<L2DMeshDrawable, Texture> = new Map();

    /** Tracks which fallback mask RTs have been cleared this frame. */
    var initializedFallbackRTs:Map<L2DMeshDrawable, Bool> = new Map();

    /** Cached main mask RT params (size + screen offset) for fallback RT allocation and UV mapping. */
    var maskRTWidth:Int = 0;
    var maskRTHeight:Int = 0;
    var maskRTOffsetX:Float = 0;
    var maskRTOffsetY:Float = 0;

    /** Optional texture loader override (defaults to PNG decode via format.png). */
    public var textureLoader:String->L2DTextureHandle;

    public function new(?parent:Object)
    {
        container = new Object();
        if (parent != null) parent.addChild(container);
        textureLoader = defaultTextureLoader;
        whiteMaskTexture = Texture.fromColor(0xFFFFFFFF, 1.0);
        maskDrawable = new L2DMeshDrawable();
        maskDrawable.visible = false;
        maskDrawable.texture = whiteMaskTexture;
        maskShader = new CubismMaskShader();
        maskDrawable.addShader(maskShader);
        // L2DMeshDrawable constructor force-adds CubismHeapsShader, but maskDrawable
        // only needs CubismMaskShader (solid color fill). CubismHeapsShader.u_opacity
        // defaults to 0, and its fragment runs after CubismMaskShader's (it reads
        // pixelColor which CubismMaskShader writes), zeroing the mask shape alpha
        // and leaving the mask RT empty. Remove it to avoid the interference.
        maskDrawable.removeShader(maskDrawable.getCubismShader());
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
        if (maskDrawable != null)
        {
            @:privateAccess maskDrawable.onRemove();
            maskDrawable = null;
        }
        maskShader = null;
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

    public function setMask(obj:L2DDisplayHandle, mask:L2DDisplayHandle):Void
    {
        // Fallback mask path: bind the mask display object's RT as the target's
        // mask texture in the shader. Uses R channel only (channelFlag = [1,0,0,0]).
        var d:L2DMeshDrawable = cast obj;
        var maskD:L2DMeshDrawable = cast mask;

        var rt = fallbackMaskRTs.get(maskD);
        if (rt == null || rt.isDisposed()) return;

        var sh = d.getCubismShader();
        sh.u_useMask = 1;
        sh.u_maskTexture = rt;
        sh.u_channelFlag.set(1, 0, 0, 0);
        sh.u_maskOffset.set(maskRTOffsetX, maskRTOffsetY);
        sh.u_maskScale.set(maskRTWidth, maskRTHeight);
        sh.u_isInverted = 0;
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

        // Cache params for fallback mask RT allocation and UV mapping
        maskRTWidth = width;
        maskRTHeight = height;
        maskRTOffsetX = offsetX;
        maskRTOffsetY = offsetY;

        // (Re)allocate RT texture if size changed — use pool to avoid alloc/dispose churn
        if (maskRT == null || maskRT.isDisposed() || maskRT.width != width || maskRT.height != height)
        {
            if (maskRT != null && !maskRT.isDisposed()) L2DHeapsMaskRTCache.release(maskRT, maskRT.width, maskRT.height);
            maskRT = L2DHeapsMaskRTCache.get(width, height);
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

        maskDrawable.blendMode = Add;
        maskDrawable.color.set(1, 1, 1, 1);
        maskDrawable.alpha = 1.0;

        for (shape in maskShapes)
        {
            var gi = shape.groupIndex;
            var gc = (gi >= 0 && gi < groupColors.length) ? groupColors[gi] : { r: 1.0, g: 1.0, b: 1.0 };
            maskShader.u_color.set(gc.r, gc.g, gc.b, 1.0);

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
                    // Screen-space vertex → RT-local vertex (subtract RT origin)
                    mergedVerts.push(verts[v * 2] - offsetX);
                    mergedVerts.push(verts[v * 2 + 1] - offsetY);
                    // UV unused by mask shader; fill zeros to satisfy vertex format
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

            maskDrawable.updateMesh(mergedVerts, mergedUVs, mergedIndices);
            maskDrawable.primitive.flush();
            @:privateAccess maskDrawable.draw(ctx);

            // Force GPU buffer reallocation between groups: all groups share the
            // same maskDrawable + primitive, so updateMesh overwrites the GPU
            // vertex buffer. Without this, group N's glBufferSubData can corrupt
            // group N-1's in-flight draw, causing mask shapes to render at wrong
            // positions.
            maskDrawable.primitive.invalidateBuffer();
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

    public function drawSolidTriangles(obj:L2DDisplayHandle,
        vertices:Array<Float>, indices:Array<Int>):Void
    {
        // Fallback mask path: render solid-color triangles into a per-mask-obj RT.
        // The RT shares size/offset with the main mask RT; vertices are converted
        // from screen space to RT-local space by subtracting the cached offset.
        // Mask shapes accumulate across multiple drawSolidTriangles calls for the
        // same mask object (Add blend mode); the RT is cleared on first use per frame.
        var d:L2DMeshDrawable = cast obj;

        if (maskRTWidth <= 0 || maskRTHeight <= 0) return;

        // Get or (re)allocate fallback mask RT for this mask display object
        var rt = fallbackMaskRTs.get(d);
        if (rt == null || rt.isDisposed() || rt.width != maskRTWidth || rt.height != maskRTHeight)
        {
            if (rt != null && !rt.isDisposed()) rt.dispose();
            rt = new Texture(maskRTWidth, maskRTHeight, [Target]);
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
        var vertCount = Std.int(vertices.length / 2);
        var rtVerts:Array<Float> = new Array();
        var rtUVs:Array<Float> = new Array();
        rtVerts[vertCount * 2 - 1] = 0;
        rtUVs[vertCount * 2 - 1] = 0;
        for (v in 0...vertCount)
        {
            rtVerts[v * 2] = vertices[v * 2] - maskRTOffsetX;
            rtVerts[v * 2 + 1] = vertices[v * 2 + 1] - maskRTOffsetY;
            rtUVs[v * 2] = 0.0;
            rtUVs[v * 2 + 1] = 0.0;
        }

        // Render solid red (R channel) triangles into the fallback mask RT
        maskDrawable.texture = getWhiteMaskTexture();
        maskDrawable.blendMode = Add;
        maskDrawable.color.set(1, 1, 1, 1);
        maskDrawable.alpha = 1.0;
        maskShader.u_color.set(1, 0, 0, 1);

        maskDrawable.updateMesh(rtVerts, rtUVs, indices);
        maskDrawable.primitive.flush();

        ctx.pushTarget(rt);
        @:privateAccess maskDrawable.draw(ctx);
        ctx.popTarget();
        // Prevent GPU buffer races with renderMaskToBitmapData
        maskDrawable.primitive.invalidateBuffer();
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
            case 0: Alpha;     // Normal
            case 1: Alpha;     // AddCompatible (visually Normal)
            case 2: Multiply;  // MultiplyCompatible
            case 3: Add;       // Add
            case 6: Multiply;  // Multiply
            case 10: Screen;   // Screen
            default: Alpha;
        }
    }
}

#end
