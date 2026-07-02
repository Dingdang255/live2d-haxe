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
target_link_options(live2d_capi PRIVATE "/DEF:\"${CMAKE_SOURCE_DIR}/live2d/live2d_capi.def\"")
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
