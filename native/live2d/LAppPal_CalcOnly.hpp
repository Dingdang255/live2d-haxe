/**
 * Live2D Cubism SDK for Native - CalcOnly version
 * Simplified LAppPal implementation, no GLFW dependency
 * 
 * Copyright(c) Live2D Inc. All rights reserved.
 * Use of this source code is governed by the Live2D Open Software license.
 */

#pragma once

#include <CubismFramework.hpp>
#include <string>

class LAppPal_CalcOnly
{
public:
    /**
     * Get delta time
     * Note: returns externally set deltaTime
     */
    static Csm::csmFloat32 GetDeltaTime();

    /**
     * Set delta time externally (called from Haxe side)
     */
    static void SetDeltaTime(Csm::csmFloat32 dt);

    /**
     * Output log
     */
    static void PrintLog(const Csm::csmChar* format, ...);

    /**
     * Output log with newline
     */
    static void PrintLogLn(const Csm::csmChar* format, ...);

    /**
     * Log output function for CubismFramework (fixed parameter version)
     * For passing to csmLogFunction
     */
    static void PrintMessage(const Csm::csmChar* message);

    /**
     * Log output function for CubismFramework (fixed parameter version, with newline)
     */
    static void PrintMessageLn(const Csm::csmChar* message);

    /**
     * Read file as byte data
     * For CubismFramework::StartUp LoadFileFunction
     * Note: csmLoadFileFunction signature requires std::string parameter
     */
    static Csm::csmByte* LoadFileAsBytes(const std::string filePath, Csm::csmSizeInt* outSize);

    /**
     * Release byte data
     * For CubismFramework::StartUp ReleaseBytesFunction
     */
    static void ReleaseBytes(Csm::csmByte* byteData);

    /**
     * Convert multibyte to wide character
     */
    static bool ConvertMultiByteToWide(const Csm::csmChar* multiByte, wchar_t* wide, int wideSize);

    /**
     * Convert wide character to multibyte
     */
    static bool ConvertWideToMultiByte(const wchar_t* wide, Csm::csmChar* multiByte, int multiByteSize);

private:
    static Csm::csmFloat32 s_deltaTime;
};
