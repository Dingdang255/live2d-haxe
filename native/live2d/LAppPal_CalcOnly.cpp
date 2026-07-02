/**
 * Live2D Cubism SDK for Native - CalcOnly version
 * Simplified LAppPal implementation, no GLFW dependency
 * 
 * Copyright(c) Live2D Inc. All rights reserved.
 * Use of this source code is governed by the Live2D Open Software license.
 */

#include "LAppPal_CalcOnly.hpp"
#include <windows.h>
#include <cstdio>
#include <stdarg.h>
#include <sys/stat.h>
#include <iostream>
#include <fstream>

using std::endl;
using namespace Csm;
using namespace std;

Csm::csmFloat32 LAppPal_CalcOnly::s_deltaTime = 0.0f;

csmFloat32 LAppPal_CalcOnly::GetDeltaTime()
{
    return s_deltaTime;
}

void LAppPal_CalcOnly::SetDeltaTime(csmFloat32 dt)
{
    s_deltaTime = dt;
}

void LAppPal_CalcOnly::PrintLog(const csmChar* format, ...)
{
    va_list args;
    csmChar buf[256];
    va_start(args, format);
    vsnprintf_s(buf, sizeof(buf), format, args);
    std::cout << buf;
    va_end(args);
}

void LAppPal_CalcOnly::PrintLogLn(const Csm::csmChar* format, ...)
{
    va_list args;
    csmChar buf[256];
    va_start(args, format);
    vsnprintf_s(buf, sizeof(buf), format, args);
    std::cout << buf << std::endl;
    va_end(args);
}

void LAppPal_CalcOnly::PrintMessage(const Csm::csmChar* message)
{
    PrintLog("%s", message);
}

void LAppPal_CalcOnly::PrintMessageLn(const Csm::csmChar* message)
{
    PrintLogLn("%s", message);
}

Csm::csmByte* LAppPal_CalcOnly::LoadFileAsBytes(const std::string filePath, Csm::csmSizeInt* outSize)
{
    wchar_t wideStr[MAX_PATH];
    MultiByteToWideChar(CP_UTF8, 0U, filePath.c_str(), -1, wideStr, MAX_PATH);

    int size = 0;
    struct _stat statBuf;
    if (_wstat(wideStr, &statBuf) == 0)
    {
        size = statBuf.st_size;
        if (size == 0)
        {
            PrintLogLn("Stat succeeded but file size is zero. path:%s", filePath.c_str());
            return NULL;
        }
    }
    else
    {
        PrintLogLn("Stat failed. errno:%d path:%s", errno, filePath.c_str());
        return NULL;
    }

    std::wfstream file;
    file.open(wideStr, std::ios::in | std::ios::binary);
    if (!file.is_open())
    {
        PrintLogLn("File open failed. path:%s", filePath.c_str());
        return NULL;
    }

    *outSize = size;
    csmChar* buf = new char[*outSize];
    std::wfilebuf* fileBuf = file.rdbuf();
    for (Csm::csmUint32 i = 0; i < *outSize; i++)
    {
        buf[i] = fileBuf->sbumpc();
    }
    file.close();

    return reinterpret_cast<Csm::csmByte*>(buf);
}

void LAppPal_CalcOnly::ReleaseBytes(Csm::csmByte* byteData)
{
    delete[] byteData;
}

bool LAppPal_CalcOnly::ConvertMultiByteToWide(const csmChar* multiByte, wchar_t* wide, int wideSize)
{
    return MultiByteToWideChar(CP_UTF8, 0U, multiByte, -1, wide, wideSize) != 0;
}

bool LAppPal_CalcOnly::ConvertWideToMultiByte(const wchar_t* wide, csmChar* multiByte, int multiByteSize)
{
    return WideCharToMultiByte(CP_UTF8, 0U, wide, -1, multiByte, multiByteSize, NULL, NULL) != 0;
}
