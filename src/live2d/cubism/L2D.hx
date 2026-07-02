package live2d.cubism;

import haxe.io.Bytes;

/**
 * Live2D C API Binding
 * Uses GetProcAddress direct DLL calls (bypassing hxcpp FFI)
 *
 * This class embeds C++ code via @:cppFileCode to load function pointers
 * from live2d_capi.dll at runtime. This approach avoids hxcpp FFI crashes.
 */
@:keep
@:cppFileCode('
#include <windows.h>
// All function pointers cached in a single struct
struct L2DFunctions {
    int (*test_add)(int, int);
    void (*framework_start_up)();
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
    float (*get_drawable_opacity)(void*, int);
    int (*get_drawable_render_order)(void*, int);
    int (*get_drawable_texture_index)(void*, int);
    bool (*is_drawable_visible)(void*, int);
    int (*get_texture_count)(void*);
    void (*get_texture_path)(void*, int, char*, int);
    float (*get_canvas_width)(void*);
    float (*get_canvas_height)(void*);
    intptr_t (*start_motion)(void*, const char*, int, int);
    intptr_t (*start_random_motion)(void*, const char*, int);
    bool (*is_motion_finished)(void*, intptr_t);
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
    bool loaded;
};
static L2DFunctions l2dFn = {0};

static void l2d_ensure_loaded() {
    if (l2dFn.loaded) return;
    HMODULE h = GetModuleHandleA("live2d_capi");
    if (!h) h = LoadLibraryA("live2d_capi");
    if (!h) return;
    #define L2D_LOAD(name) l2dFn.name = (decltype(l2dFn.name))GetProcAddress(h, "l2d_" #name)
    L2D_LOAD(test_add);
    L2D_LOAD(framework_start_up);
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
    L2D_LOAD(get_drawable_opacity);
    L2D_LOAD(get_drawable_render_order);
    L2D_LOAD(get_drawable_texture_index);
    L2D_LOAD(is_drawable_visible);
    L2D_LOAD(get_texture_count);
    L2D_LOAD(get_texture_path);
    L2D_LOAD(get_canvas_width);
    L2D_LOAD(get_canvas_height);
    L2D_LOAD(start_motion);
    L2D_LOAD(start_random_motion);
    L2D_LOAD(is_motion_finished);
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
    #undef L2D_LOAD
    l2dFn.loaded = true;
}
// Helper: Int64 model handle -> void*
static inline void* M(cpp::Int64 m) { return (void*)(intptr_t)m; }
// Helper: void* -> Int64
static inline cpp::Int64 P(void* p) { return (cpp::Int64)(intptr_t)p; }
')
class L2D
{
    static inline function m(v:L2DModel):cpp.Int64 return cast v;

    // ===== Framework =====
    public static function frameworkStartUp():Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.framework_start_up) l2dFn.framework_start_up()');
    }

    public static function frameworkCleanUp():Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.framework_start_up) { /* TODO: cleanup */ }');
    }

    // ===== Lifecycle =====
    public static function loadModel(dir:String, fileName:String):L2DModel
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.load_model ? P(l2dFn.load_model({0}.utf8_str(), {1}.utf8_str())) : (cpp::Int64)0)', dir, fileName);
    }

    public static function releaseModel(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.release_model) l2dFn.release_model(M((cpp::Int64){0}))', m(model));
    }

    // ===== Update =====
    public static function update(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.update) l2dFn.update(M((cpp::Int64){0}))', m(model));
    }

    public static function setDeltaTime(dt:Float):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_delta_time) l2dFn.set_delta_time({0})', dt);
    }

    // ===== Parameters =====
    public static function getParameterCount(model:L2DModel):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_parameter_count ? l2dFn.get_parameter_count(M((cpp::Int64){0})) : 0)', m(model));
    }

    public static function findParameterIndex(model:L2DModel, name:String):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.find_parameter_index ? l2dFn.find_parameter_index(M((cpp::Int64){0}), {1}.utf8_str()) : -1)', m(model), name);
    }

    public static function getParameterValue(model:L2DModel, index:Int):Float
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_parameter_value ? l2dFn.get_parameter_value(M((cpp::Int64){0}), {1}) : 0.0f)', m(model), index);
    }

    public static function setParameterValue(model:L2DModel, index:Int, value:Float, weight:Float = 1.0):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_parameter_value) l2dFn.set_parameter_value(M((cpp::Int64){0}), {1}, {2}, {3})', m(model), index, value, weight);
    }

    // ===== Animation =====
    public static function startMotion(model:L2DModel, group:String, no:Int, priority:Int):cpp.Int64
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.start_motion ? (cpp::Int64)l2dFn.start_motion(M((cpp::Int64){0}), {1}.utf8_str(), {2}, {3}) : (cpp::Int64)-1)', m(model), group, no, priority);
    }

    public static function startRandomMotion(model:L2DModel, group:String, priority:Int):cpp.Int64
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.start_random_motion ? (cpp::Int64)l2dFn.start_random_motion(M((cpp::Int64){0}), {1}.utf8_str(), {2}) : (cpp::Int64)-1)', m(model), group, priority);
    }

    public static function isMotionFinished(model:L2DModel, handle:cpp.Int64):Bool
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.is_motion_finished ? l2dFn.is_motion_finished(M((cpp::Int64){0}), (intptr_t){1}) : true)', m(model), handle);
    }

    // ===== Expression =====
    public static function setExpression(model:L2DModel, expressionID:String):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_expression) l2dFn.set_expression(M((cpp::Int64){0}), {1}.utf8_str())', m(model), expressionID);
    }

    public static function setRandomExpression(model:L2DModel):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_random_expression) l2dFn.set_random_expression(M((cpp::Int64){0}))', m(model));
    }

    // ===== Interaction =====
    public static function hitTest(model:L2DModel, areaName:String, x:Float, y:Float):Bool
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.hit_test ? l2dFn.hit_test(M((cpp::Int64){0}), {1}.utf8_str(), {2}, {3}) : false)', m(model), areaName, x, y);
    }

    public static function setDragging(model:L2DModel, x:Float, y:Float):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.set_dragging) l2dFn.set_dragging(M((cpp::Int64){0}), {1}, {2})', m(model), x, y);
    }

    // ===== Drawable =====
    public static function getDrawableCount(model:L2DModel):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_count ? l2dFn.get_drawable_count(M((cpp::Int64){0})) : 0)', m(model));
    }

    public static function getDrawableVertexCount(model:L2DModel, i:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_vertex_count ? l2dFn.get_drawable_vertex_count(M((cpp::Int64){0}), {1}) : 0)', m(model), i);
    }

    public static function getDrawableVertexPositions(model:L2DModel, i:Int, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_drawable_vertex_positions) l2dFn.get_drawable_vertex_positions(M((cpp::Int64){0}), {1}, (float*)({2}->b.mPtr->GetBase()))', m(model), i, out);
    }

    public static function getDrawableVertexUvs(model:L2DModel, i:Int, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_drawable_vertex_uvs) l2dFn.get_drawable_vertex_uvs(M((cpp::Int64){0}), {1}, (float*)({2}->b.mPtr->GetBase()))', m(model), i, out);
    }

    public static function getDrawableIndexCount(model:L2DModel, i:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_index_count ? l2dFn.get_drawable_index_count(M((cpp::Int64){0}), {1}) : 0)', m(model), i);
    }

    public static function getDrawableIndices(model:L2DModel, i:Int, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_drawable_indices) l2dFn.get_drawable_indices(M((cpp::Int64){0}), {1}, (uint16_t*)({2}->b.mPtr->GetBase()))', m(model), i, out);
    }

    public static function getDrawableOpacity(model:L2DModel, i:Int):Float
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_opacity ? l2dFn.get_drawable_opacity(M((cpp::Int64){0}), {1}) : 0.0f)', m(model), i);
    }

    public static function getDrawableRenderOrder(model:L2DModel, i:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_render_order ? l2dFn.get_drawable_render_order(M((cpp::Int64){0}), {1}) : 0)', m(model), i);
    }

    public static function getDrawableTextureIndex(model:L2DModel, i:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_texture_index ? l2dFn.get_drawable_texture_index(M((cpp::Int64){0}), {1}) : -1)', m(model), i);
    }

    public static function isDrawableVisible(model:L2DModel, i:Int):Bool
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.is_drawable_visible ? l2dFn.is_drawable_visible(M((cpp::Int64){0}), {1}) : false)', m(model), i);
    }

    // ===== Mask =====
    public static function getDrawableMaskCount(model:L2DModel, i:Int):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_drawable_mask_count ? l2dFn.get_drawable_mask_count(M((cpp::Int64){0}), {1}) : 0)', m(model), i);
    }

    public static function getDrawableMasks(model:L2DModel, i:Int, out:Bytes):Void
    {
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_drawable_masks) l2dFn.get_drawable_masks(M((cpp::Int64){0}), {1}, (int*)({2}->b.mPtr->GetBase()))', m(model), i, out);
    }

    // ===== Texture =====
    public static function getTextureCount(model:L2DModel):Int
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_texture_count ? l2dFn.get_texture_count(M((cpp::Int64){0})) : 0)', m(model));
    }

    public static function getTexturePath(model:L2DModel, i:Int):String
    {
        var buf = Bytes.alloc(512);
        untyped __cpp__('l2d_ensure_loaded(); if(l2dFn.get_texture_path) l2dFn.get_texture_path(M((cpp::Int64){0}), {1}, (char*)({2}->b.mPtr->GetBase()), 512)', m(model), i, buf);
        var len = 0;
        while (len < 512 && buf.get(len) != 0) len++;
        return buf.getString(0, len);
    }

    // ===== Model Info =====
    public static function getCanvasWidth(model:L2DModel):Float
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_canvas_width ? l2dFn.get_canvas_width(M((cpp::Int64){0})) : 0.0f)', m(model));
    }

    public static function getCanvasHeight(model:L2DModel):Float
    {
        return untyped __cpp__('(l2d_ensure_loaded(), l2dFn.get_canvas_height ? l2dFn.get_canvas_height(M((cpp::Int64){0})) : 0.0f)', m(model));
    }
}
