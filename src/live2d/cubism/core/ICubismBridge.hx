package live2d.cubism.core;

import haxe.io.Bytes;

/**
 * Native bridge interface for Live2D Cubism C API.
 *
 * Each platform/target provides its own implementation that loads
 * the native library and calls through to the C functions.
 */
interface ICubismBridge
{
    // Framework lifecycle
    function frameworkStartUp():Void;
    function frameworkCleanUp():Void;

    // Model lifecycle
    function loadModel(dir:String, fileName:String):L2DModel;
    function releaseModel(model:L2DModel):Void;

    // Update
    function update(model:L2DModel):Void;
    function setDeltaTime(dt:Float):Void;

    // Parameters
    function getParameterCount(model:L2DModel):Int;
    function findParameterIndex(model:L2DModel, name:String):Int;
    function getParameterValue(model:L2DModel, index:Int):Float;
    function setParameterValue(model:L2DModel, index:Int, value:Float, weight:Float):Void;

    // Animation
    function startMotion(model:L2DModel, group:String, no:Int, priority:Int):Int;
    function startRandomMotion(model:L2DModel, group:String, priority:Int):Int;
    function isMotionFinished(model:L2DModel, handle:Int):Bool;

    // Expression
    function setExpression(model:L2DModel, expressionID:String):Void;
    function setRandomExpression(model:L2DModel):Void;

    // Interaction
    function hitTest(model:L2DModel, areaName:String, x:Float, y:Float):Bool;
    function setDragging(model:L2DModel, x:Float, y:Float):Void;

    // Drawable data
    function getDrawableCount(model:L2DModel):Int;
    function getDrawableVertexCount(model:L2DModel, i:Int):Int;
    function getDrawableVertexPositions(model:L2DModel, i:Int, out:Bytes):Void;
    function getDrawableVertexUvs(model:L2DModel, i:Int, out:Bytes):Void;
    function getDrawableIndexCount(model:L2DModel, i:Int):Int;
    function getDrawableIndices(model:L2DModel, i:Int, out:Bytes):Void;
    function getDrawableOpacity(model:L2DModel, i:Int):Float;
    function getDrawableRenderOrder(model:L2DModel, i:Int):Int;
    function getDrawableTextureIndex(model:L2DModel, i:Int):Int;
    function isDrawableVisible(model:L2DModel, i:Int):Bool;
    function getDrawableMultiplyColor(model:L2DModel, i:Int, out:Bytes):Void;
    function getDrawableScreenColor(model:L2DModel, i:Int, out:Bytes):Void;
    function getDrawableBlendMode(model:L2DModel, i:Int):Int;

    // Mask
    function getDrawableMaskCount(model:L2DModel, i:Int):Int;
    function getDrawableMasks(model:L2DModel, i:Int, out:Bytes):Void;
    function getDrawableInvertedMask(model:L2DModel, i:Int):Bool;
    function isDrawableVertexPositionsDidChange(model:L2DModel, i:Int):Bool;

    // Batch
    function getDrawableBatchMetadata(model:L2DModel, count:Int, out:Bytes):Void;

    // Texture
    function getTextureCount(model:L2DModel):Int;
    function getTexturePath(model:L2DModel, i:Int):String;

    // Model info
    function getCanvasWidth(model:L2DModel):Float;
    function getCanvasHeight(model:L2DModel):Float;

    // Framework behavior control
    function setBreathEnabled(model:L2DModel, enabled:Bool):Void;
    function setEyeBlinkEnabled(model:L2DModel, enabled:Bool):Void;
    function setExpressionEnabled(model:L2DModel, enabled:Bool):Void;
    function setLookEnabled(model:L2DModel, enabled:Bool):Void;
    function setPhysicsEnabled(model:L2DModel, enabled:Bool):Void;
    function setLipSyncEnabled(model:L2DModel, enabled:Bool):Void;
    function setPoseEnabled(model:L2DModel, enabled:Bool):Void;

    // LipSync value (external audio/microphone input)
    function setLipSyncValue(model:L2DModel, value:Float):Void;

    // Motion event polling
    function pollMotionEvents(model:L2DModel, outBuf:Bytes, bufLen:Int):Int;
    function clearMotionEvents(model:L2DModel):Void;

    // Parts
    function getPartCount(model:L2DModel):Int;
    function findPartIndex(model:L2DModel, name:String):Int;
    function getPartId(model:L2DModel, partIndex:Int):String;
    function getPartOpacity(model:L2DModel, partIndex:Int):Float;
    function setPartOpacity(model:L2DModel, partIndex:Int, opacity:Float):Void;

    // Pose reset
    function resetPose(model:L2DModel):Void;

    // Moc version checking
    function getCoreVersion():Int;
    function getLatestMocVersion():Int;
    function hasMocConsistency(mocFilePath:String):Bool;
}
