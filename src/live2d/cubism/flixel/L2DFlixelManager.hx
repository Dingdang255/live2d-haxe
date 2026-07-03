package live2d.cubism.flixel;

#if flixel

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import live2d.cubism.backend.L2DTextureHandle;
import live2d.cubism.core.CubismAPI;

/**
 * Flixel-specific manager for Live2D models with global texture caching.
 *
 * Usage:
 *   var bg = L2DFlixelManager.create('assets/live2d/Haru/', 'Haru.model3.json');
 *   var char = L2DFlixelManager.create('assets/live2d/Mao/', 'Mao.model3.json');
 *   L2DFlixelManager.updateAll(elapsed);
 *   L2DFlixelManager.renderAll();
 *   L2DFlixelManager.destroy(bg);
 */
class L2DFlixelManager
{
    static var models:Array<L2DFlixelComponent> = [];
    static var textureCache:Map<String, FlxGraphic> = new Map();
    static var container:Sprite;
    static var frameworkInit:Bool = false;

    public static function create(dir:String, fileName:String):L2DFlixelComponent
    {
        if (!frameworkInit)
        {
            CubismAPI.frameworkStartUp();
            frameworkInit = true;

            if (container == null)
                container = new Sprite();
        }

        var model = new L2DFlixelComponent(dir, fileName);
        model.core.ownsTextures = false;
        models.push(model);
        return model;
    }

    public static function destroy(model:L2DFlixelComponent):Void
    {
        if (model == null) return;
        models.remove(model);
        model.destroy();
    }

    public static function destroyAll():Void
    {
        for (m in models)
            m.destroy();
        models = [];
    }

    public static function updateAll(elapsed:Float):Void
    {
        CubismAPI.setDeltaTime(elapsed);

        for (m in models)
        {
            if (m.active && m.model.notNull())
                m.update(elapsed);
        }
    }

    public static function renderAll():Void
    {
        for (m in models)
        {
            if (m.visible && m.model.notNull())
                m.render();
        }
    }

    public static function getContainer():Sprite
    {
        return container;
    }

    public static function getCachedTexture(fullPath:String):L2DTextureHandle
    {
        if (textureCache.exists(fullPath))
            return textureCache.get(fullPath);

        #if sys
        var bmpData = BitmapData.fromFile(fullPath);
        if (bmpData != null)
        {
            var graphic = FlxGraphic.fromBitmapData(bmpData, false, fullPath, false);
            textureCache.set(fullPath, graphic);
            return graphic;
        }
        #end

        return null;
    }

    public static function clearTextureCache():Void
    {
        for (graphic in textureCache)
        {
            if (graphic != null) graphic.destroy();
        }
        textureCache.clear();
    }

    public static function getModelCount():Int
    {
        return models.length;
    }

    public static function getModels():Array<L2DFlixelComponent>
    {
        return models;
    }

    public static function getModel(index:Int):L2DFlixelComponent
    {
        if (index < 0 || index >= models.length) return null;
        return models[index];
    }
}

#end
