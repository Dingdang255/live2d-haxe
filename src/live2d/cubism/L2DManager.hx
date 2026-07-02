package live2d.cubism;

import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import openfl.display.Sprite;
import haxe.io.Bytes;
import openfl.display.BitmapData;

/**
 * Live2D Manager
 * Manages multiple L2DComponents with global texture caching
 *
 * Usage:
 *   var bg = L2DManager.create('assets/live2d/Haru/', 'Haru.model3.json');
 *   var char = L2DManager.create('assets/live2d/Mao/', 'Mao.model3.json');
 *   L2DManager.updateAll(elapsed);
 *   L2DManager.renderAll();
 *   L2DManager.destroy(bg);
 */
class L2DManager
{
    // Active models
    static var models:Array<L2DComponent> = [];

    // Global texture cache (key = fullPath)
    static var textureCache:Map<String, FlxGraphic> = new Map();

    // Container sprite for all models
    static var container:Sprite;

    // Framework initialized flag
    static var frameworkInit:Bool = false;

    /**
     * Create a new Live2D model
     * @param dir Model directory (e.g., 'assets/live2d/Haru/')
     * @param fileName Model JSON file (e.g., 'Haru.model3.json')
     * @return L2DComponent instance (also added to models array)
     */
    public static function create(dir:String, fileName:String):L2DComponent
    {
        // Initialize framework once
        if (!frameworkInit)
        {
            L2D.frameworkStartUp();
            frameworkInit = true;

            // Create global container
            if (container == null)
            {
                container = new Sprite();
            }
        }

        var model = new L2DComponentCached(dir, fileName);
        models.push(model);
        return model;
    }

    /**
     * Destroy a specific model
     */
    public static function destroy(model:L2DComponent):Void
    {
        if (model == null) return;

        models.remove(model);
        model.destroy();
    }

    /**
     * Destroy all models
     */
    public static function destroyAll():Void
    {
        for (m in models)
        {
            m.destroy();
        }
        models = [];
    }

    /**
     * Update all models
     */
    public static function updateAll(elapsed:Float):Void
    {
        L2D.setDeltaTime(elapsed);

        for (m in models)
        {
            if (m.active && m.model.notNull())
            {
                m.update(elapsed);
            }
        }
    }

    /**
     * Render all models
     */
    public static function renderAll():Void
    {
        for (m in models)
        {
            if (m.visible && m.model.notNull())
            {
                m.render();
            }
        }
    }

    /**
     * Get global container sprite
     */
    public static function getContainer():Sprite
    {
        return container;
    }

    /**
     * Get cached texture (or load if not cached)
     */
    public static function getCachedTexture(fullPath:String):FlxGraphic
    {
        if (textureCache.exists(fullPath))
        {
            return textureCache.get(fullPath);
        }

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

    /**
     * Clear texture cache (call when changing scenes or freeing memory)
     */
    public static function clearTextureCache():Void
    {
        for (graphic in textureCache)
        {
            if (graphic != null) graphic.destroy();
        }
        textureCache.clear();
    }

    /**
     * Get model count
     */
    public static function getModelCount():Int
    {
        return models.length;
    }

    /**
     * Get all models
     */
    public static function getModels():Array<L2DComponent>
    {
        return models;
    }

    /**
     * Find model by index
     */
    public static function getModel(index:Int):L2DComponent
    {
        if (index < 0 || index >= models.length) return null;
        return models[index];
    }
}

/**
 * L2DComponent with global texture cache support
 */
class L2DComponentCached extends L2DComponent
{
    public function new(dir:String, fileName:String)
    {
        super(dir, fileName);
        ownsTextures = false;
    }

    override function loadTexture(fullPath:String):FlxGraphic
    {
        return L2DManager.getCachedTexture(fullPath);
    }
}
