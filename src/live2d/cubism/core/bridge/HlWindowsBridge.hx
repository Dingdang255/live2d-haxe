package live2d.cubism.core.bridge;

#if hl

import haxe.io.Bytes;
import live2d.cubism.core.ICubismBridge;
import live2d.cubism.core.L2DModel;

/**
 * HashLink + Windows implementation of ICubismBridge.
 * Uses @:hlNative to call through live2d_hl.hdll, which dynamically
 * loads live2d_capi.dll at runtime via LoadLibraryA + GetProcAddress.
 */
class HlWindowsBridge implements ICubismBridge
{
    /** Convert Haxe String (UCS-2) to UTF-8 hl.Bytes for C API consumption. */
    static inline function toUtf8(s:String):hl.Bytes
        return @:privateAccess s.bytes.utf16ToUtf8(0, null);

    public function new()
    {
        hlInit();
    }

    // ===== Framework =====

    public function frameworkStartUp():Void
        hlFrameworkStartUp();

    public function frameworkCleanUp():Void
        hlFrameworkCleanUp();

    // ===== Lifecycle =====

    public function loadModel(dir:String, fileName:String):L2DModel
        return cast hlLoadModel(toUtf8(dir), toUtf8(fileName));

    public function releaseModel(model:L2DModel):Void
        hlReleaseModel(cast model);

    // ===== Update =====

    public function update(model:L2DModel):Void
        hlUpdate(cast model);

    public function setDeltaTime(dt:Float):Void
        hlSetDeltaTime(dt);

    // ===== Parameters =====

    public function getParameterCount(model:L2DModel):Int
        return hlGetParameterCount(cast model);

    public function findParameterIndex(model:L2DModel, name:String):Int
        return hlFindParameterIndex(cast model, toUtf8(name));

    public function getParameterValue(model:L2DModel, index:Int):Float
        return hlGetParameterValue(cast model, index);

    public function setParameterValue(model:L2DModel, index:Int, value:Float, weight:Float):Void
        hlSetParameterValue(cast model, index, value, weight);

    // ===== Animation =====

    public function startMotion(model:L2DModel, group:String, no:Int, priority:Int):Int
        return hlStartMotion(cast model, toUtf8(group), no, priority);

    public function startRandomMotion(model:L2DModel, group:String, priority:Int):Int
        return hlStartRandomMotion(cast model, toUtf8(group), priority);

    public function isMotionFinished(model:L2DModel, handle:Int):Bool
        return hlIsMotionFinished(cast model, handle);

    // ===== Expression =====

    public function setExpression(model:L2DModel, expressionID:String):Void
        hlSetExpression(cast model, toUtf8(expressionID));

    public function setRandomExpression(model:L2DModel):Void
        hlSetRandomExpression(cast model);

    // ===== Interaction =====

    public function hitTest(model:L2DModel, areaName:String, x:Float, y:Float):Bool
        return hlHitTest(cast model, toUtf8(areaName), x, y);

    public function setDragging(model:L2DModel, x:Float, y:Float):Void
        hlSetDragging(cast model, x, y);

    // ===== Drawable =====

    public function getDrawableCount(model:L2DModel):Int
        return hlGetDrawableCount(cast model);

    public function getDrawableVertexCount(model:L2DModel, i:Int):Int
        return hlGetDrawableVertexCount(cast model, i);

    public function getDrawableVertexPositions(model:L2DModel, i:Int, out:Bytes):Void
        hlGetDrawableVertexPositions(cast model, i, @:privateAccess out.b);

    public function getDrawableVertexUvs(model:L2DModel, i:Int, out:Bytes):Void
        hlGetDrawableVertexUvs(cast model, i, @:privateAccess out.b);

    public function getDrawableIndexCount(model:L2DModel, i:Int):Int
        return hlGetDrawableIndexCount(cast model, i);

    public function getDrawableIndices(model:L2DModel, i:Int, out:Bytes):Void
        hlGetDrawableIndices(cast model, i, @:privateAccess out.b);

