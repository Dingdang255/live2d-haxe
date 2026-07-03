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

L2D_API intptr_t l2d_start_motion(L2D_Model m, const char* group, int no, int priority)
{
    if (m == NULL || group == NULL) return -1;
    CubismMotionQueueEntryHandle handle = GetModel(m)->StartMotion(group, no, priority);
    return reinterpret_cast<intptr_t>(handle);
}

L2D_API intptr_t l2d_start_random_motion(L2D_Model m, const char* group, int priority)
{
    if (m == NULL || group == NULL) return -1;
    CubismMotionQueueEntryHandle handle = GetModel(m)->StartRandomMotion(group, priority);
    return reinterpret_cast<intptr_t>(handle);
}

L2D_API bool l2d_is_motion_finished(L2D_Model m, intptr_t motionHandle)
{
    if (m == NULL) return true;
    CubismMotionQueueEntryHandle handle = reinterpret_cast<CubismMotionQueueEntryHandle>(motionHandle);
    return GetModel(m)->IsMotionFinished(handle);
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
