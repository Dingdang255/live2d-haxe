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
│   ├── ICubismBridge.hx     # Native bridge interface
│   ├── CubismAPI.hx         # Static API facade
│   └── bridge/
│       └── HxcppWindowsBridge.hx  # hxcpp + Windows (#if cpp)
├── backend/                 # Rendering abstraction
│   ├── IL2DRenderer.hx      # Renderer interface
│   ├── L2DTextureHandle.hx  # Opaque texture handle
│   ├── L2DDisplayHandle.hx  # Opaque display handle
│   └── openfl/
│       └── OpenFLRenderer.hx  # OpenFL implementation (#if openfl)
├── flixel/                  # Flixel framework integration
│   ├── L2DFlixelComponent.hx  # FlxBasic wrapper (#if flixel)
│   └── L2DFlixelManager.hx    # Static manager with cache (#if flixel)
├── L2DCore.hx               # Core logic (platform-independent)
├── L2D.hx                   # @:deprecated typedef → CubismAPI
├── L2DModel.hx              # @:deprecated typedef → core.L2DModel
├── L2DComponent.hx          # @:deprecated typedef → L2DFlixelComponent
└── L2DManager.hx            # @:deprecated typedef → L2DFlixelManager
```

## Key Interfaces

### ICubismBridge

Abstracts the native C API access. Each platform/target provides its own implementation for loading and calling the native library.

**Methods**: 35 functions matching the C API contract — framework lifecycle, model lifecycle, update, parameters, animation, expressions, interaction, drawable data, masks, textures, model info.

**Current implementations**:
- `HxcppWindowsBridge` — Uses `GetProcAddress`/`LoadLibraryA` on Windows (#if cpp)

### IL2DRenderer

Abstracts the rendering backend. L2DCore computes "what to draw" and calls IL2DRenderer to decide "how to draw".

**Categories of methods**:
- **Texture management**: `loadTexture`, `destroyTexture`
- **Display object lifecycle**: `createContainer`, `createDisplayObject`, `resetDisplayObject`
- **Display properties**: `setVisible`, `setAlpha`, `setBlendMode`, `setColorTransform`, `resetColorTransform`, `setMask`, `clearMask`
- **Drawing**: `drawTexturedTriangles`, `drawSolidTriangles`
- **Display list**: `setChildIndex`, `getContainer`

**Current implementations**:
- `OpenFLRenderer` — Uses `Sprite.graphics.drawTriangles()` (#if openfl)

## Data Flow

```
C API (live2d_capi.dll)
    ↓ ICubismBridge
L2DCore
    ├── Reads drawable data via bridge
    ├── Transforms vertices: screen-space coords, UV flipping
    ├── Builds batches (groups consecutive drawables by state)
    ├── Pre-computes mask groups (shared mask shapes)
    └── Calls IL2DRenderer methods
        ↓
    OpenFLRenderer (or future: HeapsRenderer, etc.)
        ├── Creates/manages display objects
        ├── Draws triangles
        ├── Applies blend modes, color transforms, masks
        └── Manages display list ordering
```

## Key Design Decisions

1. **Interface-based abstraction** over conditional compilation — easier to extend, test, and maintain
2. **Opaque handles** (`L2DTextureHandle`, `L2DDisplayHandle` as `abstract Dynamic`) — type-safe at compile time, zero overhead at runtime
3. **Texture loading injection** — OpenFLRenderer accepts `textureLoader`/`textureDestroyer` functions to support both plain OpenFL and Flixel scenarios without subclassing
4. **All vertex transforms in L2DCore** — renderer receives pre-transformed screen-space data, no coordinate system knowledge needed
5. **Backward compatibility** — deprecated typedefs allow existing `L2D`, `L2DComponent`, `L2DManager` imports to keep working
