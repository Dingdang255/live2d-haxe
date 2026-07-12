/**
 * live2d_hl.cpp — HashLink .hdll shim for live2d_capi.dll
 *
 * Dynamically loads live2d_capi.dll at runtime and forwards all calls
 * through cached function pointers, exactly like HxcppWindowsBridge
 * does on the hxcpp target.
 *
 * Build: linked against libhl.lib, output as live2d_hl.hdll
 */

#define HL_NAME(n) live2d_hl_##n
#include <hl.h>
#include <windows.h>
#include <stdint.h>

// ============================================================
// Function pointer struct (mirrors HxcppWindowsBridge::L2DFunctions)
// ============================================================
struct L2DFunctions {
    void  (*framework_start_up)();
    void  (*framework_clean_up)();
    void* (*load_model)(const char*, const char*);
    void  (*update)(void*);
    void  (*set_delta_time)(float);
    void  (*release_model)(void*);
    int   (*get_drawable_count)(void*);
    int   (*get_drawable_vertex_count)(void*, int);
    void  (*get_drawable_vertex_positions)(void*, int, float*);
    void  (*get_drawable_vertex_uvs)(void*, int, float*);
    int   (*get_drawable_index_count)(void*, int);
    void  (*get_drawable_indices)(void*, int, uint16_t*);
    float (*get_drawable_opacity)(void*, int);
    int   (*get_drawable_render_order)(void*, int);
    int   (*get_drawable_texture_index)(void*, int);
    bool  (*is_drawable_visible)(void*, int);
    void  (*get_drawable_multiply_color)(void*, int, float*);
    void  (*get_drawable_screen_color)(void*, int, float*);
    int   (*get_drawable_blend_mode)(void*, int);
    int   (*get_texture_count)(void*);
    void  (*get_texture_path)(void*, int, char*, int);
    float (*get_canvas_width)(void*);
    float (*get_canvas_height)(void*);
    intptr_t (*start_motion)(void*, const char*, int, int);
    intptr_t (*start_random_motion)(void*, const char*, int);
    intptr_t (*start_motion_file)(void*, const char*, int);
    bool  (*is_motion_finished)(void*, intptr_t);
    void  (*stop_all_motions)(void*);
    void  (*set_expression)(void*, const char*);
    void  (*set_random_expression)(void*);
    bool  (*hit_test)(void*, const char*, float, float);
    void  (*set_dragging)(void*, float, float);
    int   (*get_parameter_count)(void*);
    int   (*find_parameter_index)(void*, const char*);
    float (*get_parameter_value)(void*, int);
    void  (*set_parameter_value)(void*, int, float, float);
    int   (*get_drawable_mask_count)(void*, int);
    void  (*get_drawable_masks)(void*, int, int*);
    bool  (*get_drawable_inverted_mask)(void*, int);
    bool  (*get_drawable_dynamic_flag_vertex_positions_did_change)(void*, int);
    void  (*get_drawable_batch_metadata)(void*, int, char*);
    void  (*set_breath_enabled)(void*, bool);
    void  (*set_eye_blink_enabled)(void*, bool);
    void  (*set_expression_enabled)(void*, bool);
    void  (*set_look_enabled)(void*, bool);
    void  (*set_physics_enabled)(void*, bool);
    void  (*set_lip_sync_enabled)(void*, bool);
    void  (*set_pose_enabled)(void*, bool);
    void  (*set_lip_sync_value)(void*, float);
    unsigned int (*get_core_version)();
    unsigned int (*get_latest_moc_version)();
    bool  (*has_moc_consistency)(const char*);
    int   (*poll_motion_events)(void*, char*, int);
    void  (*clear_motion_events)(void*);
    int   (*get_part_count)(void*);
    int   (*find_part_index)(void*, const char*);
    void  (*get_part_id)(void*, int, char*, int);
    float (*get_part_opacity)(void*, int);
    void  (*set_part_opacity)(void*, int, float);
    void  (*reset_pose)(void*);
    void  (*set_physics_options)(void*, float, float, float, float);
    void  (*get_physics_options)(void*, float*, float*, float*, float*);
    void  (*reset_physics)(void*);
    void  (*stabilize_physics)(void*);
    bool loaded;
};

static L2DFunctions l2dFn = {0};
static HMODULE l2d_lib = NULL;

