package live2d.cubism.core;

import haxe.io.Bytes;

/**
 * Static facade for the Live2D Cubism native API.
 * Delegates all calls to a platform-specific ICubismBridge implementation.
 */
class CubismAPI
{
    static var _bridge:ICubismBridge;

    public static function getBridge():ICubismBridge
    {
        if (_bridge == null)
        {
            #if cpp
            _bridge = new live2d.cubism.core.bridge.HxcppWindowsBridge();
            #elseif hl
            _bridge = new live2d.cubism.core.bridge.HlWindowsBridge();
            #else
            throw "No native bridge available for this target";
            #end
        }
        return _bridge;
    }

    public static function setBridge(bridge:ICubismBridge):Void
    {
        _bridge = bridge;
    }

    // ===== Framework =====

    public static function frameworkStartUp():Void
        getBridge().frameworkStartUp();

    public static function frameworkCleanUp():Void
        getBridge().frameworkCleanUp();

    // ===== Lifecycle =====

    public static function loadModel(dir:String, fileName:String):L2DModel
        return getBridge().loadModel(dir, fileName);

    public static function releaseModel(model:L2DModel):Void
        getBridge().releaseModel(model);

    // ===== Update =====

    public static function update(model:L2DModel):Void
        getBridge().update(model);

    public static function setDeltaTime(dt:Float):Void
        getBridge().setDeltaTime(dt);

    // ===== Parameters =====

    public static function getParameterCount(model:L2DModel):Int
        return getBridge().getParameterCount(model);

    public static function findParameterIndex(model:L2DModel, name:String):Int
        return getBridge().findParameterIndex(model, name);

    public static function getParameterValue(model:L2DModel, index:Int):Float
        return getBridge().getParameterValue(model, index);

    public static function setParameterValue(model:L2DModel, index:Int, value:Float, weight:Float = 1.0):Void
        getBridge().setParameterValue(model, index, value, weight);

    // ===== Animation =====

    public static function startMotion(model:L2DModel, group:String, no:Int, priority:Int):Int
        return getBridge().startMotion(model, group, no, priority);

    public static function startRandomMotion(model:L2DModel, group:String, priority:Int):Int
        return getBridge().startRandomMotion(model, group, priority);

    public static function isMotionFinished(model:L2DModel, handle:Int):Bool
        return getBridge().isMotionFinished(model, handle);

    // ===== Expression =====

    public static function setExpression(model:L2DModel, expressionID:String):Void
        getBridge().setExpression(model, expressionID);

    public static function setRandomExpression(model:L2DModel):Void
        getBridge().setRandomExpression(model);

    // ===== Interaction =====

    public static function hitTest(model:L2DModel, areaName:String, x:Float, y:Float):Bool
        return getBridge().hitTest(model, areaName, x, y);

    public static function setDragging(model:L2DModel, x:Float, y:Float):Void
        getBridge().setDragging(model, x, y);

    // ===== Drawable =====

    public static function getDrawableCount(model:L2DModel):Int
        return getBridge().getDrawableCount(model);

    public static function getDrawableVertexCount(model:L2DModel, i:Int):Int
        return getBridge().getDrawableVertexCount(model, i);

    public static function getDrawableVertexPositions(model:L2DModel, i:Int, out:Bytes):Void
        getBridge().getDrawableVertexPositions(model, i, out);

    public static function getDrawableVertexUvs(model:L2DModel, i:Int, out:Bytes):Void
        getBridge().getDrawableVertexUvs(model, i, out);

    public static function getDrawableIndexCount(model:L2DModel, i:Int):Int
        return getBridge().getDrawableIndexCount(model, i);

    public static function getDrawableIndices(model:L2DModel, i:Int, out:Bytes):Void
        getBridge().getDrawableIndices(model, i, out);

    public static function getDrawableOpacity(model:L2DModel, i:Int):Float
        return getBridge().getDrawableOpacity(model, i);

    public static function getDrawableRenderOrder(model:L2DModel, i:Int):Int
        return getBridge().getDrawableRenderOrder(model, i);

    public static function getDrawableTextureIndex(model:L2DModel, i:Int):Int
        return getBridge().getDrawableTextureIndex(model, i);

    public static function isDrawableVisible(model:L2DModel, i:Int):Bool
        return getBridge().isDrawableVisible(model, i);

    public static function getDrawableMultiplyColor(model:L2DModel, i:Int, out:Bytes):Void
        getBridge().getDrawableMultiplyColor(model, i, out);

    public static function getDrawableScreenColor(model:L2DModel, i:Int, out:Bytes):Void
        getBridge().getDrawableScreenColor(model, i, out);

    public static function getDrawableBlendMode(model:L2DModel, i:Int):Int
        return getBridge().getDrawableBlendMode(model, i);

    // ===== Mask =====

    public static function getDrawableMaskCount(model:L2DModel, i:Int):Int
        return getBridge().getDrawableMaskCount(model, i);

    public static function getDrawableMasks(model:L2DModel, i:Int, out:Bytes):Void
        getBridge().getDrawableMasks(model, i, out);

    public static function getDrawableInvertedMask(model:L2DModel, i:Int):Bool
        return getBridge().getDrawableInvertedMask(model, i);

    public static function isDrawableVertexPositionsDidChange(model:L2DModel, i:Int):Bool
        return getBridge().isDrawableVertexPositionsDidChange(model, i);

    // ===== Batch =====

    public static function getDrawableBatchMetadata(model:L2DModel, count:Int, out:Bytes):Void
        getBridge().getDrawableBatchMetadata(model, count, out);

    // ===== Texture =====

    public static function getTextureCount(model:L2DModel):Int
        return getBridge().getTextureCount(model);

    public static function getTexturePath(model:L2DModel, i:Int):String
        return getBridge().getTexturePath(model, i);

    // ===== Model Info =====

    public static function getCanvasWidth(model:L2DModel):Float
        return getBridge().getCanvasWidth(model);

    public static function getCanvasHeight(model:L2DModel):Float
        return getBridge().getCanvasHeight(model);

    // ===== Framework Behavior Control =====

    public static function setBreathEnabled(model:L2DModel, enabled:Bool):Void
        getBridge().setBreathEnabled(model, enabled);

    public static function setEyeBlinkEnabled(model:L2DModel, enabled:Bool):Void
        getBridge().setEyeBlinkEnabled(model, enabled);

    public static function setExpressionEnabled(model:L2DModel, enabled:Bool):Void
        getBridge().setExpressionEnabled(model, enabled);

    public static function setLookEnabled(model:L2DModel, enabled:Bool):Void
        getBridge().setLookEnabled(model, enabled);

    public static function setPhysicsEnabled(model:L2DModel, enabled:Bool):Void
        getBridge().setPhysicsEnabled(model, enabled);

    public static function setLipSyncEnabled(model:L2DModel, enabled:Bool):Void
        getBridge().setLipSyncEnabled(model, enabled);

    public static function setPoseEnabled(model:L2DModel, enabled:Bool):Void
        getBridge().setPoseEnabled(model, enabled);

    // ===== LipSync Value =====

    public static function setLipSyncValue(model:L2DModel, value:Float):Void
        getBridge().setLipSyncValue(model, value);

    // ===== Moc Version Checking =====

    public static function getCoreVersion():Int
        return getBridge().getCoreVersion();

    public static function getLatestMocVersion():Int
        return getBridge().getLatestMocVersion();

    public static function hasMocConsistency(mocFilePath:String):Bool
        return getBridge().hasMocConsistency(mocFilePath);
}
