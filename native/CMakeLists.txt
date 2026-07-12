cmake_minimum_required(VERSION 3.16)
project(live2d_capi LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================
# Cubism SDK Path Configuration
# ============================================================
# Set CUBISM_ROOT to your local Cubism SDK for Native installation.
# Download from: https://www.live2d.com/download/cubism-sdk/download-native/
# Default: expects the SDK next to this project directory.
#
# You can override this by passing -DCUBISM_ROOT=/path/to/CubismSdkForNative-5-r.5
# ============================================================
if(NOT DEFINED CUBISM_ROOT)
    set(CUBISM_ROOT "${CMAKE_SOURCE_DIR}/../CubismSdkForNative-5-r.5")
endif()

message(STATUS "CUBISM_ROOT = ${CUBISM_ROOT}")

if(NOT EXISTS "${CUBISM_ROOT}/Framework/src/CubismFramework.cpp")
    message(FATAL_ERROR
        "Cubism SDK not found at CUBISM_ROOT=${CUBISM_ROOT}\n"
        "Please download the Cubism SDK for Native from https://www.live2d.com/download/cubism-sdk/download-native/\n"
        "and set CUBISM_ROOT to the extracted directory, e.g.:\n"
        "  cmake -DCUBISM_ROOT=C:/path/to/CubismSdkForNative-5-r.5 .."
    )
endif()

# ===== 1) Framework source files =====
set(FRAMEWORK_SRC
  # Core framework
  ${CUBISM_ROOT}/Framework/src/CubismFramework.cpp
  ${CUBISM_ROOT}/Framework/src/CubismDefaultParameterId.cpp
  ${CUBISM_ROOT}/Framework/src/CubismCdiJson.cpp
  ${CUBISM_ROOT}/Framework/src/CubismModelSettingJson.cpp
  
  # Effect
  ${CUBISM_ROOT}/Framework/src/Effect/CubismBreath.cpp
  ${CUBISM_ROOT}/Framework/src/Effect/CubismPose.cpp
  ${CUBISM_ROOT}/Framework/src/Effect/CubismLook.cpp
  ${CUBISM_ROOT}/Framework/src/Effect/CubismEyeBlink.cpp
  
  # Id
  ${CUBISM_ROOT}/Framework/src/Id/CubismIdManager.cpp
  ${CUBISM_ROOT}/Framework/src/Id/CubismId.cpp
  
  # Math
  ${CUBISM_ROOT}/Framework/src/Math/CubismViewMatrix.cpp
  ${CUBISM_ROOT}/Framework/src/Math/CubismVector2.cpp
  ${CUBISM_ROOT}/Framework/src/Math/CubismTargetPoint.cpp
  ${CUBISM_ROOT}/Framework/src/Math/CubismModelMatrix.cpp
  ${CUBISM_ROOT}/Framework/src/Math/CubismMatrix44.cpp
  ${CUBISM_ROOT}/Framework/src/Math/CubismMath.cpp
  
  # Model
  ${CUBISM_ROOT}/Framework/src/Model/CubismUserModel.cpp
  ${CUBISM_ROOT}/Framework/src/Model/CubismModelUserDataJson.cpp
  ${CUBISM_ROOT}/Framework/src/Model/CubismModelUserData.cpp
  ${CUBISM_ROOT}/Framework/src/Model/CubismModelMultiplyAndScreenColor.cpp
  ${CUBISM_ROOT}/Framework/src/Model/CubismModel.cpp
  ${CUBISM_ROOT}/Framework/src/Model/CubismMoc.cpp
  
  # Motion
  ${CUBISM_ROOT}/Framework/src/Motion/ACubismMotion.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismBreathUpdater.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismExpressionMotion.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismExpressionMotionManager.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismExpressionUpdater.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismEyeBlinkUpdater.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismLipSyncUpdater.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismLookUpdater.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismMotion.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismMotionJson.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismMotionManager.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismMotionQueueEntry.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismMotionQueueManager.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismPhysicsUpdater.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismPoseUpdater.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/CubismUpdateScheduler.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/ICubismUpdater.cpp
  ${CUBISM_ROOT}/Framework/src/Motion/IParameterProvider.cpp
  
  # Physics
  ${CUBISM_ROOT}/Framework/src/Physics/CubismPhysics.cpp
  ${CUBISM_ROOT}/Framework/src/Physics/CubismPhysicsJson.cpp
  
  # Rendering (core files + stub implementation)
  ${CUBISM_ROOT}/Framework/src/Rendering/CubismRenderer.cpp
  ${CUBISM_ROOT}/Framework/src/Rendering/csmBlendMode.cpp
  live2d/CubismRenderer_Stub.cpp
  
  # Type
  ${CUBISM_ROOT}/Framework/src/Type/csmString.cpp
  ${CUBISM_ROOT}/Framework/src/Type/csmRectF.cpp
  
  # Utils
  ${CUBISM_ROOT}/Framework/src/Utils/CubismString.cpp
  ${CUBISM_ROOT}/Framework/src/Utils/CubismJson.cpp
  ${CUBISM_ROOT}/Framework/src/Utils/CubismDebug.cpp
)

add_library(Live2DFramework STATIC ${FRAMEWORK_SRC})
target_include_directories(Live2DFramework PUBLIC
  ${CUBISM_ROOT}/Framework/src
  ${CUBISM_ROOT}/Core/include
)

# ===== 2) Common sources =====
# Use our LAppPal_NoGL.cpp instead of SDK's LAppPal.cpp (no OpenGL dependency)
set(COMMON_SRC
  ${CUBISM_ROOT}/Samples/Common/LAppModel_Common.cpp
  ${CUBISM_ROOT}/Samples/Common/LAppAllocator_Common.cpp
  ${CUBISM_ROOT}/Samples/Common/LAppTextureManager_Common.cpp
  ${CUBISM_ROOT}/Samples/Common/LAppWavFileHandler_Common.cpp
  ${CUBISM_ROOT}/Samples/Common/TouchManager_Common.cpp
  ${CUBISM_ROOT}/Samples/Common/MouseActionManager_Common.cpp
  ${CUBISM_ROOT}/Samples/Common/LAppView_Common.cpp
  ${CUBISM_ROOT}/Samples/Common/CubismSampleViewMatrix_Common.cpp
  ${CUBISM_ROOT}/Samples/Common/LAppSprite_Common.cpp
  # No-OpenGL LAppPal implementation
  live2d/LAppPal_NoGL.cpp
  # SDK Demo LAppDefine (Common depends on it)
  ${CUBISM_ROOT}/Samples/OpenGL/Demo/proj.win.cmake/src/LAppDefine.cpp
)
add_library(Live2DCommon STATIC ${COMMON_SRC})
target_include_directories(Live2DCommon PUBLIC
  ${CUBISM_ROOT}/Framework/src
  ${CUBISM_ROOT}/Core/include
  ${CUBISM_ROOT}/Samples/Common
  ${CUBISM_ROOT}/Samples/OpenGL/Demo/proj.win.cmake/src
)

# ===== 3) Core library (provided by SDK) =====
if(MSVC_VERSION GREATER_EQUAL 1930 AND MSVC_VERSION LESS 1950)
  set(COMPILER 143)
elseif(MSVC_VERSION GREATER_EQUAL 1920 AND MSVC_VERSION LESS 1930)
  set(COMPILER 142)
elseif(MSVC_VERSION GREATER_EQUAL 1910 AND MSVC_VERSION LESS 1920)
  set(COMPILER 141)
else()
  set(COMPILER 142)
endif()

set(CORE_LIB_DIR "${CUBISM_ROOT}/Core/lib/windows/x86_64/${COMPILER}")
set(CORE_LIB_DEBUG "${CORE_LIB_DIR}/Live2DCubismCore_MTd.lib")
set(CORE_LIB_RELEASE "${CORE_LIB_DIR}/Live2DCubismCore_MT.lib")

add_library(Live2DCubismCore STATIC IMPORTED)
set_target_properties(Live2DCubismCore PROPERTIES
  IMPORTED_LOCATION "${CORE_LIB_RELEASE}"
  IMPORTED_LOCATION_DEBUG "${CORE_LIB_DEBUG}"
  IMPORTED_LOCATION_RELEASE "${CORE_LIB_RELEASE}"
  IMPORTED_LOCATION_MINSIZEREL "${CORE_LIB_RELEASE}"
  IMPORTED_LOCATION_RELWITHDEBINFO "${CORE_LIB_RELEASE}"
  INTERFACE_INCLUDE_DIRECTORIES "${CUBISM_ROOT}/Core/include"
)

# ===== 4) capi DLL =====
add_library(live2d_capi SHARED
  live2d/live2d_capi.cpp
  live2d/LAppModel_CalcOnly.cpp
  live2d/LAppPal_CalcOnly.cpp
)
target_include_directories(live2d_capi PUBLIC
  ${CUBISM_ROOT}/Core/include
  ${CUBISM_ROOT}/Framework/src
  ${CUBISM_ROOT}/Samples/Common
  live2d
)
target_link_libraries(live2d_capi PUBLIC
  Live2DFramework
  Live2DCommon
  Live2DCubismCore
)
# Suppress LNK4098: LIBCMT conflict (/MT vs /MD mixing)
target_link_options(live2d_capi PRIVATE "/NODEFAULTLIB:LIBCMT")

# Output directory
set_target_properties(live2d_capi PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../lib/win"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../lib/win"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../lib/win"
)

# Post-build: copy Live2DCubismCore.dll to output
add_custom_command(TARGET live2d_capi POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CUBISM_ROOT}/Core/dll/windows/x86_64/Live2DCubismCore.dll"
    "${CMAKE_SOURCE_DIR}/../lib/win/Live2DCubismCore.dll"
  COMMENT "Copying Live2DCubismCore.dll to output directory"
)