    public function getDrawableOpacity(model:L2DModel, i:Int):Float
        return hlGetDrawableOpacity(cast model, i);

    public function getDrawableRenderOrder(model:L2DModel, i:Int):Int
        return hlGetDrawableRenderOrder(cast model, i);

    public function getDrawableTextureIndex(model:L2DModel, i:Int):Int
        return hlGetDrawableTextureIndex(cast model, i);

    public function isDrawableVisible(model:L2DModel, i:Int):Bool
        return hlIsDrawableVisible(cast model, i);

    public function getDrawableMultiplyColor(model:L2DModel, i:Int, out:Bytes):Void
        hlGetDrawableMultiplyColor(cast model, i, @:privateAccess out.b);

    public function getDrawableScreenColor(model:L2DModel, i:Int, out:Bytes):Void
        hlGetDrawableScreenColor(cast model, i, @:privateAccess out.b);

    public function getDrawableBlendMode(model:L2DModel, i:Int):Int
        return hlGetDrawableBlendMode(cast model, i);

    // ===== Mask =====

    public function getDrawableMaskCount(model:L2DModel, i:Int):Int
        return hlGetDrawableMaskCount(cast model, i);

    public function getDrawableMasks(model:L2DModel, i:Int, out:Bytes):Void
        hlGetDrawableMasks(cast model, i, @:privateAccess out.b);

    public function getDrawableInvertedMask(model:L2DModel, i:Int):Bool
        return hlGetDrawableInvertedMask(cast model, i);

    public function isDrawableVertexPositionsDidChange(model:L2DModel, i:Int):Bool
        return hlGetDrawableDynamicFlagVertexPositionsDidChange(cast model, i);

    // ===== Batch =====

    public function getDrawableBatchMetadata(model:L2DModel, count:Int, out:Bytes):Void
        hlGetDrawableBatchMetadata(cast model, count, @:privateAccess out.b);

    // ===== Texture =====

    public function getTextureCount(model:L2DModel):Int
        return hlGetTextureCount(cast model);

    public function getTexturePath(model:L2DModel, i:Int):String
    {
        var buf = Bytes.alloc(512);
        hlGetTexturePath(cast model, i, @:privateAccess buf.b, 512);
        var len = 0;
        while (len < 512 && buf.get(len) != 0) len++;
        return buf.getString(0, len);
    }

    // ===== Model Info =====

    public function getCanvasWidth(model:L2DModel):Float
        return hlGetCanvasWidth(cast model);

    public function getCanvasHeight(model:L2DModel):Float
        return hlGetCanvasHeight(cast model);

    // ===== Framework Behavior Control =====

    public function setBreathEnabled(model:L2DModel, enabled:Bool):Void
        hlSetBreathEnabled(cast model, enabled);

    public function setEyeBlinkEnabled(model:L2DModel, enabled:Bool):Void
        hlSetEyeBlinkEnabled(cast model, enabled);

    public function setExpressionEnabled(model:L2DModel, enabled:Bool):Void
        hlSetExpressionEnabled(cast model, enabled);

    public function setLookEnabled(model:L2DModel, enabled:Bool):Void
        hlSetLookEnabled(cast model, enabled);

    public function setPhysicsEnabled(model:L2DModel, enabled:Bool):Void
        hlSetPhysicsEnabled(cast model, enabled);

    public function setLipSyncEnabled(model:L2DModel, enabled:Bool):Void
        hlSetLipSyncEnabled(cast model, enabled);

    public function setPoseEnabled(model:L2DModel, enabled:Bool):Void
        hlSetPoseEnabled(cast model, enabled);

    // ===== LipSync Value =====

    public function setLipSyncValue(model:L2DModel, value:Float):Void
        hlSetLipSyncValue(cast model, value);

    // ===== Moc Version Checking =====

    public function getCoreVersion():Int
        return hlGetCoreVersion();

    public function getLatestMocVersion():Int
        return hlGetLatestMocVersion();

    public function hasMocConsistency(mocFilePath:String):Bool
        return hlHasMocConsistency(toUtf8(mocFilePath));

