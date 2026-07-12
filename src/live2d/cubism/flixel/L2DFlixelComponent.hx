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
import live2d.cubism.core.L2DModel;
import live2d.cubism.ext.L2DPhysicsTuner;

/**
 * Flixel integration for Live2D models.
 * Wraps L2DCore as a FlxBasic with OpenFL rendering backend.
 */
class L2DFlixelComponent extends FlxBasic
{
    public var core:L2DCore;
    /** Optional physics tuner for runtime gravity/wind/strength adjustment. */
    public var physicsTuner:L2DPhysicsTuner;

    public function new(dir:String, fileName:String)
    {
        super();

        var renderer = new OpenFLRenderer(
            flixelTextureLoader,
            flixelTextureDestroyer,
            flixelTextureToBitmapData
        );
        core = new L2DCore(dir, fileName, renderer);
    }

    // ===== Flixel lifecycle =====

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (physicsTuner != null) physicsTuner.applyPreUpdate();
        core.update(elapsed);
        if (physicsTuner != null) physicsTuner.applyPostUpdate();
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
