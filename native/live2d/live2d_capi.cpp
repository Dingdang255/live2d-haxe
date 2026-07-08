/**
 * Live2D C API - Flat Interface Implementation
 * 
 * Copyright(c) Live2D Inc. All rights reserved.
 */

#include "live2d_capi.h"
#include "LAppModel_CalcOnly.hpp"
#include "LAppPal_CalcOnly.hpp"
#include "LAppAllocator_Common.hpp"
#include <CubismFramework.hpp>
#include <Id/CubismIdManager.hpp>
#include <Model/CubismModel.hpp>
#include <Motion/CubismMotionQueueManager.hpp>
#include <Live2DCubismCore.hpp>
#include <Model/CubismMoc.hpp>
#include <fstream>
#include <vector>
#include <unordered_map>
#include <LAppDefine.hpp>  // For LAppDefine::CubismLoggingLevel
#include <cstring>
#include <cstdio>
#include <windows.h>

using namespace Live2D::Cubism::Framework;

// Global allocator
static LAppAllocator_Common s_allocator;

// Convert L2D_Model to LAppModel_CalcOnly
static LAppModel_CalcOnly* GetModel(L2D_Model m)
{
    return reinterpret_cast<LAppModel_CalcOnly*>(m);
}

// ===== Lifecycle =====

L2D_API L2D_Model l2d_load_model(const char* dir, const char* fileName)
{
    OutputDebugStringA("[L2D-CPP] l2d_load_model BEGIN\r\n");
    char buf[512];
    sprintf_s(buf, "[L2D-CPP] dir=%s, fileName=%s\r\n", dir, fileName);
    OutputDebugStringA(buf);

    OutputDebugStringA("[L2D-CPP] Creating LAppModel_CalcOnly...\r\n");
    LAppModel_CalcOnly* model = new LAppModel_CalcOnly();

    OutputDebugStringA("[L2D-CPP] Calling LoadAssets...\r\n");
    model->LoadAssets(dir, fileName);

    if (model->GetModel() == NULL)
    {
        OutputDebugStringA("[L2D-CPP] LoadAssets failed, model is NULL. Deleting and returning NULL.\r\n");
        delete model;
        return NULL;
    }

    OutputDebugStringA("[L2D-CPP] LoadAssets completed\r\n");
    return reinterpret_cast<L2D_Model>(model);
}

L2D_API void l2d_release_model(L2D_Model m)
{
    if (m == NULL) return;
    LAppModel_CalcOnly* model = GetModel(m);
    delete model;
}

// ===== Framework Initialization/Cleanup =====

// Global option for CubismFramework
static CubismFramework::Option s_option;

L2D_API int l2d_test_add(int a, int b)
{
    OutputDebugStringA("[L2D-CPP] l2d_test_add called\r\n");
    return a + b;
}

L2D_API void l2d_framework_start_up()
{
    OutputDebugStringA("[L2D-CPP] l2d_framework_start_up BEGIN\r\n");

    OutputDebugStringA("[L2D-CPP] Setting up option...\r\n");
    s_option.LogFunction = LAppPal_CalcOnly::PrintMessage;
    s_option.LoggingLevel = LAppDefine::CubismLoggingLevel;
    s_option.LoadFileFunction = LAppPal_CalcOnly::LoadFileAsBytes;
    s_option.ReleaseBytesFunction = LAppPal_CalcOnly::ReleaseBytes;

    OutputDebugStringA("[L2D-CPP] Calling CubismFramework::StartUp...\r\n");
    csmBool result = CubismFramework::StartUp(&s_allocator, &s_option);
    char buf[256];
    sprintf_s(buf, "[L2D-CPP] StartUp returned: %d\r\n", (int)result);
    OutputDebugStringA(buf);

    OutputDebugStringA("[L2D-CPP] Calling CubismFramework::Initialize...\r\n");
    CubismFramework::Initialize();

    OutputDebugStringA("[L2D-CPP] l2d_framework_start_up END\r\n");
}

