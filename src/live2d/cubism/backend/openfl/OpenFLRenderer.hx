package live2d.cubism.backend.openfl;

#if openfl

import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Sprite;
import openfl.display.TriangleCulling;
import openfl.geom.ColorTransform;
import openfl.geom.Rectangle;
import openfl.Vector;
import live2d.cubism.backend.IL2DRenderer;
import live2d.cubism.backend.L2DDisplayHandle;
import live2d.cubism.backend.L2DTextureHandle;

/**
 * OpenFL implementation of IL2DRenderer.
 * Uses Sprite.graphics.drawTriangles for rendering.
 *
 * Supports both:
 *   - Unified GPU shader path (mask + Multiply/Screen color + opacity)
 *   - Fallback CPU path (beginBitmapFill + ColorTransform + Sprite.mask)
 */
class OpenFLRenderer implements IL2DRenderer
{
    var containerSprite:Sprite;
    var textureLoader:String->L2DTextureHandle;
    var textureDestroyer:L2DTextureHandle->Void;
    var nextObjectId:Int = 0;
    var textureToBitmapData:L2DTextureHandle->BitmapData;

    static var defaultColorTransform:ColorTransform = new ColorTransform();
    // Reusable ColorTransform to avoid allocation per call
    var reusableColorTransform:ColorTransform = new ColorTransform();

    // Unified renderer shader (mask + color + opacity)
    var rendererShader:CubismRendererShader;
    // Mask offscreen texture
    var maskBitmapData:BitmapData;
    var tempMaskSprite:Sprite;

    // Pre-allocated shader uniform arrays (avoid ~166 allocations/frame)
    static var UNI_USE_MASK_ON:Array<Float> = [1.0];
    static var UNI_USE_MASK_OFF:Array<Float> = [0.0];
    static var UNI_MASK_OFFSET_ZERO:Array<Float> = [0.0, 0.0];
    static var UNI_MASK_SCALE_ONE:Array<Float> = [1.0, 1.0];
    static var UNI_CHANNEL_FLAG_DEFAULT:Array<Float> = [1.0, 0.0, 0.0, 0.0];
    static var UNI_IS_INVERTED_OFF:Array<Float> = [0.0];
    static var UNI_MUL_COLOR_DEFAULT:Array<Float> = [1.0, 1.0, 1.0];
    static var UNI_SCR_COLOR_DEFAULT:Array<Float> = [0.0, 0.0, 0.0];
    static var UNI_USE_COLOR_ON:Array<Float> = [1.0];
    static var UNI_USE_COLOR_OFF:Array<Float> = [0.0];
    var uniIsInvertedOn:Array<Float> = [1.0];
    var uniOpacityBuf:Array<Float> = [1.0];
    var uniMaskOffsetBuf:Array<Float> = [0.0, 0.0];
    var uniMaskScaleBuf:Array<Float> = [1.0, 1.0];
    var uniChannelFlagBuf:Array<Float> = [1.0, 0.0, 0.0, 0.0];

    // Fallback mask RT support (per-object BitmapData, mirrors HeapsRenderer)
    var fbMaskMinX:Float = 0;
    var fbMaskMinY:Float = 0;
    var fbMaskWidth:Float = 0;
    var fbMaskHeight:Float = 0;
    var fallbackMaskRTs:Map<Sprite, BitmapData> = new Map();
    // Batching: accumulate shapes for one mask object, flush on target change
    var pendingFallbackSprite:Sprite;
    var tempFallbackMaskSprite:Sprite;

    // Resolution cap: BitmapData.fillRect/draw are CPU-side and scale with pixel count.
    // Cap at 512px max dimension; shader linear filtering handles upscaling from lower res.
    static inline var FB_MASK_MAX_RES:Int = 512;

    public function new(
        ?textureLoader:String->L2DTextureHandle,
        ?textureDestroyer:L2DTextureHandle->Void,
        ?textureToBitmapData:L2DTextureHandle->BitmapData)
    {
        this.textureLoader = textureLoader != null ? textureLoader : defaultTextureLoader;
        this.textureDestroyer = textureDestroyer != null ? textureDestroyer : defaultTextureDestroyer;
        this.textureToBitmapData = textureToBitmapData != null ? textureToBitmapData : defaultTextureToBitmapData;
        rendererShader = new CubismRendererShader();
    }

