package live2d.cubism.backend.openfl;

#if openfl

import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Sprite;
import openfl.display.TriangleCulling;
import openfl.geom.ColorTransform;
import openfl.Vector;
import live2d.cubism.backend.IL2DRenderer;
import live2d.cubism.backend.L2DDisplayHandle;
import live2d.cubism.backend.L2DTextureHandle;

/**
 * OpenFL implementation of IL2DRenderer.
 * Uses Sprite.graphics.drawTriangles for rendering.
 *
 * Texture loading is injected via constructor to support both
 * plain OpenFL (BitmapData) and Flixel (FlxGraphic) scenarios.
 */
class OpenFLRenderer implements IL2DRenderer
{
    var containerSprite:Sprite;
    var textureLoader:String->L2DTextureHandle;
    var textureDestroyer:L2DTextureHandle->Void;
    var textureToBitmapData:L2DTextureHandle->BitmapData;

    static var defaultColorTransform:ColorTransform = new ColorTransform();

    /**
     * @param textureLoader Function to load a texture from path. Returns L2DTextureHandle.
     * @param textureDestroyer Function to destroy a texture handle.
     * @param textureToBitmapData Function to extract BitmapData from a texture handle.
     */
    public function new(
        ?textureLoader:String->L2DTextureHandle,
        ?textureDestroyer:L2DTextureHandle->Void,
        ?textureToBitmapData:L2DTextureHandle->BitmapData)
    {
        this.textureLoader = textureLoader != null ? textureLoader : defaultTextureLoader;
        this.textureDestroyer = textureDestroyer != null ? textureDestroyer : defaultTextureDestroyer;
        this.textureToBitmapData = textureToBitmapData != null ? textureToBitmapData : defaultTextureToBitmapData;
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
    }

    public function createDisplayObject():L2DDisplayHandle
    {
        var s = new Sprite();
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
        s.transform.colorTransform = new ColorTransform(
            mulR, mulG, mulB, mulA,
            addR, addG, addB, addA
        );
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

    // ===== Drawing =====

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