L2D_API void l2d_framework_clean_up()
{
    CubismFramework::Dispose();
    CubismFramework::CleanUp();
}

// ===== Update =====

L2D_API void l2d_update(L2D_Model m)
{
    if (m == NULL) return;
    GetModel(m)->Update();
}

L2D_API void l2d_set_delta_time(float dt)
{
    LAppPal_CalcOnly::SetDeltaTime(dt);
}

// ===== Parameters =====

L2D_API int l2d_get_parameter_count(L2D_Model m)
{
    if (m == NULL) return 0;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetParameterCount();
}

L2D_API int l2d_find_parameter_index(L2D_Model m, const char* name)
{
    if (m == NULL || name == NULL) return -1;
    CubismModel* model = GetModel(m)->GetModel();
    CubismIdHandle id = CubismFramework::GetIdManager()->GetId(name);
    return model->GetParameterIndex(id);
}

L2D_API float l2d_get_parameter_value(L2D_Model m, int index)
{
    if (m == NULL) return 0.0f;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetParameterValue(index);
}

L2D_API void l2d_set_parameter_value(L2D_Model m, int index, float value, float weight)
{
    if (m == NULL) return;
    CubismModel* model = GetModel(m)->GetModel();
    model->SetParameterValue(index, value, weight);
}

// ===== Animation =====

// CubismMotionQueueEntryHandle is `void*` (64-bit on x64): each entry stores
// `this` pointer as its handle. The Haxe side passes handles as 32-bit Int,
// so a direct cast truncates the high 32 bits and IsFinished() can never
// match the entry — it always returns true ("finished"). We therefore map
// 64-bit native handles to 32-bit IDs at this boundary.
static std::unordered_map<int32_t, CubismMotionQueueEntryHandle> g_motionHandleMap;
static int32_t g_nextMotionHandleId = 1;

L2D_API intptr_t l2d_start_motion(L2D_Model m, const char* group, int no, int priority)
{
    if (m == NULL || group == NULL) return -1;
    CubismMotionQueueEntryHandle handle = GetModel(m)->StartMotion(group, no, priority);
    if (handle == InvalidMotionQueueEntryHandleValue) return -1;
    int32_t id = g_nextMotionHandleId++;
    g_motionHandleMap[id] = handle;
    return static_cast<intptr_t>(id);
}

L2D_API intptr_t l2d_start_random_motion(L2D_Model m, const char* group, int priority)
{
    if (m == NULL || group == NULL) return -1;
    CubismMotionQueueEntryHandle handle = GetModel(m)->StartRandomMotion(group, priority);
    if (handle == InvalidMotionQueueEntryHandleValue) return -1;
    int32_t id = g_nextMotionHandleId++;
    g_motionHandleMap[id] = handle;
    return static_cast<intptr_t>(id);
}

L2D_API bool l2d_is_motion_finished(L2D_Model m, intptr_t motionHandle)
{
    if (m == NULL) return true;
    int32_t id = static_cast<int32_t>(motionHandle);
    if (id <= 0) return true;
    auto it = g_motionHandleMap.find(id);
    if (it == g_motionHandleMap.end()) return true;
    CubismMotionQueueEntryHandle handle = it->second;
    bool finished = GetModel(m)->IsMotionFinished(handle);
    if (finished)
    {
        g_motionHandleMap.erase(it);
    }
    return finished;
}

// ===== Expression =====

L2D_API void l2d_set_expression(L2D_Model m, const char* expressionID)
{
    if (m == NULL || expressionID == NULL) return;
    GetModel(m)->SetExpression(expressionID);
}

L2D_API void l2d_set_random_expression(L2D_Model m)
{
    if (m == NULL) return;
    GetModel(m)->SetRandomExpression();
}

// ===== Interaction =====

L2D_API bool l2d_hit_test(L2D_Model m, const char* areaName, float x, float y)
{
    if (m == NULL || areaName == NULL) return false;
    return GetModel(m)->HitTest(areaName, x, y);
}

