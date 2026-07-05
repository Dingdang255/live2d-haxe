package live2d.cubism.backend.openfl;

#if openfl

import openfl.display.Bitmap;
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
    var debugMaskBitmap:Bitmap;

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

    public function setMask(obj:L2DDisplayHandle, mask:L2DDisplayHandle):Void
    {
        var s:Sprite = cast obj;
        var maskSprite:Sprite = cast mask;
        s.mask = maskSprite;
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

    /** Show mask texture for debugging */
    public function showDebugMaskTexture():Void
    {
        if (maskBitmapData != null)
        {
            if (debugMaskBitmap == null)
            {
                debugMaskBitmap = new Bitmap(maskBitmapData);
                debugMaskBitmap.x = 0;
                debugMaskBitmap.y = 0;
                debugMaskBitmap.scaleX = 0.5;
                debugMaskBitmap.scaleY = 0.5;
                containerSprite.addChild(debugMaskBitmap);
            }
            else
            {
                debugMaskBitmap.bitmapData = maskBitmapData;
            }
        }
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
            gfx.beginFill(0xFFFFFF, 1.0);

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