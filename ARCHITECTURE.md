# Architecture

## Overview

live2d-haxe uses a **CalcOnly** architecture: the C++ native layer handles all computation (physics, animation, poses, expressions, etc.) while the Haxe layer handles all rendering. This separation allows the core logic to be platform-independent.

## Four-Layer Architecture

```
┌─────────────────────────────────────────────────────┐
│  Framework Integration Layer                         │
│  L2DFlixelComponent / L2DHeapsObject / ...          │  Adapts to specific game framework
├─────────────────────────────────────────────────────┤
│  Core Logic Layer                                    │
│  L2DCore                                             │  Platform-independent: batch building,
│                                                      │  mask grouping, render orchestration
├─────────────────────────────────────────────────────┤
│  Backend Interface Layer                             │
│  IL2DRenderer  ·  ICubismBridge                     │  Contracts for rendering & native access
├─────────────────────────────────────────────────────┤
│  Backend Implementation Layer                        │
│  OpenFLRenderer · HxcppWindowsBridge · (future: ...)│  Platform-specific code
└─────────────────────────────────────────────────────┘
```

## Package Structure

```
live2d.cubism
├── core/                    # Platform-agnostic core
│   ├── L2DModel.hx          # Model handle type (#if cpp)
│   ├── ICubismBridge.hx     # Native bridge interface (46 methods)
│   ├── CubismAPI.hx         # Static API facade
│   └── bridge/
│       └── HxcppWindowsBridge.hx  # hxcpp + Windows (#if cpp)
├── backend/                 # Rendering abstraction
│   ├── IL2DRenderer.hx      # Renderer interface
│   ├── L2DTextureHandle.hx  # Opaque texture handle
│   ├── L2DDisplayHandle.hx  # Opaque display handle
│   └── openfl/
│       ├── OpenFLRenderer.hx      # OpenFL implementation (#if openfl)
│       └── CubismRendererShader.hx  # Unified GPU shader (#if openfl)
├── flixel/                  # Flixel framework integration
│   ├── L2DFlixelComponent.hx  # FlxBasic wrapper (#if flixel)
│   └── L2DFlixelManager.hx    # Static manager with cache (#if flixel)
├── L2DCore.hx               # Core logic (platform-independent)
├── L2DModel.hx              # typedef → core.L2DModel
└── L2DManager.hx            # typedef → flixel.L2DFlixelManager
```

## Key Interfaces

### ICubismBridge

Abstracts the native C API access. Each platform/target provides its own implementation for loading and calling the native library.

**Methods**: 46 functions matching the C API contract — framework lifecycle, model lifecycle, update, parameters, animation, expressions, interaction, drawable data, masks, textures, model info, framework behavior control (7 enabled + lip sync value), moc version checking (3).

**Current implementations**:
- `HxcppWindowsBridge` — Uses `GetProcAddress`/`LoadLibraryA` on Windows (#if cpp)

### IL2DRenderer

Abstracts the rendering backend. L2DCore computes "what to draw" and calls IL2DRenderer to decide "how to draw".

**Categories of methods**:
- **Texture management**: `loadTexture`, `destroyTexture`
- **Display object lifecycle**: `createContainer`, `createDisplayObject`, `resetDisplayObject`
- **Display properties**: `setVisible`, `setAlpha`, `setBlendMode`, `setColorTransform`, `resetColorTransform`, `setMask`, `clearMask`
- **Shader rendering**: `supportsShaderMask`, `renderMaskToBitmapData`, `drawShaderTexturedTriangles`
- **Drawing**: `drawTexturedTriangles`, `drawSolidTriangles`
- **Display list**: `setChildIndex`, `getObjectId`, `getContainer`

**Current implementations**:
- `OpenFLRenderer` — Uses `Sprite.graphics.drawTriangles()` with `CubismRendererShader` for GPU-accelerated mask/color/opacity (#if openfl)

**Two rendering paths**:
1. **Shader path** (default when `supportsShaderMask()` returns true): Uses `beginShaderFill(CubismRendererShader)` + `drawTriangles`. Mask, Multiply/Screen color, and opacity handled by fragment shader uniforms. All drawables are batchable regardless of color/opacity.
2. **Fallback path**: Uses `beginBitmapFill` + `drawTriangles` + `ColorTransform` + `Sprite.mask`. Drawables with non-default color or partial opacity cannot be batched.

## Data Flow

```
C API (live2d_capi.dll)
    ↓ ICubismBridge (1 batch metadata call + vertex data calls)
L2DCore
    ├── Reads all drawable metadata via batch API (1 FFI call)
    ├── Caches UVs/indices at construction (0 FFI at runtime)
    ├── Caches vertex positions with dirty markers (only changed drawables)
    ├── Transforms vertices: screen-space coords, UV flipping
    ├── Builds batches (groups drawables by texture+blend+mask+color+opacity)
    ├── Pre-computes mask groups (rendered to offscreen BitmapData, RGB channel packing)
    └── Calls IL2DRenderer methods
        ↓
    OpenFLRenderer (or future: HeapsRenderer, etc.)
        ├── Shader path: beginShaderFill + drawTriangles + shader uniforms
        │   ├── Mask: u_maskTex sampler + u_channelFlag
        │   ├── Color: u_mulColor / u_scrColor (blend-mode conditional)
        │   └── Opacity: u_opacity (RGBA scaling)
        ├── Fallback: beginBitmapFill + drawTriangles + ColorTransform + Sprite.mask
        └── Manages display list ordering with Sprite pooling
```

## Key Design Decisions

1. **Interface-based abstraction** over conditional compilation — easier to extend, test, and maintain
2. **Opaque handles** (`L2DTextureHandle`, `L2DDisplayHandle` as `abstract Dynamic`) — type-safe at compile time, zero overhead at runtime
3. **Texture loading injection** — OpenFLRenderer accepts `textureLoader`/`textureDestroyer` functions to support both plain OpenFL and Flixel scenarios without subclassing
4. **All vertex transforms in L2DCore** — renderer receives pre-transformed screen-space data, no coordinate system knowledge needed
5. **GPU shader-first with automatic fallback** — `CubismRendererShader` handles mask/color/opacity in fragment shader for maximum batching; falls back to Sprite.mask when shader unsupported or model has >3 mask groups
6. **Batch FFI metadata** — Single C API call returns all drawable metadata (48 bytes/drawable), reducing per-frame FFI calls from ~4000 to ~10
7. **Backward compatibility** — `L2DManager` and `L2DModel` typedefs allow existing imports to keep working; `L2DComponent` and `L2D` were removed in v0.5 as breaking changes
8. **Manual updater management** — 7 Framework behavior updaters (Breath, EyeBlink, Expression, Look, Physics, LipSync, Pose) are stored as member pointers instead of registered with `_updateScheduler`, enabling per-module enable/disable control from Haxe side
9. **Moc version checking** — `hasMocConsistency()` checks moc3 files against the current Core before loading, preventing silent crashes on incompatible models