    // ============================================================
    // @:hlNative bindings to live2d_hl.hdll
    // ============================================================

    @:hlNative("live2d_hl", "init")                                          static function hlInit():Void {}
    @:hlNative("live2d_hl", "framework_start_up")                            static function hlFrameworkStartUp():Void {}
    @:hlNative("live2d_hl", "framework_clean_up")                            static function hlFrameworkCleanUp():Void {}
    @:hlNative("live2d_hl", "load_model")                                    static function hlLoadModel(dir:hl.Bytes, fileName:hl.Bytes):hl.I64 return 0;
    @:hlNative("live2d_hl", "release_model")                                 static function hlReleaseModel(model:hl.I64):Void {}
    @:hlNative("live2d_hl", "update")                                        static function hlUpdate(model:hl.I64):Void {}
    @:hlNative("live2d_hl", "set_delta_time")                                static function hlSetDeltaTime(dt:Float):Void {}
    @:hlNative("live2d_hl", "get_parameter_count")                           static function hlGetParameterCount(model:hl.I64):Int return 0;
    @:hlNative("live2d_hl", "find_parameter_index")                          static function hlFindParameterIndex(model:hl.I64, name:hl.Bytes):Int return -1;
    @:hlNative("live2d_hl", "get_parameter_value")                           static function hlGetParameterValue(model:hl.I64, index:Int):Float return 0;
    @:hlNative("live2d_hl", "set_parameter_value")                           static function hlSetParameterValue(model:hl.I64, index:Int, value:Float, weight:Float):Void {}
    @:hlNative("live2d_hl", "start_motion")                                  static function hlStartMotion(model:hl.I64, group:hl.Bytes, no:Int, priority:Int):Int return -1;
    @:hlNative("live2d_hl", "start_random_motion")                           static function hlStartRandomMotion(model:hl.I64, group:hl.Bytes, priority:Int):Int return -1;
    @:hlNative("live2d_hl", "is_motion_finished")                            static function hlIsMotionFinished(model:hl.I64, handle:Int):Bool return true;
    @:hlNative("live2d_hl", "set_expression")                                static function hlSetExpression(model:hl.I64, expressionID:hl.Bytes):Void {}
    @:hlNative("live2d_hl", "set_random_expression")                         static function hlSetRandomExpression(model:hl.I64):Void {}
    @:hlNative("live2d_hl", "hit_test")                                      static function hlHitTest(model:hl.I64, areaName:hl.Bytes, x:Float, y:Float):Bool return false;
    @:hlNative("live2d_hl", "set_dragging")                                  static function hlSetDragging(model:hl.I64, x:Float, y:Float):Void {}
    @:hlNative("live2d_hl", "get_drawable_count")                            static function hlGetDrawableCount(model:hl.I64):Int return 0;
    @:hlNative("live2d_hl", "get_drawable_vertex_count")                     static function hlGetDrawableVertexCount(model:hl.I64, i:Int):Int return 0;
    @:hlNative("live2d_hl", "get_drawable_vertex_positions")                 static function hlGetDrawableVertexPositions(model:hl.I64, i:Int, out:hl.Bytes):Void {}
    @:hlNative("live2d_hl", "get_drawable_vertex_uvs")                       static function hlGetDrawableVertexUvs(model:hl.I64, i:Int, out:hl.Bytes):Void {}
    @:hlNative("live2d_hl", "get_drawable_index_count")                      static function hlGetDrawableIndexCount(model:hl.I64, i:Int):Int return 0;
    @:hlNative("live2d_hl", "get_drawable_indices")                          static function hlGetDrawableIndices(model:hl.I64, i:Int, out:hl.Bytes):Void {}
    @:hlNative("live2d_hl", "get_drawable_opacity")                          static function hlGetDrawableOpacity(model:hl.I64, i:Int):Float return 0;
    @:hlNative("live2d_hl", "get_drawable_render_order")                     static function hlGetDrawableRenderOrder(model:hl.I64, i:Int):Int return 0;
    @:hlNative("live2d_hl", "get_drawable_texture_index")                    static function hlGetDrawableTextureIndex(model:hl.I64, i:Int):Int return -1;
    @:hlNative("live2d_hl", "is_drawable_visible")                           static function hlIsDrawableVisible(model:hl.I64, i:Int):Bool return false;
    @:hlNative("live2d_hl", "get_drawable_multiply_color")                   static function hlGetDrawableMultiplyColor(model:hl.I64, i:Int, out:hl.Bytes):Void {}
    @:hlNative("live2d_hl", "get_drawable_screen_color")                     static function hlGetDrawableScreenColor(model:hl.I64, i:Int, out:hl.Bytes):Void {}
    @:hlNative("live2d_hl", "get_drawable_blend_mode")                       static function hlGetDrawableBlendMode(model:hl.I64, i:Int):Int return 0;
    @:hlNative("live2d_hl", "get_drawable_mask_count")                       static function hlGetDrawableMaskCount(model:hl.I64, i:Int):Int return 0;
    @:hlNative("live2d_hl", "get_drawable_masks")                            static function hlGetDrawableMasks(model:hl.I64, i:Int, out:hl.Bytes):Void {}
    @:hlNative("live2d_hl", "get_drawable_inverted_mask")                    static function hlGetDrawableInvertedMask(model:hl.I64, i:Int):Bool return false;
    @:hlNative("live2d_hl", "get_drawable_dynamic_flag_vertex_positions_did_change") static function hlGetDrawableDynamicFlagVertexPositionsDidChange(model:hl.I64, i:Int):Bool return false;
    @:hlNative("live2d_hl", "get_drawable_batch_metadata")                   static function hlGetDrawableBatchMetadata(model:hl.I64, count:Int, out:hl.Bytes):Void {}
    @:hlNative("live2d_hl", "get_texture_count")                             static function hlGetTextureCount(model:hl.I64):Int return 0;
    @:hlNative("live2d_hl", "get_texture_path")                              static function hlGetTexturePath(model:hl.I64, i:Int, out:hl.Bytes, bufLen:Int):Void {}
    @:hlNative("live2d_hl", "get_canvas_width")                              static function hlGetCanvasWidth(model:hl.I64):Float return 0;
    @:hlNative("live2d_hl", "get_canvas_height")                             static function hlGetCanvasHeight(model:hl.I64):Float return 0;
    @:hlNative("live2d_hl", "set_breath_enabled")                            static function hlSetBreathEnabled(model:hl.I64, enabled:Bool):Void {}
    @:hlNative("live2d_hl", "set_eye_blink_enabled")                         static function hlSetEyeBlinkEnabled(model:hl.I64, enabled:Bool):Void {}
    @:hlNative("live2d_hl", "set_expression_enabled")                        static function hlSetExpressionEnabled(model:hl.I64, enabled:Bool):Void {}
    @:hlNative("live2d_hl", "set_look_enabled")                              static function hlSetLookEnabled(model:hl.I64, enabled:Bool):Void {}
    @:hlNative("live2d_hl", "set_physics_enabled")                           static function hlSetPhysicsEnabled(model:hl.I64, enabled:Bool):Void {}
    @:hlNative("live2d_hl", "set_lip_sync_enabled")                          static function hlSetLipSyncEnabled(model:hl.I64, enabled:Bool):Void {}
    @:hlNative("live2d_hl", "set_pose_enabled")                              static function hlSetPoseEnabled(model:hl.I64, enabled:Bool):Void {}
    @:hlNative("live2d_hl", "set_lip_sync_value")                            static function hlSetLipSyncValue(model:hl.I64, value:Float):Void {}
    @:hlNative("live2d_hl", "get_core_version")                              static function hlGetCoreVersion():Int return 0;
    @:hlNative("live2d_hl", "get_latest_moc_version")                        static function hlGetLatestMocVersion():Int return 0;
    @:hlNative("live2d_hl", "has_moc_consistency")                           static function hlHasMocConsistency(path:hl.Bytes):Bool return false;
}

#end
