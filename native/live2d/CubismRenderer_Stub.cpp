/**
 * CubismRenderer Stub Implementation
 * Provides empty implementations for Create and StaticRelease
 * 
 * Copyright(c) Live2D Inc. All rights reserved.
 */

#include <Rendering/CubismRenderer.hpp>

namespace Live2D { namespace Cubism { namespace Framework { namespace Rendering {

// Stub implementation - returns NULL since we don't use renderer
CubismRenderer* CubismRenderer::Create(csmUint32 width, csmUint32 height)
{
    // CalcOnly mode: no renderer needed
    return NULL;
}

// Stub implementation - does nothing
void CubismRenderer::StaticRelease()
{
    // CalcOnly mode: no renderer resources to release
}

}}}}