// Pointer ↔ int64_t helpers
static inline void* M(int64_t m) { return (void*)(intptr_t)m; }
static inline int64_t P(void* p) { return (int64_t)(intptr_t)p; }

// ============================================================
// Init: LoadLibraryA + GetProcAddress
// ============================================================
HL_PRIM void HL_NAME(init)() {
    if (l2dFn.loaded) return;
    HMODULE h = GetModuleHandleA("live2d_capi");
    if (!h) h = LoadLibraryA("live2d_capi");
    if (!h) return;
    l2d_lib = h;
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
    L2D_LOAD(get_drawable_opacity);
    L2D_LOAD(get_drawable_render_order);
    L2D_LOAD(get_drawable_texture_index);
    L2D_LOAD(is_drawable_visible);
    L2D_LOAD(get_drawable_multiply_color);
    L2D_LOAD(get_drawable_screen_color);
    L2D_LOAD(get_drawable_blend_mode);
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
    L2D_LOAD(get_drawable_dynamic_flag_vertex_positions_did_change);
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
DEFINE_PRIM(_VOID, init, _NO_ARG);

// ============================================================
// Framework lifecycle
// ============================================================

HL_PRIM void HL_NAME(framework_start_up)() {
    if (l2dFn.framework_start_up) l2dFn.framework_start_up();
}
DEFINE_PRIM(_VOID, framework_start_up, _NO_ARG);

HL_PRIM void HL_NAME(framework_clean_up)() {
    if (l2dFn.framework_clean_up) l2dFn.framework_clean_up();
}
DEFINE_PRIM(_VOID, framework_clean_up, _NO_ARG);

// ============================================================
// Model lifecycle
// ============================================================

HL_PRIM int64_t HL_NAME(load_model)(vbyte* dir, vbyte* fileName) {
    if (!l2dFn.load_model) return 0;
    return P(l2dFn.load_model((const char*)dir, (const char*)fileName));
}
DEFINE_PRIM(_I64, load_model, _BYTES _BYTES);

HL_PRIM void HL_NAME(release_model)(int64_t model) {
    if (l2dFn.release_model) l2dFn.release_model(M(model));
}
DEFINE_PRIM(_VOID, release_model, _I64);

// ============================================================
// Update
// ============================================================

HL_PRIM void HL_NAME(update)(int64_t model) {
    if (l2dFn.update) l2dFn.update(M(model));
}
DEFINE_PRIM(_VOID, update, _I64);

HL_PRIM void HL_NAME(set_delta_time)(double dt) {
    if (l2dFn.set_delta_time) l2dFn.set_delta_time((float)dt);
}
DEFINE_PRIM(_VOID, set_delta_time, _F64);

// ============================================================
// Parameters
// ============================================================

HL_PRIM int HL_NAME(get_parameter_count)(int64_t model) {
    return l2dFn.get_parameter_count ? l2dFn.get_parameter_count(M(model)) : 0;
}
DEFINE_PRIM(_I32, get_parameter_count, _I64);

HL_PRIM int HL_NAME(find_parameter_index)(int64_t model, vbyte* name) {
    return l2dFn.find_parameter_index ? l2dFn.find_parameter_index(M(model), (const char*)name) : -1;
}
DEFINE_PRIM(_I32, find_parameter_index, _I64 _BYTES);

HL_PRIM double HL_NAME(get_parameter_value)(int64_t model, int index) {
    return l2dFn.get_parameter_value ? (double)l2dFn.get_parameter_value(M(model), index) : 0.0;
}
DEFINE_PRIM(_F64, get_parameter_value, _I64 _I32);

HL_PRIM void HL_NAME(set_parameter_value)(int64_t model, int index, double value, double weight) {
    if (l2dFn.set_parameter_value) l2dFn.set_parameter_value(M(model), index, (float)value, (float)weight);
}
DEFINE_PRIM(_VOID, set_parameter_value, _I64 _I32 _F64 _F64);

// ============================================================
// Animation
// ============================================================

HL_PRIM int HL_NAME(start_motion)(int64_t model, vbyte* group, int no, int priority) {
    return l2dFn.start_motion ? (int)l2dFn.start_motion(M(model), (const char*)group, no, priority) : -1;
}
DEFINE_PRIM(_I32, start_motion, _I64 _BYTES _I32 _I32);

HL_PRIM int HL_NAME(start_random_motion)(int64_t model, vbyte* group, int priority) {
    return l2dFn.start_random_motion ? (int)l2dFn.start_random_motion(M(model), (const char*)group, priority) : -1;
}
DEFINE_PRIM(_I32, start_random_motion, _I64 _BYTES _I32);

HL_PRIM int HL_NAME(start_motion_file)(int64_t model, vbyte* path, int priority) {
    return l2dFn.start_motion_file ? (int)l2dFn.start_motion_file(M(model), (const char*)path, priority) : -1;
}
DEFINE_PRIM(_I32, start_motion_file, _I64 _BYTES _I32);

HL_PRIM bool HL_NAME(is_motion_finished)(int64_t model, int handle) {
    return l2dFn.is_motion_finished ? l2dFn.is_motion_finished(M(model), (intptr_t)handle) : true;
}
DEFINE_PRIM(_BOOL, is_motion_finished, _I64 _I32);

HL_PRIM void HL_NAME(stop_all_motions)(int64_t model) {
    if (l2dFn.stop_all_motions) l2dFn.stop_all_motions(M(model));
}
DEFINE_PRIM(_VOID, stop_all_motions, _I64);

// ============================================================
// Expression
// ============================================================

HL_PRIM void HL_NAME(set_expression)(int64_t model, vbyte* expressionID) {
    if (l2dFn.set_expression) l2dFn.set_expression(M(model), (const char*)expressionID);
}
DEFINE_PRIM(_VOID, set_expression, _I64 _BYTES);

HL_PRIM void HL_NAME(set_random_expression)(int64_t model) {
    if (l2dFn.set_random_expression) l2dFn.set_random_expression(M(model));
}
DEFINE_PRIM(_VOID, set_random_expression, _I64);

// ============================================================
// Interaction
// ============================================================

HL_PRIM bool HL_NAME(hit_test)(int64_t model, vbyte* areaName, double x, double y) {
    return l2dFn.hit_test ? l2dFn.hit_test(M(model), (const char*)areaName, (float)x, (float)y) : false;
}
DEFINE_PRIM(_BOOL, hit_test, _I64 _BYTES _F64 _F64);

HL_PRIM void HL_NAME(set_dragging)(int64_t model, double x, double y) {
    if (l2dFn.set_dragging) l2dFn.set_dragging(M(model), (float)x, (float)y);
}
DEFINE_PRIM(_VOID, set_dragging, _I64 _F64 _F64);

// ============================================================
// Drawable data
// ============================================================

HL_PRIM int HL_NAME(get_drawable_count)(int64_t model) {
    return l2dFn.get_drawable_count ? l2dFn.get_drawable_count(M(model)) : 0;
}
DEFINE_PRIM(_I32, get_drawable_count, _I64);

HL_PRIM int HL_NAME(get_drawable_vertex_count)(int64_t model, int i) {
    return l2dFn.get_drawable_vertex_count ? l2dFn.get_drawable_vertex_count(M(model), i) : 0;
}
DEFINE_PRIM(_I32, get_drawable_vertex_count, _I64 _I32);

HL_PRIM void HL_NAME(get_drawable_vertex_positions)(int64_t model, int i, vbyte* out) {
    if (l2dFn.get_drawable_vertex_positions) l2dFn.get_drawable_vertex_positions(M(model), i, (float*)out);
}
DEFINE_PRIM(_VOID, get_drawable_vertex_positions, _I64 _I32 _BYTES);

HL_PRIM void HL_NAME(get_drawable_vertex_uvs)(int64_t model, int i, vbyte* out) {
    if (l2dFn.get_drawable_vertex_uvs) l2dFn.get_drawable_vertex_uvs(M(model), i, (float*)out);
}
DEFINE_PRIM(_VOID, get_drawable_vertex_uvs, _I64 _I32 _BYTES);

HL_PRIM int HL_NAME(get_drawable_index_count)(int64_t model, int i) {
    return l2dFn.get_drawable_index_count ? l2dFn.get_drawable_index_count(M(model), i) : 0;
}
DEFINE_PRIM(_I32, get_drawable_index_count, _I64 _I32);

HL_PRIM void HL_NAME(get_drawable_indices)(int64_t model, int i, vbyte* out) {
    if (l2dFn.get_drawable_indices) l2dFn.get_drawable_indices(M(model), i, (uint16_t*)out);
}
DEFINE_PRIM(_VOID, get_drawable_indices, _I64 _I32 _BYTES);

HL_PRIM double HL_NAME(get_drawable_opacity)(int64_t model, int i) {
    return l2dFn.get_drawable_opacity ? (double)l2dFn.get_drawable_opacity(M(model), i) : 0.0;
}
DEFINE_PRIM(_F64, get_drawable_opacity, _I64 _I32);

HL_PRIM int HL_NAME(get_drawable_render_order)(int64_t model, int i) {
    return l2dFn.get_drawable_render_order ? l2dFn.get_drawable_render_order(M(model), i) : 0;
}
DEFINE_PRIM(_I32, get_drawable_render_order, _I64 _I32);

HL_PRIM int HL_NAME(get_drawable_texture_index)(int64_t model, int i) {
    return l2dFn.get_drawable_texture_index ? l2dFn.get_drawable_texture_index(M(model), i) : -1;
}
DEFINE_PRIM(_I32, get_drawable_texture_index, _I64 _I32);

HL_PRIM bool HL_NAME(is_drawable_visible)(int64_t model, int i) {
    return l2dFn.is_drawable_visible ? l2dFn.is_drawable_visible(M(model), i) : false;
}
DEFINE_PRIM(_BOOL, is_drawable_visible, _I64 _I32);

HL_PRIM void HL_NAME(get_drawable_multiply_color)(int64_t model, int i, vbyte* out) {
    if (l2dFn.get_drawable_multiply_color) l2dFn.get_drawable_multiply_color(M(model), i, (float*)out);
}
DEFINE_PRIM(_VOID, get_drawable_multiply_color, _I64 _I32 _BYTES);

HL_PRIM void HL_NAME(get_drawable_screen_color)(int64_t model, int i, vbyte* out) {
    if (l2dFn.get_drawable_screen_color) l2dFn.get_drawable_screen_color(M(model), i, (float*)out);
}
DEFINE_PRIM(_VOID, get_drawable_screen_color, _I64 _I32 _BYTES);

HL_PRIM int HL_NAME(get_drawable_blend_mode)(int64_t model, int i) {
    return l2dFn.get_drawable_blend_mode ? l2dFn.get_drawable_blend_mode(M(model), i) : 0;
}
DEFINE_PRIM(_I32, get_drawable_blend_mode, _I64 _I32);

// ============================================================
// Mask
// ============================================================

HL_PRIM int HL_NAME(get_drawable_mask_count)(int64_t model, int i) {
    return l2dFn.get_drawable_mask_count ? l2dFn.get_drawable_mask_count(M(model), i) : 0;
}
DEFINE_PRIM(_I32, get_drawable_mask_count, _I64 _I32);

HL_PRIM void HL_NAME(get_drawable_masks)(int64_t model, int i, vbyte* out) {
    if (l2dFn.get_drawable_masks) l2dFn.get_drawable_masks(M(model), i, (int*)out);
}
DEFINE_PRIM(_VOID, get_drawable_masks, _I64 _I32 _BYTES);

HL_PRIM bool HL_NAME(get_drawable_inverted_mask)(int64_t model, int i) {
    return l2dFn.get_drawable_inverted_mask ? l2dFn.get_drawable_inverted_mask(M(model), i) : false;
}
DEFINE_PRIM(_BOOL, get_drawable_inverted_mask, _I64 _I32);

HL_PRIM bool HL_NAME(get_drawable_dynamic_flag_vertex_positions_did_change)(int64_t model, int i) {
    return l2dFn.get_drawable_dynamic_flag_vertex_positions_did_change
        ? l2dFn.get_drawable_dynamic_flag_vertex_positions_did_change(M(model), i) : false;
}
DEFINE_PRIM(_BOOL, get_drawable_dynamic_flag_vertex_positions_did_change, _I64 _I32);

// ============================================================
// Batch metadata
// ============================================================

HL_PRIM void HL_NAME(get_drawable_batch_metadata)(int64_t model, int count, vbyte* out) {
    if (l2dFn.get_drawable_batch_metadata) l2dFn.get_drawable_batch_metadata(M(model), count, (char*)out);
}
DEFINE_PRIM(_VOID, get_drawable_batch_metadata, _I64 _I32 _BYTES);

// ============================================================
// Texture
// ============================================================

HL_PRIM int HL_NAME(get_texture_count)(int64_t model) {
    return l2dFn.get_texture_count ? l2dFn.get_texture_count(M(model)) : 0;
}
DEFINE_PRIM(_I32, get_texture_count, _I64);

HL_PRIM void HL_NAME(get_texture_path)(int64_t model, int i, vbyte* out, int bufLen) {
    if (l2dFn.get_texture_path) l2dFn.get_texture_path(M(model), i, (char*)out, bufLen);
}
DEFINE_PRIM(_VOID, get_texture_path, _I64 _I32 _BYTES _I32);

// ============================================================
// Model info
// ============================================================

HL_PRIM double HL_NAME(get_canvas_width)(int64_t model) {
    return l2dFn.get_canvas_width ? (double)l2dFn.get_canvas_width(M(model)) : 0.0;
}
DEFINE_PRIM(_F64, get_canvas_width, _I64);

HL_PRIM double HL_NAME(get_canvas_height)(int64_t model) {
    return l2dFn.get_canvas_height ? (double)l2dFn.get_canvas_height(M(model)) : 0.0;
}
DEFINE_PRIM(_F64, get_canvas_height, _I64);

// ============================================================
// Framework behavior control
// ============================================================

HL_PRIM void HL_NAME(set_breath_enabled)(int64_t model, bool enabled) {
    if (l2dFn.set_breath_enabled) l2dFn.set_breath_enabled(M(model), enabled);
}
DEFINE_PRIM(_VOID, set_breath_enabled, _I64 _BOOL);

HL_PRIM void HL_NAME(set_eye_blink_enabled)(int64_t model, bool enabled) {
    if (l2dFn.set_eye_blink_enabled) l2dFn.set_eye_blink_enabled(M(model), enabled);
}
DEFINE_PRIM(_VOID, set_eye_blink_enabled, _I64 _BOOL);

HL_PRIM void HL_NAME(set_expression_enabled)(int64_t model, bool enabled) {
    if (l2dFn.set_expression_enabled) l2dFn.set_expression_enabled(M(model), enabled);
}
DEFINE_PRIM(_VOID, set_expression_enabled, _I64 _BOOL);

HL_PRIM void HL_NAME(set_look_enabled)(int64_t model, bool enabled) {
    if (l2dFn.set_look_enabled) l2dFn.set_look_enabled(M(model), enabled);
}
DEFINE_PRIM(_VOID, set_look_enabled, _I64 _BOOL);

HL_PRIM void HL_NAME(set_physics_enabled)(int64_t model, bool enabled) {
    if (l2dFn.set_physics_enabled) l2dFn.set_physics_enabled(M(model), enabled);
}
DEFINE_PRIM(_VOID, set_physics_enabled, _I64 _BOOL);

HL_PRIM void HL_NAME(set_lip_sync_enabled)(int64_t model, bool enabled) {
    if (l2dFn.set_lip_sync_enabled) l2dFn.set_lip_sync_enabled(M(model), enabled);
}
DEFINE_PRIM(_VOID, set_lip_sync_enabled, _I64 _BOOL);

HL_PRIM void HL_NAME(set_pose_enabled)(int64_t model, bool enabled) {
    if (l2dFn.set_pose_enabled) l2dFn.set_pose_enabled(M(model), enabled);
}
DEFINE_PRIM(_VOID, set_pose_enabled, _I64 _BOOL);

// ============================================================
// LipSync value
// ============================================================

HL_PRIM void HL_NAME(set_lip_sync_value)(int64_t model, double value) {
    if (l2dFn.set_lip_sync_value) l2dFn.set_lip_sync_value(M(model), (float)value);
}
DEFINE_PRIM(_VOID, set_lip_sync_value, _I64 _F64);

// ============================================================
// Moc version checking
// ============================================================

HL_PRIM int HL_NAME(get_core_version)() {
    return l2dFn.get_core_version ? (int)l2dFn.get_core_version() : 0;
}
DEFINE_PRIM(_I32, get_core_version, _NO_ARG);

HL_PRIM int HL_NAME(get_latest_moc_version)() {
    return l2dFn.get_latest_moc_version ? (int)l2dFn.get_latest_moc_version() : 0;
}
DEFINE_PRIM(_I32, get_latest_moc_version, _NO_ARG);

HL_PRIM bool HL_NAME(has_moc_consistency)(vbyte* path) {
    return l2dFn.has_moc_consistency ? l2dFn.has_moc_consistency((const char*)path) : false;
}
DEFINE_PRIM(_BOOL, has_moc_consistency, _BYTES);

// ============================================================
// Motion Event Polling
// ============================================================

HL_PRIM int HL_NAME(poll_motion_events)(int64_t model, vbyte* out, int len) {
    return l2dFn.poll_motion_events ? l2dFn.poll_motion_events(M(model), (char*)out, len) : 0;
}
DEFINE_PRIM(_I32, poll_motion_events, _I64 _BYTES _I32);

HL_PRIM void HL_NAME(clear_motion_events)(int64_t model) {
    if (l2dFn.clear_motion_events) l2dFn.clear_motion_events(M(model));
}
DEFINE_PRIM(_VOID, clear_motion_events, _I64);

// ============================================================
// Parts API
// ============================================================

HL_PRIM int HL_NAME(get_part_count)(int64_t model) {
    return l2dFn.get_part_count ? l2dFn.get_part_count(M(model)) : 0;
}
DEFINE_PRIM(_I32, get_part_count, _I64);

HL_PRIM int HL_NAME(find_part_index)(int64_t model, vbyte* name) {
    return l2dFn.find_part_index ? l2dFn.find_part_index(M(model), (const char*)name) : -1;
}
DEFINE_PRIM(_I32, find_part_index, _I64 _BYTES);

HL_PRIM void HL_NAME(get_part_id)(int64_t model, int idx, vbyte* out, int len) {
    if (l2dFn.get_part_id) l2dFn.get_part_id(M(model), idx, (char*)out, len);
}
DEFINE_PRIM(_VOID, get_part_id, _I64 _I32 _BYTES _I32);

HL_PRIM double HL_NAME(get_part_opacity)(int64_t model, int idx) {
    return l2dFn.get_part_opacity ? (double)l2dFn.get_part_opacity(M(model), idx) : 0.0;
}
DEFINE_PRIM(_F64, get_part_opacity, _I64 _I32);

HL_PRIM void HL_NAME(set_part_opacity)(int64_t model, int idx, double opacity) {
    if (l2dFn.set_part_opacity) l2dFn.set_part_opacity(M(model), idx, (float)opacity);
}
DEFINE_PRIM(_VOID, set_part_opacity, _I64 _I32 _F64);

// ============================================================
// Pose Reset
// ============================================================

HL_PRIM void HL_NAME(reset_pose)(int64_t model) {
    if (l2dFn.reset_pose) l2dFn.reset_pose(M(model));
}
DEFINE_PRIM(_VOID, reset_pose, _I64);

// ============================================================
// Physics Runtime Tuning
// ============================================================

HL_PRIM void HL_NAME(set_physics_options)(int64_t model, double gx, double gy, double wx, double wy) {
    if (l2dFn.set_physics_options) l2dFn.set_physics_options(M(model), (float)gx, (float)gy, (float)wx, (float)wy);
}
DEFINE_PRIM(_VOID, set_physics_options, _I64 _F64 _F64 _F64 _F64);

// outBuf: 16 bytes, layout: [gx, gy, wx, wy] as float32 LE
HL_PRIM void HL_NAME(get_physics_options)(int64_t model, vbyte* outBuf) {
    if (!l2dFn.get_physics_options || !outBuf) return;
    float gx = 0.0f, gy = -1.0f, wx = 0.0f, wy = 0.0f;
    l2dFn.get_physics_options(M(model), &gx, &gy, &wx, &wy);
    float* out = (float*)outBuf;
    out[0] = gx; out[1] = gy; out[2] = wx; out[3] = wy;
}
DEFINE_PRIM(_VOID, get_physics_options, _I64 _BYTES);

HL_PRIM void HL_NAME(reset_physics)(int64_t model) {
    if (l2dFn.reset_physics) l2dFn.reset_physics(M(model));
}
DEFINE_PRIM(_VOID, reset_physics, _I64);

HL_PRIM void HL_NAME(stabilize_physics)(int64_t model) {
    if (l2dFn.stabilize_physics) l2dFn.stabilize_physics(M(model));
}
DEFINE_PRIM(_VOID, stabilize_physics, _I64);