    static function defaultTextureLoader(path:String):L2DTextureHandle
    {
        #if sys
        var bmp = BitmapData.fromFile(path);
        if (bmp != null) return bmp;
        #end
        return null;
    }

    static function defaultTextureDestroyer(tex:L2DTextureHandle):Void
    {
        var bmp:BitmapData = cast tex;
        if (bmp != null) bmp.dispose();
    }

    static function defaultTextureToBitmapData(tex:L2DTextureHandle):BitmapData
    {
        return cast tex;
    }

    // ===== Texture management =====

    public function loadTexture(path:String):L2DTextureHandle
    {
        return textureLoader(path);
    }

    public function destroyTexture(tex:L2DTextureHandle):Void
    {
        textureDestroyer(tex);
    }

    // ===== Display object management =====

    public function createContainer():L2DDisplayHandle
    {
        containerSprite = new Sprite();
        return containerSprite;
    }

    public function destroyContainer():Void
    {
        if (containerSprite != null)
        {
            containerSprite.removeChildren();
            if (containerSprite.parent != null)
                containerSprite.parent.removeChild(containerSprite);
            containerSprite = null;
        }
        if (maskBitmapData != null)
        {
            maskBitmapData.dispose();
            maskBitmapData = null;
        }
        tempMaskSprite = null;
        for (rt in fallbackMaskRTs)
        {
            if (rt != null) rt.dispose();
        }
        fallbackMaskRTs = new Map();
        pendingFallbackSprite = null;
        tempFallbackMaskSprite = null;
    }

    public function createDisplayObject():L2DDisplayHandle
    {
        var s = new Sprite();
        s.name = Std.string(nextObjectId++);
        s.visible = false;
        containerSprite.addChild(s);
        return s;
    }

    public function resetDisplayObject(obj:L2DDisplayHandle):Void
    {
        var s:Sprite = cast obj;
        s.visible = false;
        s.graphics.clear();
        s.alpha = 1.0;
        s.blendMode = BlendMode.NORMAL;
        s.transform.colorTransform = defaultColorTransform;
        s.mask = null;
    }

    public function setVisible(obj:L2DDisplayHandle, visible:Bool):Void
    {
        var s:Sprite = cast obj;
        s.visible = visible;
    }

    public function setAlpha(obj:L2DDisplayHandle, alpha:Float):Void
    {
        var s:Sprite = cast obj;
        s.alpha = alpha;
    }

    public function setBlendMode(obj:L2DDisplayHandle, blendValue:Int):Void
    {
        var s:Sprite = cast obj;
        s.blendMode = blendModeFromValue(blendValue);
    }

    public function setColorTransform(obj:L2DDisplayHandle,
        mulR:Float, mulG:Float, mulB:Float, mulA:Float,
        addR:Float, addG:Float, addB:Float, addA:Float):Void
    {
        var s:Sprite = cast obj;
        reusableColorTransform.redMultiplier = mulR;
        reusableColorTransform.greenMultiplier = mulG;
        reusableColorTransform.blueMultiplier = mulB;
        reusableColorTransform.alphaMultiplier = mulA;
        reusableColorTransform.redOffset = addR;
        reusableColorTransform.greenOffset = addG;
        reusableColorTransform.blueOffset = addB;
        reusableColorTransform.alphaOffset = addA;
        s.transform.colorTransform = reusableColorTransform;
    }

    public function resetColorTransform(obj:L2DDisplayHandle):Void
    {
        var s:Sprite = cast obj;
        s.transform.colorTransform = defaultColorTransform;
    }

    public function setMask(obj:L2DDisplayHandle, mask:L2DDisplayHandle, ?isInverted:Bool = false):Void
    {
        var s:Sprite = cast obj;
        var maskSprite:Sprite = cast mask;
        s.mask = maskSprite;
        // Note: isInverted ignored — Flash native Sprite.mask doesn't support inverted masking.
    }

