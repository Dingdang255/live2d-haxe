/**
 * LAppPal Implementation without OpenGL/GLFW dependency
 * Compatible with SDK Common interface
 * 
 * Copyright(c) Live2D Inc. All rights reserved.
 * Use of this source code is governed by the Live2D Open Software license.
 */

// Include the SDK's LAppPal.hpp from OpenGL Demo directory
#include <LAppPal.hpp>
#include <windows.h>
#include <cstdio>
#include <stdarg.h>
#include <sys/stat.h>
#include <iostream>
#include <fstream>

using std::endl;
using namespace Csm;
using namespace std;

double LAppPal::s_currentFrame = 0.0;
double LAppPal::s_lastFrame = 0.0;
double LAppPal::s_deltaTime = 0.0;
#ifdef CSM_FIXED_FRAME_RATE
int LAppPal::s_frame = 0;
#endif

csmByte* LAppPal::LoadFileAsBytes(const string filePath, csmSizeInt* outSize)
{
    int size = 0;
    struct _stat statBuf;
    if (_stat(filePath.c_str(), &statBuf) == 0)
    {
        size = statBuf.st_size;
        if (size == 0)
        {
            return NULL;
        }
    }
    else
    {
        return NULL;
    }

    std::ifstream file(filePath, std::ios::binary);
    if (!file.is_open())
    {
        return NULL;
    }

    *outSize = size;
    csmChar* buf = new char[*outSize];
    file.read(buf, *outSize);
    file.close();

    return reinterpret_cast<csmByte*>(buf);
}

void LAppPal::ReleaseBytes(csmByte* byteData)
{
    delete[] byteData;
}

csmFloat32 LAppPal::GetDeltaTime()
{
    return static_cast<csmFloat32>(s_deltaTime);
}

void LAppPal::UpdateTime()
{
    // No GLFW, so we don't update time automatically
    // This can be called from external code
}

void LAppPal::PrintLog(const csmChar* format, ...)
{
    va_list args;
    csmChar buf[256];
    va_start(args, format);
    vsnprintf_s(buf, sizeof(buf), format, args);
    std::cout << buf;
    va_end(args);
}

void LAppPal::PrintLogLn(const csmChar* format, ...)
{
    va_list args;
    csmChar buf[256];
    va_start(args, format);
    vsnprintf_s(buf, sizeof(buf), format, args);
    std::cout << buf << std::endl;
    va_end(args);
}

void LAppPal::PrintMessage(const csmChar* message)
{
    std::cout << message;
}

void LAppPal::PrintMessageLn(const csmChar* message)
{
    std::cout << message << std::endl;
}

bool LAppPal::ConvertMultiByteToWide(const csmChar* multiByte, wchar_t* wide, int wideSize)
{
    return MultiByteToWideChar(CP_UTF8, 0U, multiByte, -1, wide, wideSize) != 0;
}

bool LAppPal::ConvertWideToMultiByte(const wchar_t* wide, csmChar* multiByte, int multiByteSize)
{
    return WideCharToMultiByte(CP_UTF8, 0U, wide, -1, multiByte, multiByteSize, NULL, NULL) != 0;
}
