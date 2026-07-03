package live2d.cubism.flixel;

#if flixel

import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.Vector;
import live2d.cubism.L2DCore;
import live2d.cubism.backend.L2DDisplayHandle;
import live2d.cubism.backend.L2DTextureHandle;
import live2d.cubism.backend.openfl.OpenFLRenderer;
import live2d.cubism.core.CubismAPI;
import live2d.cubism.core.L2DModel;

/**
 * Flixel integration for Live2D models.
 * Wraps L2DCore as a FlxBasic with OpenFL rendering backend.
 */
class L2DFlixelComponent extends FlxBasic
{
    public var core:L2DCore;

    public function new(dir:String, fileName:String)
    {
        super();

        var bridge = CubismAPI.getBridge();
        var renderer = new OpenFLRenderer(
            flixelTextureLoader,
            flixelTextureDestroyer,
            flixelTextureToBitmapData
        );
        core = new L2DCore(dir, fileName, bridge, renderer);
    }

    // ===== Flixel lifecycle =====

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        core.update(elapsed);
    }

    override function destroy():Void
    {
        if (core != null)
        {
            core.destroy();
            core = null;
        }
        super.destroy();
    }

    // ===== Public API (delegated to core) =====

    public function render():Void
    {
        core.render();
    }

    public function getSprite():Sprite
    {
        return cast core.getContainer();
    }

    public var x(get, set):Float;
    function get_x() return core.x;
    function set_x(v) return core.x = v;

    public var y(get, set):Float;
    function get_y() return core.y;
    function set_y(v) return core.y = v;

    public var scale(get, set):Float;
    function get_scale() return core.scale;
    function set_scale(v) return core.scale = v;

    public var alpha(get, set):Float;
    function get_alpha() return core.alpha;
    function set_alpha(v) return core.alpha = v;

    public var model(get, never):L2DModel;
    function get_model() return core.model;

    public var modelDir(get, never):String;
    function get_modelDir() return core.modelDir;

    public var modelFileName(get, never):String;
    function get_modelFileName() return core.modelFileName;

    public var modelWidth(get, never):Float;
    function get_modelWidth() return core.modelWidth;

    public var modelHeight(get, never):Float;
    function get_modelHeight() return core.modelHeight;

    // ===== Convenience API =====

    public function startMotion(group:String, no:Int = 0, priority:Int = 2):Int
        return core.startMotion(group, no, priority);

    public function startIdleMotion():Int
        return core.startIdleMotion();

    public function setExpression(id:String):Void
        core.setExpression(id);

    public function setRandomExpression():Void
        core.setRandomExpression();

    public function hitTest(areaName:String, px:Float, py:Float):Bool
        return core.hitTest(areaName, px, py);

    public function setDragging(screenX:Float, screenY:Float):Void
        core.setDragging(screenX, screenY);

    public function getCanvasWidth():Float
        return core.getCanvasWidth();

    public function getCanvasHeight():Float
        return core.getCanvasHeight();

    // ===== Flixel texture helpers =====

    static function flixelTextureLoader(path:String):L2DTextureHandle
    {
        #if sys
        var bmpData = BitmapData.fromFile(path);
        if (bmpData != null)
            return FlxGraphic.fromBitmapData(bmpData, false, path, false);
        #end
        return null;
    }

    static function flixelTextureDestroyer(tex:L2DTextureHandle):Void
    {
        var g:FlxGraphic = cast tex;
        if (g != null) g.destroy();
    }

    static function flixelTextureToBitmapData(tex:L2DTextureHandle):BitmapData
    {
        var g:FlxGraphic = cast tex;
        if (g != null) return g.bitmap;
        return null;
    }
}

#end
