/**
 * Live2D C API - Flat Interface
 * For Haxe FFI calls
 * 
 * Copyright(c) Live2D Inc. All rights reserved.
 */

#pragma once

#ifdef _WIN32
#  define L2D_API __declspec(dllexport)
#else
#  define L2D_API
#endif

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* L2D_Model;

// ===== Test =====
L2D_API int l2d_test_add(int a, int b);

// ===== Lifecycle =====
L2D_API L2D_Model l2d_load_model(const char* dir, const char* fileName);
L2D_API void      l2d_release_model(L2D_Model m);

// ===== Framework Initialization/Cleanup =====
L2D_API void l2d_framework_start_up();
L2D_API void l2d_framework_clean_up();

// ===== Update =====
L2D_API void l2d_update(L2D_Model m);
L2D_API void l2d_set_delta_time(float dt);

// ===== Parameters =====
L2D_API int   l2d_get_parameter_count(L2D_Model m);
L2D_API int   l2d_find_parameter_index(L2D_Model m, const char* name);
L2D_API float l2d_get_parameter_value(L2D_Model m, int index);
L2D_API void  l2d_set_parameter_value(L2D_Model m, int index, float value, float weight);

// ===== Animation =====
// Note: motion handle is intptr_t because CubismMotionQueueEntryHandle is void*
L2D_API intptr_t l2d_start_motion(L2D_Model m, const char* group, int no, int priority);
L2D_API intptr_t l2d_start_random_motion(L2D_Model m, const char* group, int priority);
L2D_API bool     l2d_is_motion_finished(L2D_Model m, intptr_t motionHandle);

// ===== Expression =====
L2D_API void l2d_set_expression(L2D_Model m, const char* expressionID);
L2D_API void l2d_set_random_expression(L2D_Model m);

// ===== Interaction =====
L2D_API bool l2d_hit_test(L2D_Model m, const char* areaName, float x, float y);
L2D_API void l2d_set_dragging(L2D_Model m, float x, float y);

// ===== Drawable Data =====
L2D_API int  l2d_get_drawable_count(L2D_Model m);
L2D_API int  l2d_get_drawable_vertex_count(L2D_Model m, int drawableIndex);
L2D_API void l2d_get_drawable_vertex_positions(L2D_Model m, int drawableIndex, float* outBuf);
L2D_API void l2d_get_drawable_vertex_uvs(L2D_Model m, int drawableIndex, float* outBuf);
L2D_API int  l2d_get_drawable_index_count(L2D_Model m, int drawableIndex);
L2D_API void l2d_get_drawable_indices(L2D_Model m, int drawableIndex, uint16_t* outBuf);
L2D_API float l2d_get_drawable_opacity(L2D_Model m, int drawableIndex);
L2D_API int   l2d_get_drawable_render_order(L2D_Model m, int drawableIndex);
L2D_API int   l2d_get_drawable_texture_index(L2D_Model m, int drawableIndex);
L2D_API bool  l2d_is_drawable_visible(L2D_Model m, int drawableIndex);
L2D_API void  l2d_get_drawable_multiply_color(L2D_Model m, int drawableIndex, float* outRGBA);
L2D_API void  l2d_get_drawable_screen_color(L2D_Model m, int drawableIndex, float* outRGBA);
L2D_API int   l2d_get_drawable_blend_mode(L2D_Model m, int drawableIndex);

// ===== Mask =====
L2D_API int  l2d_get_drawable_mask_count(L2D_Model m, int drawableIndex);
L2D_API void l2d_get_drawable_masks(L2D_Model m, int drawableIndex, int* outBuf);
L2D_API bool l2d_get_drawable_inverted_mask(L2D_Model m, int drawableIndex);
L2D_API bool l2d_get_drawable_dynamic_flag_vertex_positions_did_change(L2D_Model m, int drawableIndex);

// ===== Batch Metadata (one call returns all drawable metadata) =====
// Layout per drawable: int32 visible, int32 renderOrder, float opacity, int32 textureIndex, int32 blendMode, float mulR, float mulG, float mulB, float scrR, float scrG, float scrB, int32 vertexDidChange = 48 bytes
L2D_API void l2d_get_drawable_batch_metadata(L2D_Model m, int count, char* outBuf);

// ===== Texture Path =====
L2D_API int  l2d_get_texture_count(L2D_Model m);
L2D_API void l2d_get_texture_path(L2D_Model m, int textureIndex, char* outBuf, int bufLen);

// ===== Model Info =====
L2D_API float l2d_get_canvas_width(L2D_Model m);
L2D_API float l2d_get_canvas_height(L2D_Model m);

// ===== Framework Behavior Control =====
L2D_API void  l2d_set_breath_enabled(L2D_Model m, bool enabled);
L2D_API void  l2d_set_eye_blink_enabled(L2D_Model m, bool enabled);
L2D_API void  l2d_set_expression_enabled(L2D_Model m, bool enabled);
L2D_API void  l2d_set_look_enabled(L2D_Model m, bool enabled);
L2D_API void  l2d_set_physics_enabled(L2D_Model m, bool enabled);
L2D_API void  l2d_set_lip_sync_enabled(L2D_Model m, bool enabled);
L2D_API void  l2d_set_pose_enabled(L2D_Model m, bool enabled);

// ===== LipSync Value (external audio/microphone input) =====
// value: 0.0~1.0 for external mode, <0 to revert to wav file handler
L2D_API void  l2d_set_lip_sync_value(L2D_Model m, float value);

// ===== Motion Event Polling =====
// Returns the number of pending motion UserData events for model m.
// Events are written to outBuf as null-separated UTF-8 strings with a
// double-null terminator. The queue is auto-cleared after polling.
L2D_API int l2d_poll_motion_events(L2D_Model m, char* outBuf, int bufLen);
// Clear all pending motion events for model m without retrieving them.
L2D_API void l2d_clear_motion_events(L2D_Model m);

// ===== Parts API =====
L2D_API int   l2d_get_part_count(L2D_Model m);
L2D_API int   l2d_find_part_index(L2D_Model m, const char* name);
L2D_API void  l2d_get_part_id(L2D_Model m, int partIndex, char* outBuf, int bufLen);
L2D_API float l2d_get_part_opacity(L2D_Model m, int partIndex);
L2D_API void  l2d_set_part_opacity(L2D_Model m, int partIndex, float opacity);

// ===== Pose Reset =====
// Resets pose part opacities to default values defined in .pose3.json.
// No-op if the model has no pose file.
L2D_API void l2d_reset_pose(L2D_Model m);

// ===== Moc Version Checking =====
L2D_API unsigned int l2d_get_core_version();
L2D_API unsigned int l2d_get_latest_moc_version();
L2D_API bool l2d_has_moc_consistency(const char* mocFilePath);

#ifdef __cplusplus
}
#endif