    public function clearMask(obj:L2DDisplayHandle):Void
    {
        var s:Sprite = cast obj;
        s.mask = null;
    }

    // ===== Shader Mask =====

    public function supportsShaderMask():Bool
    {
        return true;
    }

    public function getFallbackMaskTexture(obj:L2DDisplayHandle):L2DTextureHandle
    {
        // Flush any pending batched shapes before returning (captures last group's work)
        flushPendingFallbackRT();
        var s:Sprite = cast obj;
        return fallbackMaskRTs.get(s);
    }

    public function setFallbackMaskDimensions(minX:Float, minY:Float, width:Float, height:Float):Void
    {
        // Flush any leftover pending work from previous frame
        flushPendingFallbackRT();
        fbMaskMinX = minX;
        fbMaskMinY = minY;
        fbMaskWidth = width;
        fbMaskHeight = height;
    }

    public function renderMaskToBitmapData(
        maskShapes:Array<{groupIndex:Int, channelFlag:Array<Float>,
                          vertices:Array<Array<Float>>, indices:Array<Array<Int>>}>,
        width:Int, height:Int, offsetX:Float, offsetY:Float
    ):L2DTextureHandle
    {
        if (maskBitmapData == null || maskBitmapData.width != width || maskBitmapData.height != height)
        {
            if (maskBitmapData != null) maskBitmapData.dispose();
            maskBitmapData = new BitmapData(width, height, true, 0x00000000);
        }
        else
        {
            maskBitmapData.fillRect(new Rectangle(0, 0, width, height), 0x00000000);
        }

        if (tempMaskSprite == null)
            tempMaskSprite = new Sprite();

        var groupColors = [0xFFFF0000, 0xFF00FF00, 0xFF0000FF];

        // Draw all mask shapes into tempMaskSprite first, then do a single BitmapData.draw()
        tempMaskSprite.graphics.clear();

        for (shape in maskShapes)
        {
            var gi = shape.groupIndex;
            var fillColor = (gi >= 0 && gi < groupColors.length) ? groupColors[gi] : 0xFFFFFFFF;

            for (i in 0...shape.vertices.length)
            {
                var verts = shape.vertices[i];
                var idxs = shape.indices[i];

                var offsetVerts = new Array<Float>();
                for (v in 0...verts.length)
                {
                    if (v % 2 == 0)
                        offsetVerts.push(verts[v] - offsetX);
                    else
                        offsetVerts.push(verts[v] - offsetY);
                }

                tempMaskSprite.graphics.beginFill(fillColor);
                tempMaskSprite.graphics.drawTriangles(
                    Vector.ofArray(offsetVerts),
                    Vector.ofArray(idxs),
                    null, NONE
                );
                tempMaskSprite.graphics.endFill();
            }
        }

        // Single BitmapData.draw() call instead of one per group
        maskBitmapData.draw(tempMaskSprite, null, null, BlendMode.ADD, null, true);

        return maskBitmapData;
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
        var s:Sprite = cast obj;
        var gfx = s.graphics;

        var bmpData:BitmapData = null;
        if (texture != null)
            bmpData = textureToBitmapData(texture);
        if (bmpData == null) trace('[L2D WHITE] drawShaderTexturedTriangles: null bmpData | texture=$texture');

        // Set diffuse texture
        rendererShader.data.bitmap.input = bmpData;

        // Mask: always set uniforms to avoid stale state
        var useMask = (maskTexture != null && channelFlag != null);
        if (useMask)
        {
            var maskBmp:BitmapData = cast maskTexture;
            rendererShader.data.u_maskTexture.input = maskBmp;
            uniChannelFlagBuf[0] = channelFlag[0];
            uniChannelFlagBuf[1] = channelFlag[1];
            uniChannelFlagBuf[2] = channelFlag[2];
            uniChannelFlagBuf[3] = channelFlag[3];
            rendererShader.data.u_channelFlag.value = uniChannelFlagBuf;
            if (maskOffset != null)
            {
                uniMaskOffsetBuf[0] = maskOffset[0];
                uniMaskOffsetBuf[1] = maskOffset[1];
            }
            else
            {
                uniMaskOffsetBuf[0] = 0.0;
                uniMaskOffsetBuf[1] = 0.0;
            }
            rendererShader.data.u_maskOffset.value = uniMaskOffsetBuf;
            if (maskScale != null)
            {
                uniMaskScaleBuf[0] = maskScale[0];
                uniMaskScaleBuf[1] = maskScale[1];
            }
            else
            {
                uniMaskScaleBuf[0] = 1.0;
                uniMaskScaleBuf[1] = 1.0;
            }
            rendererShader.data.u_maskScale.value = uniMaskScaleBuf;
            rendererShader.data.u_isInverted.value = isInverted ? uniIsInvertedOn : UNI_IS_INVERTED_OFF;
            rendererShader.data.u_useMask.value = UNI_USE_MASK_ON;
        }
        else
        {
            rendererShader.data.u_useMask.value = UNI_USE_MASK_OFF;
            rendererShader.data.u_maskOffset.value = UNI_MASK_OFFSET_ZERO;
            rendererShader.data.u_maskScale.value = UNI_MASK_SCALE_ONE;
            rendererShader.data.u_channelFlag.value = UNI_CHANNEL_FLAG_DEFAULT;
            rendererShader.data.u_isInverted.value = UNI_IS_INVERTED_OFF;
        }

        // Multiply/Screen color: ALWAYS set all three uniforms
        if (mulColor != null && scrColor != null)
        {
            rendererShader.data.u_mulColor.value = mulColor;
            rendererShader.data.u_scrColor.value = scrColor;
            rendererShader.data.u_useColor.value = UNI_USE_COLOR_ON;
        }
        else
        {
            rendererShader.data.u_mulColor.value = UNI_MUL_COLOR_DEFAULT;
            rendererShader.data.u_scrColor.value = UNI_SCR_COLOR_DEFAULT;
            rendererShader.data.u_useColor.value = UNI_USE_COLOR_OFF;
        }

        // Per-drawable opacity: ALWAYS set to avoid stale alpha
        uniOpacityBuf[0] = (opacity != null) ? opacity : 1.0;
        rendererShader.data.u_opacity.value = uniOpacityBuf;

        gfx.beginShaderFill(rendererShader);
        gfx.drawTriangles(
            Vector.ofArray(vertices),
            Vector.ofArray(indices),
            Vector.ofArray(uvs),
            NONE
        );
        gfx.endFill();
    }

