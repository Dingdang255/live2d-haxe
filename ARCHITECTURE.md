# Architecture

## Overview

live2d-haxe uses a **CalcOnly** architecture: the C++ native layer handles all computation (physics, animation, poses, expressions, etc.) while the Haxe layer handles all rendering. This separation allows the core logic to be platform-independent.

## Five-Layer Architecture

```
┌─────────────────────────────────────────────────────┐
│  Extension Layer (v0.8+, v1.0 expanded)              │
│  L2DMotionQueue · L2DLookAt · L2DLipSync            │  Optional, composable utilities
│  L2DEventDispatcher · L2DModelConstants              │  Pure Haxe, depends only on L2DCore
│  L2DAudioSourceBase + 3 backend AudioSources         │  v1.0: LipSync backend specialization
│  L2DHeapsObject: hot-reload · filter chain           │  v1.0: Heaps DX combo
├─────────────────────────────────────────────────────┤
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
│  OpenFLRenderer · HeapsRenderer · HxcppWindowsBridge │  Platform-specific code
│                      · HlWindowsBridge               │
└─────────────────────────────────────────────────────┘
```

## Package Structure

```
live2d.cubism
├── ext/                     # Extension Layer (v0.8+) — cross-backend utilities
│   ├── L2DEvent.hx          # Event enum (6 variants)
│   ├── L2DEventDispatcher.hx  # Typed callback dispatcher with token unsubscribe
│   ├── L2DMotionQueue.hx    # Motion priority queue + idle recovery
│   ├── L2DLookAt.hx         # Damped mouse → head/eye follow
│   ├── L2DLipSync.hx        # Audio-driven lip sync with attack/release
│   ├── IL2DAudioSource.hx   # Audio amplitude interface
│   ├── L2DCallbackAudioSource.hx  # Callback-based IL2DAudioSource
│   ├── L2DModelConstants.hx # @:build macro: model3.json → compile-time constants
│   ├── IL2DInputAdapter.hx  # Input adapter interface
│   ├── openfl/
│   │   └── L2DOpenFLInputAdapter.hx  # MouseEvent adapter (#if openfl)
│   ├── flixel/
│   │   └── L2DFlixelInputAdapter.hx  # FlxG.mouse polling adapter (#if flixel)
│   └── heaps/
│       └── L2DHeapsInputAdapter.hx   # hxd.Stage event adapter (#if heaps)
├── core/                    # Platform-agnostic core
│   ├── L2DModel.hx          # Model handle type (#if cpp)
│   ├── ICubismBridge.hx     # Native bridge interface (46 methods)
│   ├── CubismAPI.hx         # Static API facade
│   └── bridge/
│       ├── HxcppWindowsBridge.hx  # hxcpp + Windows (#if cpp)
│       └── HlWindowsBridge.hx     # HashLink + Windows (#if hl)
├── backend/                 # Rendering abstraction
│   ├── IL2DRenderer.hx      # Renderer interface
│   ├── L2DTextureHandle.hx  # Opaque texture handle
│   ├── L2DDisplayHandle.hx  # Opaque display handle
│   ├── openfl/
│   │   ├── OpenFLRenderer.hx      # OpenFL implementation (#if openfl)
│   │   └── CubismRendererShader.hx  # Unified GPU shader (#if openfl)
│   └── heaps/
│       ├── HeapsRenderer.hx       # Heaps implementation (#if heaps)
│       ├── L2DMeshDrawable.hx     # h2d.Drawable mesh wrapper (#if heaps)
│       ├── CubismHeapsShader.hx   # Mask + color + opacity shader (#if heaps)
│       └── CubismMaskShader.hx    # Solid-color fill shader for mask RT (#if heaps)
├── flixel/                  # Flixel framework integration
│   ├── L2DFlixelComponent.hx  # FlxBasic wrapper (#if flixel)
│   └── L2DFlixelManager.hx    # Static manager with cache (#if flixel)
├── heaps/                   # Heaps framework integration
│   └── L2DHeapsObject.hx      # h2d.Object wrapper (#if heaps)
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
- `HlWindowsBridge` — Uses `@:hlNative` bindings to .hdll shim on Windows (#if hl)

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
- `HeapsRenderer` — Uses `h2d.Drawable` + `h3d.prim.Primitive` with `CubismHeapsShader` (hxsl) for GPU-accelerated mask/color/opacity (#if heaps, HL target only)

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
    OpenFLRenderer (or HeapsRenderer, etc.)
        ├── Shader path: beginShaderFill + drawTriangles + shader uniforms
        │   ├── Mask: u_maskTex sampler + u_channelFlag
        │   ├── Color: u_mulColor / u_scrColor (blend-mode conditional)
        │   └── Opacity: u_opacity (RGBA scaling for premul alpha / alpha-only for non-premul)
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
10. **Dual-target native bridge** — cpp target uses inline `untyped __cpp__()` with `@:cppFileCode` for DLL loading; HL target uses `.hdll` native extension with `@:hlNative` bindings, keeping the same ICubismBridge interface contract. Both delegate to the same `live2d_capi.dll` at runtime
11. **Heaps backend (v0.7.0)** — `HeapsRenderer` implements `IL2DRenderer` on HL target using `h2d.Drawable` + `h3d.prim.Primitive` (8-float RawFormat vertices: x, y, u, v, r, g, b, a). `CubismHeapsShader` (hxsl, priority=200) runs before `Base2d.fragment()` (priority=100) to modify `pixelColor` for mask/color/opacity. `L2DHeapsObject` extends `h2d.Object` and auto-updates+renders in `sync(ctx)` via `hxd.Timer.dt`. Mask RT uses `RenderContext.pushTarget`/`popTarget` with a dedicated `CubismMaskShader` (solid-color fill, RGB channel packing per mask group). **Blend mode difference**: Heaps `BlendMode.Alpha` is non-premultiplied (`SrcAlpha, OneMinusSrcAlpha`) while OpenFL uses premultiplied (`One, OneMinusSrcAlpha`) — opacity is applied as alpha-only scaling in Heaps (`pixelColor.a *= u_opacity`) vs RGBA scaling in OpenFL (`gl_FragColor *= u_opacity`).
12. **Extension Layer (v0.8.0)** — Optional, composable utility classes (`L2DMotionQueue`, `L2DLookAt`, `L2DLipSync`, `L2DEventDispatcher`, `L2DModelConstants`) sit above `L2DCore` and depend only on its public API. All extensions are pure Haxe, zero native changes, and work across all three backends. Backend-specific concerns (audio amplitude, input events) are abstracted behind `IL2DAudioSource` and `IL2DInputAdapter` interfaces, following the same interface-first pattern as `IL2DRenderer`/`ICubismBridge`. Extensions use dependency injection (receive `L2DCore` in constructor) rather than inheritance, preserving existing wrapper APIs.

## Extension Layer (v0.8+)

The Extension Layer provides high-level utilities that reduce boilerplate for common Live2D interaction patterns. All extensions are **optional** — users adopt them by constructing classes with a `L2DCore` reference. No existing API is changed.

### Design Principles

1. **Zero native changes** — Extensions use only existing C API (`startMotion`, `isMotionFinished`, `setDragging`, `setLipSyncValue`, `hitTest`)
2. **Dependency injection** — Extensions receive `L2DCore` in constructor, don't inherit it
3. **Interface-first** — Backend-specific concerns abstracted behind `IL2DAudioSource` / `IL2DInputAdapter`
4. **Composable** — Each extension is independent; users mix-and-match as needed
5. **Stateful `update(dt)`** — Extensions manage their own state, user calls `update(dt)` in main loop

### Extensions

| Extension | Purpose | Native Dependency |
|-----------|---------|-------------------|
| `L2DMotionQueue` | Priority queue + idle recovery + completion callbacks | `startMotion`, `isMotionFinished`, `startIdleMotion` |
| `L2DLookAt` | Damped mouse → head/eye follow with deadzone + auto-return | `setDragging` |
| `L2DLipSync` | Audio → mouth sync with attack/release smoothing | `setLipSyncValue`, `setLipSyncEnabled` |
| `L2DEventDispatcher` | Typed event subscription with token unsubscribe | `hitTest` (for `hitTestAreas`) |
| `L2DModelConstants` | `@:build` macro: model3.json → compile-time constants | None (pure macro) |

### Abstraction Interfaces

- **`IL2DAudioSource`** — `getAmplitude():Float`. Default impl: `L2DCallbackAudioSource` (wraps `() -> Float`). v1.0 adds `L2DAudioSourceBase` (composes `L2DWavFileAudioSource`) + three backend subclasses: `L2DHeapsAudioSource` (`hxd.snd.Channel.position`), `L2DOpenFLAudioSource` (`SoundChannel.position`), `L2DFlixelAudioSource` (`FlxSound.time`). See [AudioSource Pattern (v1.0)](#audio-source-pattern-v10) below.
- **`IL2DInputAdapter`** — `bindMove/bindDown/bindUp(callback)`, `dispose()`. Three implementations: `L2DOpenFLInputAdapter` (event-based), `L2DFlixelInputAdapter` (polling-based, requires `adapter.update()`), `L2DHeapsInputAdapter` (event-based).

### Usage Example

```haxe
var dispatcher = new L2DEventDispatcher(core);
var motionQueue = new L2DMotionQueue(core, dispatcher);
motionQueue.enableIdleRecovery("Idle", 3.0);
var lookAt = new L2DLookAt(core);