L2D_API void l2d_set_dragging(L2D_Model m, float x, float y)
{
    if (m == NULL) return;
    GetModel(m)->SetDragging(x, y);
}

// ===== Drawable Data =====

L2D_API int l2d_get_drawable_count(L2D_Model m)
{
    if (m == NULL) return 0;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetDrawableCount();
}

L2D_API int l2d_get_drawable_vertex_count(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return 0;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetDrawableVertexCount(drawableIndex);
}

L2D_API void l2d_get_drawable_vertex_positions(L2D_Model m, int drawableIndex, float* outBuf)
{
    if (m == NULL || outBuf == NULL) return;
    CubismModel* model = GetModel(m)->GetModel();
    const csmFloat32* vertices = model->GetDrawableVertices(drawableIndex);
    int count = model->GetDrawableVertexCount(drawableIndex) * 2;
    memcpy(outBuf, vertices, count * sizeof(float));
}

L2D_API void l2d_get_drawable_vertex_uvs(L2D_Model m, int drawableIndex, float* outBuf)
{
    if (m == NULL || outBuf == NULL) return;
    CubismModel* model = GetModel(m)->GetModel();
    const Live2D::Cubism::Core::csmVector2* uvs = model->GetDrawableVertexUvs(drawableIndex);
    int count = model->GetDrawableVertexCount(drawableIndex);
    for (int i = 0; i < count; i++)
    {
        outBuf[i * 2] = uvs[i].X;
        outBuf[i * 2 + 1] = uvs[i].Y;
    }
}

L2D_API int l2d_get_drawable_index_count(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return 0;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetDrawableVertexIndexCount(drawableIndex);
}

L2D_API void l2d_get_drawable_indices(L2D_Model m, int drawableIndex, uint16_t* outBuf)
{
    if (m == NULL || outBuf == NULL) return;
    CubismModel* model = GetModel(m)->GetModel();
    const csmUint16* indices = model->GetDrawableVertexIndices(drawableIndex);
    int count = model->GetDrawableVertexIndexCount(drawableIndex);
    memcpy(outBuf, indices, count * sizeof(uint16_t));
}

L2D_API float l2d_get_drawable_opacity(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return 0.0f;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetDrawableOpacity(drawableIndex);
}

L2D_API int l2d_get_drawable_render_order(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return 0;
    CubismModel* model = GetModel(m)->GetModel();
    const csmInt32* renderOrders = model->GetRenderOrders();
    return renderOrders[drawableIndex];
}

L2D_API int l2d_get_drawable_texture_index(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return -1;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetDrawableTextureIndex(drawableIndex);
}

L2D_API bool l2d_is_drawable_visible(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return false;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetDrawableDynamicFlagIsVisible(drawableIndex);
}

L2D_API void l2d_get_drawable_multiply_color(L2D_Model m, int drawableIndex, float* outRGBA)
{
    if (m == NULL || outRGBA == NULL) return;
    CubismModel* model = GetModel(m)->GetModel();
    auto color = model->GetDrawableMultiplyColor(drawableIndex);
    outRGBA[0] = color.X;
    outRGBA[1] = color.Y;
    outRGBA[2] = color.Z;
    outRGBA[3] = color.W;
}

L2D_API void l2d_get_drawable_screen_color(L2D_Model m, int drawableIndex, float* outRGBA)
{
    if (m == NULL || outRGBA == NULL) return;
    CubismModel* model = GetModel(m)->GetModel();
    auto color = model->GetDrawableScreenColor(drawableIndex);
    outRGBA[0] = color.X;
    outRGBA[1] = color.Y;
    outRGBA[2] = color.Z;
    outRGBA[3] = color.W;
}

L2D_API int l2d_get_drawable_blend_mode(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return 0;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetDrawableBlendModeType(drawableIndex).GetColorBlendType();
}

// ===== Mask =====