# ============================================================
# 5) HashLink .hdll target
# ============================================================
# Builds live2d_hl.hdll — a thin shim that dynamically loads
# live2d_capi.dll at runtime and forwards calls via HL_PRIM.
#
# HL SDK auto-detection:
#   1. -DHL_ROOT=path — explicit override (must contain include/hl.h)
#   2. Auto-search installed Lime versions for include/hl.h
#
# Note: The .hdll only uses hl.h for type definitions and macros
# (HL_PRIM, DEFINE_PRIM). It does NOT call any hl_* functions at
# runtime, so a .hdll compiled against one HL version is compatible
# with any HL runtime (Lime 8.0.1 or 8.3.0) that loads it.
# ============================================================

# Auto-detect HL_ROOT if not specified
if(NOT DEFINED HL_ROOT)
    set(_HL_SEARCH_PATHS
      "${CMAKE_SOURCE_DIR}/../../../lime/8,3,0/templates/bin/hl"
      "${CMAKE_SOURCE_DIR}/../../../lime/8,0,1/templates/bin/hl"
    )
    foreach(_p ${_HL_SEARCH_PATHS})
        if(EXISTS "${_p}/include/hl.h")
            set(HL_ROOT "${_p}")
            break()
        endif()
    endforeach()
    if(NOT DEFINED HL_ROOT)
        # No Lime version has include/hl.h — try without it
        # (will use bundled hl.h if available)
        foreach(_p ${_HL_SEARCH_PATHS})
            if(EXISTS "${_p}/Windows64/libhl.lib")
                set(HL_ROOT "${_p}")
                set(HL_NO_INCLUDE ON)
                break()
            endif()
        endforeach()
    endif()