    // ===== Drawing (fallback non-shader path) =====

    public function drawTexturedTriangles(obj:L2DDisplayHandle,
        texture:L2DTextureHandle,
        vertices:Array<Float>, uvs:Array<Float>, indices:Array<Int>):Void
    {
        var s:Sprite = cast obj;
        var gfx = s.graphics;

        var bmpData:BitmapData = null;
        if (texture != null)
            bmpData = textureToBitmapData(texture);

        if (bmpData != null)
            gfx.beginBitmapFill(bmpData, null, false, true);
        else
        {
            trace('[L2D WHITE] drawTexturedTriangles: null texture -> white fill | texture=$texture');
            gfx.beginFill(0xFFFFFF, 1.0);
        }

        gfx.drawTriangles(
            Vector.ofArray(vertices),
            Vector.ofArray(indices),
            Vector.ofArray(uvs),
            NONE
        );
        gfx.endFill();
    }

    public function drawSolidTriangles(obj:L2DDisplayHandle,
        vertices:Array<Float>, indices:Array<Int>):Void
    {
        var s:Sprite = cast obj;

        // Fallback mask path: accumulate shapes into temp sprite per mask object,
        // then flush to BitmapData once per group. RT resolution is capped to avoid
        // expensive CPU-side BitmapData.fillRect/draw on large regions.
        if (fbMaskWidth > 0)
        {
            var rtW = Std.int(fbMaskWidth);
            var rtH = Std.int(fbMaskHeight);
            if (rtW > 0 && rtH > 0)
            {
                // Resolution cap: downscale if exceeding max dimension
                var fbScaleX:Float = 1.0;
                var fbScaleY:Float = 1.0;
                if (rtW > FB_MASK_MAX_RES || rtH > FB_MASK_MAX_RES)
                {
                    var maxDim = rtW > rtH ? rtW : rtH;
                    fbScaleX = FB_MASK_MAX_RES / maxDim;
                    fbScaleY = fbScaleX; // uniform scale to preserve aspect
                    rtW = Math.ceil(rtW * fbScaleX);
                    rtH = Math.ceil(rtH * fbScaleY);
                }

                // Flush previous group when target changes
                if (pendingFallbackSprite != null && pendingFallbackSprite != s)
                    flushPendingFallbackRT();

                if (pendingFallbackSprite == null)
                {
                    pendingFallbackSprite = s;

                    // Ensure RT exists at the right size
                    var rt = fallbackMaskRTs.get(s);
                    if (rt == null || rt.width != rtW || rt.height != rtH)
                    {
                        if (rt != null) rt.dispose();
                        rt = new BitmapData(rtW, rtH, true, 0x00000000);
                        fallbackMaskRTs.set(s, rt);
                    }
                    // Clear RT for this frame
                    rt.fillRect(new Rectangle(0, 0, rtW, rtH), 0x00000000);

                    // Start fresh temp sprite for accumulating shapes
                    if (tempFallbackMaskSprite == null)
                        tempFallbackMaskSprite = new Sprite();
                    tempFallbackMaskSprite.graphics.clear();
                }

                // Accumulate shape into temp sprite (RT-local coords with downscale)
                tempFallbackMaskSprite.graphics.beginFill(0xFFFFFF);

                var vertCount = Std.int(vertices.length / 2);
                var rtVerts = new Array<Float>();
                for (v in 0...vertCount)
                {
                    rtVerts.push((vertices[v * 2] - fbMaskMinX) * fbScaleX);
                    rtVerts.push((vertices[v * 2 + 1] - fbMaskMinY) * fbScaleY);
                }

                tempFallbackMaskSprite.graphics.drawTriangles(
                    Vector.ofArray(rtVerts),
                    Vector.ofArray(indices),
                    null, NONE
                );
                tempFallbackMaskSprite.graphics.endFill();
                // Defer BitmapData.draw until flushPendingFallbackRT()
            }
        }
        else
        {
            // Non-fallback: draw to sprite graphics (e.g. main mask RT for groups 0-2,
            // or non-shader path mask objects)
            var gfx = s.graphics;
            gfx.beginFill(0xFFFFFF);
            gfx.drawTriangles(
                Vector.ofArray(vertices),
                Vector.ofArray(indices),
                null,
                NONE
            );
            gfx.endFill();
        }
    }