L2D_API int l2d_get_drawable_mask_count(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return 0;
    CubismModel* model = GetModel(m)->GetModel();
    const csmInt32* maskCounts = model->GetDrawableMaskCounts();
    return maskCounts[drawableIndex];
}

L2D_API void l2d_get_drawable_masks(L2D_Model m, int drawableIndex, int* outBuf)
{
    if (m == NULL || outBuf == NULL) return;
    CubismModel* model = GetModel(m)->GetModel();
    const csmInt32** masks = model->GetDrawableMasks();
    const csmInt32* maskCounts = model->GetDrawableMaskCounts();
    int count = maskCounts[drawableIndex];
    memcpy(outBuf, masks[drawableIndex], count * sizeof(int));
}

L2D_API bool l2d_get_drawable_inverted_mask(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return false;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetDrawableInvertedMask(drawableIndex);
}

L2D_API bool l2d_get_drawable_dynamic_flag_vertex_positions_did_change(L2D_Model m, int drawableIndex)
{
    if (m == NULL) return false;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetDrawableDynamicFlagVertexPositionsDidChange(drawableIndex);
}

// ===== Batch Metadata =====

L2D_API void l2d_get_drawable_batch_metadata(L2D_Model m, int count, char* outBuf)
{
    if (m == NULL || outBuf == NULL || count <= 0) return;
    CubismModel* model = GetModel(m)->GetModel();
    if (model == NULL) return;

    const csmInt32* renderOrders = model->GetRenderOrders();

    // Per drawable: visible(i32) + renderOrder(i32) + opacity(f32) + textureIndex(i32) + blendMode(i32) + mulRGB(3xf32) + scrRGB(3xf32) + vertexDidChange(i32) = 48 bytes
    for (int i = 0; i < count; i++)
    {
        int offset = i * 48;
        int32_t visible = model->GetDrawableDynamicFlagIsVisible(i) ? 1 : 0;
        memcpy(outBuf + offset, &visible, 4);
        memcpy(outBuf + offset + 4, &renderOrders[i], 4);
        float opacity = model->GetDrawableOpacity(i);
        memcpy(outBuf + offset + 8, &opacity, 4);
        int32_t texIdx = model->GetDrawableTextureIndex(i);
        memcpy(outBuf + offset + 12, &texIdx, 4);
        int32_t blendMode = model->GetDrawableBlendModeType(i).GetColorBlendType();
        memcpy(outBuf + offset + 16, &blendMode, 4);
        auto mulColor = model->GetDrawableMultiplyColor(i);
        memcpy(outBuf + offset + 20, &mulColor.X, 4);
        memcpy(outBuf + offset + 24, &mulColor.Y, 4);
        memcpy(outBuf + offset + 28, &mulColor.Z, 4);
        auto scrColor = model->GetDrawableScreenColor(i);
        memcpy(outBuf + offset + 32, &scrColor.X, 4);
        memcpy(outBuf + offset + 36, &scrColor.Y, 4);
        memcpy(outBuf + offset + 40, &scrColor.Z, 4);
        int32_t vertChanged = model->GetDrawableDynamicFlagVertexPositionsDidChange(i) ? 1 : 0;
        memcpy(outBuf + offset + 44, &vertChanged, 4);
    }
}

// ===== Texture Path =====

L2D_API int l2d_get_texture_count(L2D_Model m)
{
    if (m == NULL) return 0;
    return GetModel(m)->GetTextureCount();
}

L2D_API void l2d_get_texture_path(L2D_Model m, int textureIndex, char* outBuf, int bufLen)
{
    if (m == NULL || outBuf == NULL) 
    {
        if (outBuf != NULL && bufLen > 0) outBuf[0] = '\0';
        return;
    }
    GetModel(m)->GetTexturePath(textureIndex, outBuf, bufLen);
}

// ===== Model Info =====

L2D_API float l2d_get_canvas_width(L2D_Model m)
{
    if (m == NULL) return 0.0f;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetCanvasWidthPixel();
}