endif()

message(STATUS "HL_ROOT = ${HL_ROOT}")

# Check for hl.h: prefer HL_ROOT/include, fall back to bundled copy
if(EXISTS "${HL_ROOT}/include/hl.h")
    set(HL_INCLUDE_DIR "${HL_ROOT}/include")
elseif(EXISTS "${CMAKE_SOURCE_DIR}/hl/hl.h")
    set(HL_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/hl")
    set(HL_NO_INCLUDE ON)
    message(STATUS "Using bundled hl.h from ${HL_INCLUDE_DIR}")
else()
    set(HL_NO_INCLUDE ON)
    message(WARNING "hl.h not found — .hdll build requires HL SDK headers. "
        "Install Lime 8.3.0+ (which includes HL headers) or copy hl.h to dev/native/hl/")
endif()

if(DEFINED HL_INCLUDE_DIR)
    add_library(live2d_hl SHARED
      hl/live2d_hl.cpp
    )
    target_include_directories(live2d_hl PUBLIC
      ${HL_INCLUDE_DIR}
    )
    # Link against HL runtime import library
    if(EXISTS "${HL_ROOT}/Windows64/libhl.lib")
        target_link_libraries(live2d_hl PUBLIC
          "${HL_ROOT}/Windows64/libhl.lib"
        )
    else()
        message(WARNING "libhl.lib not found at ${HL_ROOT}/Windows64/ — .hdll build will fail")
    endif()

    # .hdll is actually a DLL with custom extension
    set_target_properties(live2d_hl PROPERTIES
      OUTPUT_NAME "live2d_hl"
      SUFFIX ".hdll"
      RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../lib/win"
      LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../lib/win"
      ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../lib/win"
    )
    # Suppress LNK4098 for HL too
    target_link_options(live2d_hl PRIVATE "/NODEFAULTLIB:LIBCMT")

    # Post-build: copy libhl.dll to output
    if(EXISTS "${HL_ROOT}/Windows64/libhl.dll")
        add_custom_command(TARGET live2d_hl POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${HL_ROOT}/Windows64/libhl.dll"
            "${CMAKE_SOURCE_DIR}/../lib/win/libhl.dll"
          COMMENT "Copying libhl.dll to output directory"
        )
    endif()
elseif(NOT DEFINED HL_INCLUDE_DIR AND NOT HL_NO_INCLUDE)
    message(STATUS "HL SDK not found — skipping .hdll build target")
endif()