    /** Flush batched shapes for the current pending mask object to its BitmapData. */
    function flushPendingFallbackRT():Void
    {
        if (pendingFallbackSprite == null) return;
        var rt = fallbackMaskRTs.get(pendingFallbackSprite);
        if (rt != null && tempFallbackMaskSprite != null)
        {
            rt.draw(tempFallbackMaskSprite, null, null, BlendMode.ADD, null, true);
        }
        pendingFallbackSprite = null;
    }

    // ===== Display list =====

    public function setChildIndex(child:L2DDisplayHandle, index:Int):Void
    {
        var s:Sprite = cast child;
        containerSprite.setChildIndex(s, index);
    }

    public function getObjectId(obj:L2DDisplayHandle):Int
    {
        var s:Sprite = cast obj;
        return s.name == null ? 0 : Std.parseInt(s.name);
    }

    public function getContainer():L2DDisplayHandle
    {
        return containerSprite;
    }

    // ===== Helpers =====

    static function blendModeFromValue(val:Int):BlendMode
    {
        return switch (val)
        {
            case 0: BlendMode.NORMAL;
            case 1: BlendMode.ADD;
            case 2: BlendMode.MULTIPLY;
            case 3: BlendMode.ADD;
            case 6: BlendMode.MULTIPLY;
            case 10: BlendMode.SCREEN;
            default: BlendMode.NORMAL;
        }
    }
}

#end