dispatcher.onMotionFinished((group, no, handle) -> trace('Done: $group#$no'));

// In update loop:
motionQueue.update(dt);
lookAt.update(dt);

// On input:
lookAt.setTarget(mouseX, mouseY);
motionQueue.enqueue("TapBody", 0, 3);  // Force priority
dispatcher.hitTestAreas(["Head", "Body"], clickX, clickY);
```

## Heaps Rendering Invariants (v1.0)

Three internal invariants the Heaps backend relies on as of v1.0. These are not public APIs but document why the code is structured the way it is — future refactors must preserve them.

### sync Ordering Invariant (D1)

`L2DHeapsObject.sync(ctx)` must run `core.update(dt)` + `core.render()` **before** `super.sync(ctx)`.

**Why:** h2d's `sync` pass is top-down — a parent's `sync` runs before its children's. `L2DMeshDrawable` (a child of `L2DHeapsObject`) reads vertex counts during its own `sync` to decide whether to reallocate its GPU buffer. If `core.update` runs *after* `super.sync`, the drawable sees the *previous* frame's counts during sync, then `core.render` produces new vertices, and `draw` is forced to upload a second time to catch up. Reordering so `core.update+render` runs first means the drawable sees current-frame vertices during sync, and `draw` uploads exactly once.

### Mask RT Cache Pool (D3)

`L2DHeapsMaskRTCache` uses a **POOL** strategy, not a refcounted single RT.

**Why not refcount:** Two concurrent models sharing one mask RT would corrupt each other's data. h2d sync is top-down across the whole scene graph: model A's sync writes its masks into the RT, then model B's sync overwrites the same RT with B's masks, then model A's draw samples the RT — now reading B's masks. The POOL gives each concurrent model its own RT instance; when a model is destroyed its RT returns to the pool (keyed by `"WxH"`) for a future model to reuse, avoiding both corruption and per-model allocation churn.

### GPU Buffer Reuse (D2)

`L2DMeshDrawable` holds a grow-only `h3d.Buffer` (`BufferFlag.Dynamic` + `BufferFlag.RawFormat`).

**Why:** A typical 130-drawable model would otherwise allocate ~130 GPU buffers every frame. The buffer is reused across frames and reallocated only when capacity is insufficient. `uploadVector` uploads in place; `render` passes an explicit `drawTri` count to limit drawing to the active index range, so the buffer's allocated capacity and the active vertex count are decoupled.

### Mask Group Buffer Isolation (D4)

All mask groups in `renderMaskToBitmapData` share one reusable `maskDrawable` and its `MeshPrimitive`. **Each group must use an independent GPU vertex buffer** — call `maskDrawable.primitive.invalidateBuffer()` after each group's draw to force a fresh buffer allocation on the next `updateMesh` → `flush`.

**Why:** Without isolation, OpenGL's asynchronous pipeline creates a data race. Group 0 draws with its vertices, then group 1's `updateMesh` → `uploadVector` calls `glBufferSubData` on the *same* GPU buffer. If the GPU hasn't finished group 0's `glDrawElements`, it reads group 1's vertices for group 0's geometry. In practice this manifests as mask shapes rendering at wrong positions (e.g., left-eye green pixels at right-eye X coordinates on the mask RT, causing the right eye to sample an empty mask channel and disappear).

`invalidateBuffer()` disposes the current GPU buffer object and clears the reference, so the next `flush()` allocates a brand-new buffer — guaranteeing that in-flight draws on the old buffer complete before any new data is written. Called at the end of `drawSolidTriangles` too to prevent cross-call races between the fallback path and `renderMaskToBitmapData`.

## Audio Source Pattern (v1.0)

`L2DAudioSourceBase` implements `IL2DAudioSource` by composing `L2DWavFileAudioSource` (pure-Haxe WAV decode + sliding-window RMS). Backend subclasses (`L2DHeapsAudioSource`, `L2DOpenFLAudioSource`, `L2DFlixelAudioSource`) only set `wav.positionProvider` in their constructor — a `() -> Float` closure that returns the backend's live playback position (in seconds). This lets the RMS window track actual audio playback instead of a self-advancing playhead that can drift.

**Two-step update rule:** `L2DLipSync.update(dt)` only calls `source.getAmplitude()` — it never calls `source.update(dt)`. The caller must run `source.update(dt)` (which advances the RMS window via `positionProvider`) *before* `lipSync.update(dt)` each frame:

```haxe
source.update(dt);    // advance RMS window to match live playback position
lipSync.update(dt);   // read amplitude → write mouth param via setLipSyncValue
```

This separation keeps `L2DLipSync` backend-agnostic (it only needs `getAmplitude()`) while letting backend subclasses own their playback lifecycle (`play`/`stop`/`pause`/`resume`/`volume`).