L2D_API float l2d_get_canvas_height(L2D_Model m)
{
    if (m == NULL) return 0.0f;
    CubismModel* model = GetModel(m)->GetModel();
    return model->GetCanvasHeightPixel();
}

// ===== Framework Behavior Control =====

L2D_API void l2d_set_breath_enabled(L2D_Model m, bool enabled)
{
    if (m == NULL) return;
    GetModel(m)->SetBreathEnabled(enabled);
}

L2D_API void l2d_set_eye_blink_enabled(L2D_Model m, bool enabled)
{
    if (m == NULL) return;
    GetModel(m)->SetEyeBlinkEnabled(enabled);
}

L2D_API void l2d_set_expression_enabled(L2D_Model m, bool enabled)
{
    if (m == NULL) return;
    GetModel(m)->SetExpressionEnabled(enabled);
}

L2D_API void l2d_set_look_enabled(L2D_Model m, bool enabled)
{
    if (m == NULL) return;
    GetModel(m)->SetLookEnabled(enabled);
}

L2D_API void l2d_set_physics_enabled(L2D_Model m, bool enabled)
{
    if (m == NULL) return;
    GetModel(m)->SetPhysicsEnabled(enabled);
}

L2D_API void l2d_set_lip_sync_enabled(L2D_Model m, bool enabled)
{
    if (m == NULL) return;
    GetModel(m)->SetLipSyncEnabled(enabled);
}

L2D_API void l2d_set_pose_enabled(L2D_Model m, bool enabled)
{
    if (m == NULL) return;
    GetModel(m)->SetPoseEnabled(enabled);
}

// ===== LipSync Value =====

L2D_API void l2d_set_lip_sync_value(L2D_Model m, float value)
{
    if (m == NULL) return;
    GetModel(m)->SetLipSyncValue(value);
}

// ===== Moc Version Checking =====

L2D_API unsigned int l2d_get_core_version()
{
    return Live2D::Cubism::Core::csmGetVersion();
}

L2D_API unsigned int l2d_get_latest_moc_version()
{
    return Live2D::Cubism::Core::csmGetLatestMocVersion();
}

L2D_API bool l2d_has_moc_consistency(const char* mocFilePath)
{
    if (mocFilePath == NULL)
    {
        OutputDebugStringA("[L2D-CPP] l2d_has_moc_consistency: NULL path\r\n");
        return false;
    }

    // Read moc3 file directly and check consistency (no model loading needed)
    std::ifstream file(mocFilePath, std::ios::binary | std::ios::ate);
    if (!file.is_open())
    {
        char buf[512];
        sprintf_s(buf, "[L2D-CPP] l2d_has_moc_consistency: failed to open file: %s\r\n", mocFilePath);
        OutputDebugStringA(buf);
        return false;
    }

    auto size = file.tellg();
    if (size <= 0)
    {
        char buf[512];
        sprintf_s(buf, "[L2D-CPP] l2d_has_moc_consistency: file is empty: %s\r\n", mocFilePath);
        OutputDebugStringA(buf);
        return false;
    }

    file.seekg(0, std::ios::beg);

    std::vector<char> buffer(size);
    if (!file.read(buffer.data(), size))
    {
        char buf[512];
        sprintf_s(buf, "[L2D-CPP] l2d_has_moc_consistency: failed to read file: %s\r\n", mocFilePath);
        OutputDebugStringA(buf);
        return false;
    }
    file.close();

    bool result = CubismMoc::HasMocConsistencyFromUnrevivedMoc(
        reinterpret_cast<csmByte*>(buffer.data()),
        static_cast<csmSizeInt>(size)
    );

    char buf[512];
    sprintf_s(buf, "[L2D-CPP] l2d_has_moc_consistency: %s -> %s (size=%lld)\r\n",
        mocFilePath, result ? "PASS" : "FAIL", (long long)size);
    OutputDebugStringA(buf);

    return result;
}
