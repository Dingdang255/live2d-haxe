package live2d.cubism.core.bridge;

#if cpp

import haxe.io.Bytes;
import live2d.cubism.core.ICubismBridge;
import live2d.cubism.core.L2DModel;

/**
 * hxcpp + Windows implementation of ICubismBridge.
 * Uses GetProcAddress to load function pointers from live2d_capi.dll at runtime.
 */
@:keep
@:cppFileCode('
#include <windows.h>
struct L2DFunctions {
    void (*framework_start_up)();
    void (*framework_clean_up)();
    void* (*load_model)(const char*, const char*);
    void (*update)(void*);
    void (*set_delta_time)(float);
    void (*release_model)(void*);
    int (*get_drawable_count)(void*);
    int (*get_drawable_vertex_count)(void*, int);
    void (*get_drawable_vertex_positions)(void*, int, float*);
    void (*get_drawable_vertex_uvs)(void*, int, float*);
    int (*get_drawable_index_count)(void*, int);
    void (*get_drawable_indices)(void*, int, uint16_t*);
    int (*get_texture_count)(void*);
    void (*get_texture_path)(void*, int, char*, int);
    float (*get_canvas_width)(void*);
    float (*get_canvas_height)(void*);
    intptr_t (*start_motion)(void*, const char*, int, int);
    intptr_t (*start_random_motion)(void*, const char*, int);
    intptr_t (*start_motion_file)(void*, const char*, int);
    bool (*is_motion_finished)(void*, intptr_t);
    void (*stop_all_motions)(void*);
    void (*set_expression)(void*, const char*);
    void (*set_random_expression)(void*);
    bool (*hit_test)(void*, const char*, float, float);
    void (*set_dragging)(void*, float, float);
    int (*get_parameter_count)(void*);
    int (*find_parameter_index)(void*, const char*);
    float (*get_parameter_value)(void*, int);
    void (*set_parameter_value)(void*, int, float, float);
    int (*get_drawable_mask_count)(void*, int);
    void (*get_drawable_masks)(void*, int, int*);
    bool (*get_drawable_inverted_mask)(void*, int);
    void (*get_drawable_batch_metadata)(void*, int, char*);
    void (*set_breath_enabled)(void*, bool);
    void (*set_eye_blink_enabled)(void*, bool);
    void (*set_expression_enabled)(void*, bool);
    void (*set_look_enabled)(void*, bool);
    void (*set_physics_enabled)(void*, bool);
    void (*set_lip_sync_enabled)(void*, bool);
    void (*set_pose_enabled)(void*, bool);
    void (*set_lip_sync_value)(void*, float);
    unsigned int (*get_core_version)();
    unsigned int (*get_latest_moc_version)();
    bool (*has_moc_consistency)(const char*);
    int (*poll_motion_events)(void*, char*, int);
    void (*clear_motion_events)(void*);
    int (*get_part_count)(void*);
    int (*find_part_index)(void*, const char*);
    void (*get_part_id)(void*, int, char*, int);
    float (*get_part_opacity)(void*, int);
    void (*set_part_opacity)(void*, int, float);
    void (*reset_pose)(void*);
    void (*set_physics_options)(void*, float, float, float, float);
    void (*get_physics_options)(void*, float*, float*, float*, float*);
    void (*reset_physics)(void*);
    void (*stabilize_physics)(void*);
    bool loaded;
};
static L2DFunctions l2dFn = {0};

static void l2d_ensure_loaded() {
    if (l2dFn.loaded) return;
    HMODULE h = GetModuleHandleA("live2d_capi");
    if (!h) h = LoadLibraryA("live2d_capi");
    if (!h) return;
    #define L2D_LOAD(name) l2dFn.name = (decltype(l2dFn.name))GetProcAddress(h, "l2d_" #name)
    L2D_LOAD(framework_start_up);
    L2D_LOAD(framework_clean_up);
    L2D_LOAD(load_model);
    L2D_LOAD(update);
    L2D_LOAD(set_delta_time);
    L2D_LOAD(release_model);
    L2D_LOAD(get_drawable_count);
    L2D_LOAD(get_drawable_vertex_count);
    L2D_LOAD(get_drawable_vertex_positions);
    L2D_LOAD(get_drawable_vertex_uvs);
    L2D_LOAD(get_drawable_index_count);
    L2D_LOAD(get_drawable_indices);
    L2D_LOAD(get_texture_count);
    L2D_LOAD(get_texture_path);
    L2D_LOAD(get_canvas_width);
    L2D_LOAD(get_canvas_height);
    L2D_LOAD(start_motion);
    L2D_LOAD(start_random_motion);
    L2D_LOAD(start_motion_file);
    L2D_LOAD(is_motion_finished);
    L2D_LOAD(stop_all_motions);
    L2D_LOAD(set_expression);
    L2D_LOAD(set_random_expression);
    L2D_LOAD(hit_test);
    L2D_LOAD(set_dragging);
    L2D_LOAD(get_parameter_count);
    L2D_LOAD(find_parameter_index);
    L2D_LOAD(get_parameter_value);
    L2D_LOAD(set_parameter_value);
    L2D_LOAD(get_drawable_mask_count);
    L2D_LOAD(get_drawable_masks);
    L2D_LOAD(get_drawable_inverted_mask);
    L2D_LOAD(get_drawable_batch_metadata);
    L2D_LOAD(set_breath_enabled);
    L2D_LOAD(set_eye_blink_enabled);
    L2D_LOAD(set_expression_enabled);
    L2D_LOAD(set_look_enabled);
    L2D_LOAD(set_physics_enabled);
    L2D_LOAD(set_lip_sync_enabled);
    L2D_LOAD(set_pose_enabled);
    L2D_LOAD(set_lip_sync_value);
    L2D_LOAD(get_core_version);
    L2D_LOAD(get_latest_moc_version);
    L2D_LOAD(has_moc_consistency);
    L2D_LOAD(poll_motion_events);
    L2D_LOAD(clear_motion_events);
    L2D_LOAD(get_part_count);
    L2D_LOAD(find_part_index);
    L2D_LOAD(get_part_id);
    L2D_LOAD(get_part_opacity);
    L2D_LOAD(set_part_opacity);
    L2D_LOAD(reset_pose);
    L2D_LOAD(set_physics_options);
    L2D_LOAD(get_physics_options);
    L2D_LOAD(reset_physics);
    L2D_LOAD(stabilize_physics);
    #undef L2D_LOAD
    l2dFn.loaded = true;
}
static inline void* M(cpp::Int64 m) { return (void*)(intptr_t)m; }
static inline cpp::Int64 P(void* p) { return (cpp::Int64)(intptr_t)p; }
')
class HxcppWindowsBridge implements ICubismBridge
{
    static inline function m(v:L2DModel):cpp.Int64 return cast v;

    public function new() {}

    // ===== Framework =====

    public function frameworkStartUp():Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.framework_start_up) l2dFn.framework_start_up()');
    }

    public function frameworkCleanUp():Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.framework_clean_up) l2dFn.framework_clean_up()');
    }

    // ===== Lifecycle =====

    public function loadModel(dir:String, fileName:String):L2DModel
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.load_model ? P(l2dFn.load_model({0}.utf8_str(), {1}.utf8_str())) : (cpp::Int64)0)', dir, fileName);
    }

    public function releaseModel(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.release_model) l2dFn.release_model(M((cpp::Int64){0}))', m(model));
    }

    // ===== Update =====

    public function update(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.update) l2dFn.update(M((cpp::Int64){0}))', m(model));
    }

    public function setDeltaTime(dt:Float):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_delta_time) l2dFn.set_delta_time({0})', dt);
    }

    // ===== Parameters =====

    public function getParameterCount(model:L2DModel):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_parameter_count ? l2dFn.get_parameter_count(M((cpp::Int64){0})) : 0)', m(model));
    }

    public function findParameterIndex(model:L2DModel, name:String):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.find_parameter_index ? l2dFn.find_parameter_index(M((cpp::Int64){0}), {1}.utf8_str()) : -1)', m(model), name);
    }

    public function getParameterValue(model:L2DModel, index:Int):Float
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_parameter_value ? l2dFn.get_parameter_value(M((cpp::Int64){0}), {1}) : 0.0f)', m(model), index);
    }

    public function setParameterValue(model:L2DModel, index:Int, value:Float, weight:Float):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_parameter_value) l2dFn.set_parameter_value(M((cpp::Int64){0}), {1}, {2}, {3})', m(model), index, value, weight);
    }

    // ===== Animation =====

    public function startMotion(model:L2DModel, group:String, no:Int, priority:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.start_motion ? (int)l2dFn.start_motion(M((cpp::Int64){0}), {1}.utf8_str(), {2}, {3}) : -1)', m(model), group, no, priority);
    }

    public function startRandomMotion(model:L2DModel, group:String, priority:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.start_random_motion ? (int)l2dFn.start_random_motion(M((cpp::Int64){0}), {1}.utf8_str(), {2}) : -1)', m(model), group, priority);
    }

    public function startMotionFile(model:L2DModel, path:String, priority:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.start_motion_file ? (int)l2dFn.start_motion_file(M((cpp::Int64){0}), {1}.utf8_str(), {2}) : -1)', m(model), path, priority);
    }

    public function isMotionFinished(model:L2DModel, handle:Int):Bool
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.is_motion_finished ? l2dFn.is_motion_finished(M((cpp::Int64){0}), (intptr_t){1}) : true)', m(model), handle);
    }

    public function stopAllMotions(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.stop_all_motions) l2dFn.stop_all_motions(M((cpp::Int64){0}))', m(model));
    }

    // ===== Expression =====

    public function setExpression(model:L2DModel, expressionID:String):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_expression) l2dFn.set_expression(M((cpp::Int64){0}), {1}.utf8_str())', m(model), expressionID);
    }

    public function setRandomExpression(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_random_expression) l2dFn.set_random_expression(M((cpp::Int64){0}))', m(model));
    }

    // ===== Interaction =====

    public function hitTest(model:L2DModel, areaName:String, x:Float, y:Float):Bool
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.hit_test ? l2dFn.hit_test(M((cpp::Int64){0}), {1}.utf8_str(), {2}, {3}) : false)', m(model), areaName, x, y);
    }

    public function setDragging(model:L2DModel, x:Float, y:Float):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_dragging) l2dFn.set_dragging(M((cpp::Int64){0}), {1}, {2})', m(model), x, y);
    }

    // ===== Drawable =====

    public function getDrawableCount(model:L2DModel):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_count ? l2dFn.get_drawable_count(M((cpp::Int64){0})) : 0)', m(model));
    }

    public function getDrawableVertexCount(model:L2DModel, i:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_vertex_count ? l2dFn.get_drawable_vertex_count(M((cpp::Int64){0}), {1}) : 0)', m(model), i);
    }

    public function getDrawableVertexPositions(model:L2DModel, i:Int, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_drawable_vertex_positions) l2dFn.get_drawable_vertex_positions(M((cpp::Int64){0}), {1}, (float*)({2}->b.mPtr->GetBase()))', m(model), i, out);
    }

    public function getDrawableVertexUvs(model:L2DModel, i:Int, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_drawable_vertex_uvs) l2dFn.get_drawable_vertex_uvs(M((cpp::Int64){0}), {1}, (float*)({2}->b.mPtr->GetBase()))', m(model), i, out);
    }

    public function getDrawableIndexCount(model:L2DModel, i:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_index_count ? l2dFn.get_drawable_index_count(M((cpp::Int64){0}), {1}) : 0)', m(model), i);
    }

    public function getDrawableIndices(model:L2DModel, i:Int, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_drawable_indices) l2dFn.get_drawable_indices(M((cpp::Int64){0}), {1}, (uint16_t*)({2}->b.mPtr->GetBase()))', m(model), i, out);
    }

    // ===== Mask =====

    public function getDrawableMaskCount(model:L2DModel, i:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_mask_count ? l2dFn.get_drawable_mask_count(M((cpp::Int64){0}), {1}) : 0)', m(model), i);
    }

    public function getDrawableMasks(model:L2DModel, i:Int, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_drawable_masks) l2dFn.get_drawable_masks(M((cpp::Int64){0}), {1}, (int*)({2}->b.mPtr->GetBase()))', m(model), i, out);
    }

    public function getDrawableInvertedMask(model:L2DModel, i:Int):Bool
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_inverted_mask ? l2dFn.get_drawable_inverted_mask(M((cpp::Int64){0}), {1}) : false)', m(model), i);
    }

    public function getDrawableBatchMetadata(model:L2DModel, count:Int, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_drawable_batch_metadata) l2dFn.get_drawable_batch_metadata(M((cpp::Int64){0}), {1}, (char*)({2}->b.mPtr->GetBase()))', m(model), count, out);
    }

    // ===== Texture =====

    public function getTextureCount(model:L2DModel):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_texture_count ? l2dFn.get_texture_count(M((cpp::Int64){0})) : 0)', m(model));
    }

    public function getTexturePath(model:L2DModel, i:Int):String
    {
        var buf = Bytes.alloc(512);
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_texture_path) l2dFn.get_texture_path(M((cpp::Int64){0}), {1}, (char*)({2}->b.mPtr->GetBase()), 512)', m(model), i, buf);
        var len = 0;
        while (len < 512 && buf.get(len) != 0) len++;
        return buf.getString(0, len);
    }

    // ===== Model Info =====

    public function getCanvasWidth(model:L2DModel):Float
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_canvas_width ? l2dFn.get_canvas_width(M((cpp::Int64){0})) : 0.0f)', m(model));
    }

    public function getCanvasHeight(model:L2DModel):Float
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_canvas_height ? l2dFn.get_canvas_height(M((cpp::Int64){0})) : 0.0f)', m(model));
    }

    // ===== Framework Behavior Control =====

    public function setBreathEnabled(model:L2DModel, enabled:Bool):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_breath_enabled) l2dFn.set_breath_enabled(M((cpp::Int64){0}), {1})', m(model), enabled);
    }

    public function setEyeBlinkEnabled(model:L2DModel, enabled:Bool):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_eye_blink_enabled) l2dFn.set_eye_blink_enabled(M((cpp::Int64){0}), {1})', m(model), enabled);
    }

    public function setExpressionEnabled(model:L2DModel, enabled:Bool):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_expression_enabled) l2dFn.set_expression_enabled(M((cpp::Int64){0}), {1})', m(model), enabled);
    }

    public function setLookEnabled(model:L2DModel, enabled:Bool):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_look_enabled) l2dFn.set_look_enabled(M((cpp::Int64){0}), {1})', m(model), enabled);
    }

    public function setPhysicsEnabled(model:L2DModel, enabled:Bool):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_physics_enabled) l2dFn.set_physics_enabled(M((cpp::Int64){0}), {1})', m(model), enabled);
    }

    public function setLipSyncEnabled(model:L2DModel, enabled:Bool):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_lip_sync_enabled) l2dFn.set_lip_sync_enabled(M((cpp::Int64){0}), {1})', m(model), enabled);
    }

    public function setPoseEnabled(model:L2DModel, enabled:Bool):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_pose_enabled) l2dFn.set_pose_enabled(M((cpp::Int64){0}), {1})', m(model), enabled);
    }

    // ===== LipSync Value =====

    public function setLipSyncValue(model:L2DModel, value:Float):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_lip_sync_value) l2dFn.set_lip_sync_value(M((cpp::Int64){0}), {1})', m(model), value);
    }

    // ===== Moc Version Checking =====

    public function getCoreVersion():Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_core_version ? (int)l2dFn.get_core_version() : 0)');
    }

    public function getLatestMocVersion():Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_latest_moc_version ? (int)l2dFn.get_latest_moc_version() : 0)');
    }

    public function hasMocConsistency(mocFilePath:String):Bool
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.has_moc_consistency ? l2dFn.has_moc_consistency({0}.utf8_str()) : false)', mocFilePath);
    }

    // ===== Motion Event Polling =====

    public function pollMotionEvents(model:L2DModel, outBuf:Bytes, bufLen:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.poll_motion_events ? l2dFn.poll_motion_events(M((cpp::Int64){0}), (char*)({1}->b.mPtr->GetBase()), {2}) : 0)', m(model), outBuf, bufLen);
    }

    public function clearMotionEvents(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.clear_motion_events) l2dFn.clear_motion_events(M((cpp::Int64){0}))', m(model));
    }

    // ===== Parts =====

    public function getPartCount(model:L2DModel):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_part_count ? l2dFn.get_part_count(M((cpp::Int64){0})) : 0)', m(model));
    }

    public function findPartIndex(model:L2DModel, name:String):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.find_part_index ? l2dFn.find_part_index(M((cpp::Int64){0}), {1}.utf8_str()) : -1)', m(model), name);
    }

    public function getPartId(model:L2DModel, partIndex:Int):String
    {
        var buf = Bytes.alloc(256);
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_part_id) l2dFn.get_part_id(M((cpp::Int64){0}), {1}, (char*)({2}->b.mPtr->GetBase()), 256)', m(model), partIndex, buf);
        var len = 0;
        while (len < 256 && buf.get(len) != 0) len++;
        return buf.getString(0, len);
    }

    public function getPartOpacity(model:L2DModel, partIndex:Int):Float
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_part_opacity ? l2dFn.get_part_opacity(M((cpp::Int64){0}), {1}) : 0.0f)', m(model), partIndex);
    }

    public function setPartOpacity(model:L2DModel, partIndex:Int, opacity:Float):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_part_opacity) l2dFn.set_part_opacity(M((cpp::Int64){0}), {1}, {2})', m(model), partIndex, opacity);
    }

    // ===== Pose Reset =====

    public function resetPose(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.reset_pose) l2dFn.reset_pose(M((cpp::Int64){0}))', m(model));
    }

    // ===== Physics Runtime Tuning =====

    public function setPhysicsOptions(model:L2DModel, gravityX:Float, gravityY:Float, windX:Float, windY:Float):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_physics_options) l2dFn.set_physics_options(M((cpp::Int64){0}), {1}, {2}, {3}, {4})', m(model), gravityX, gravityY, windX, windY);
    }

    // out: 16 bytes, layout [gx, gy, wx, wy] as float32 LE
    public function getPhysicsOptions(model:L2DModel, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_physics_options) { float gx=0.0f, gy=-1.0f, wx=0.0f, wy=0.0f; l2dFn.get_physics_options(M((cpp::Int64){0}), &gx, &gy, &wx, &wy); float* o = (float*)({1}->b.mPtr->GetBase()); o[0]=gx; o[1]=gy; o[2]=wx; o[3]=wy; }', m(model), out);
    }

    public function resetPhysics(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.reset_physics) l2dFn.reset_physics(M((cpp::Int64){0}))', m(model));
    }

    public function stabilizePhysics(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.stabilize_physics) l2dFn.stabilize_physics(M((cpp::Int64){0}))', m(model));
    }
}

#end
