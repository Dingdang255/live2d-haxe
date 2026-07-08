# live2d-haxe

[中文](./README_CN.md)

Live2D Cubism SDK for Haxe - multi-backend rendering abstraction with CalcOnly architecture.

This library provides a standalone, reusable Live2D Cubism integration for Haxe projects. It uses a "CalcOnly" approach where the C++ side only handles parameter calculation (physics, motion, expressions, etc.) while the Haxe side handles all rendering through a pluggable backend interface.

**Current targets:** Windows x64 (cpp + hl) | **Architecture:** Multi-backend (OpenFL/Flixel/Heaps built-in, extensible to other frameworks)

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture docs and [BACKEND_GUIDE.md](./BACKEND_GUIDE.md) for adding new backends.

## Demo

### cpp target (Flixel/OpenFL)

<video src="https://github.com/user-attachments/assets/c98ea2d4-15c6-4584-9d7d-ad84c42fa06a" controls="controls" style="max-width: 100%;"></video>

> Demo showing model switching, hit test, expressions, motions, eye tracking, and scaling.

### hl target (HashLink/JIT)

<video src="https://github.com/user-attachments/assets/f8d0088d-1dd3-439c-93a8-d4b3d8b47742" controls="controls" style="max-width: 100%;"></video>

> HashLink JIT-accelerated demo. Faster iteration with no C++ rebuild. Compatible with Lime 8.0.1 and 8.3.0.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Extension Layer (v0.8+)                             │
│  L2DMotionQueue · L2DLookAt · L2DLipSync            │  Optional, composable utilities
│  L2DEventDispatcher · L2DModelConstants              │  Pure Haxe, depends only on L2DCore
├─────────────────────────────────────────────────────┤
│  Framework Integration                               │
│  L2DFlixelComponent / L2DHeapsObject / ...          │  Adapts to specific game framework
├─────────────────────────────────────────────────────┤
│  Core Logic                                          │
│  L2DCore (platform-independent)                      │  Batch building, mask grouping,
│                                                      │  vertex transform, render orchestration
├─────────────────────────────────────────────────────┤
│  Backend Interfaces                                  │
│  IL2DRenderer  ·  ICubismBridge                     │  Contracts for rendering & native access
├─────────────────────────────────────────────────────┤
│  Backend Implementations                             │
│  OpenFLRenderer · HeapsRenderer · HxcppWindowsBridge│  Platform-specific code
│                            · HlWindowsBridge         │
└─────────────────────────────────────────────────────┘
         ↕ ICubismBridge (GetProcAddress/dlopen/...)
    live2d_capi.dll/.so/.dylib → Live2DCubismCore
```

- **Extension Layer** (v0.8+): Optional, composable utility classes (`L2DMotionQueue`, `L2DLookAt`, `L2DLipSync`, `L2DEventDispatcher`, `L2DModelConstants`) that sit above `L2DCore` and depend only on its public API. Pure Haxe, zero native changes, work across all three backends. See [Extensions (v0.8+)](#extensions-v08) below.
- **Framework Integration Layer**: `L2DFlixelComponent` (#if flixel), `L2DHeapsObject` (#if heaps) — wraps `L2DCore` for idiomatic integration with the target game framework.
- **Core Logic Layer** (`L2DCore`): Platform-independent batch building, mask grouping, vertex transformation, and render orchestration.
- **Backend Interfaces** (`IL2DRenderer`, `ICubismBridge`): Contracts for rendering and native access, enabling multi-backend support.
- **Backend Implementations**: `OpenFLRenderer` (drawTriangles, #if openfl), `HeapsRenderer` (h2d.Drawable + h3d.prim, #if heaps), `HxcppWindowsBridge` (GetProcAddress, #if cpp), `HlWindowsBridge` (@:hlNative, #if hl). Adding a new backend only requires implementing these two interfaces.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for full details and [BACKEND_GUIDE.md](./BACKEND_GUIDE.md) for adding new backends.

## Prerequisites

- Haxe 4.2.5+
- CMake 3.16+
- Visual Studio 2019/2022 (for native C++ compilation)
- **Cubism SDK for Native 5-r.5** (NOT bundled - see below)

For **cpp target**:
- hxcpp 4.2.1+

For **hl target**:
- Lime 8.0.1+ (provides HL runtime, no extra haxelib needed)

For the Flixel/OpenFL backend (default):
- Lime 8.0.1+
- OpenFL 9.2.1+
- Flixel 4.11.0+

For the Heaps backend (optional, HL target only):
- Heaps 1.9.1+
- hlsdl 1.13.0+ (provides SDL window driver for HL)
- HashLink 1.13+ (JIT runtime, `hl` executable on PATH)

## Step 1: Download the Cubism SDK

The Cubism SDK is **NOT** included in this library. You must download it separately and agree to the Live2D license.

1. Visit: https://www.live2d.com/download/cubism-sdk/download-native/
2. Download **Cubism SDK for Native 5-r.5** (or compatible version)
3. Extract to a directory, e.g., `C:/SDK/CubismSdkForNative-5-r.5/`
4. Make sure the directory contains `Framework/src/` and `Core/` subdirectories

## Step 2: Install the Haxelib

Option A — Download the release zip:
```bash
haxelib install live2d-haxe
```

Option B — Install from GitHub repository:
```bash
haxelib git live2d-haxe https://github.com/Dingdang255/live2d-haxe.git
```

Option C — Local development (only for contributing to this library):
```bash
haxelib dev live2d-haxe /path/to/live2d-haxe
```

## Step 3: Compile the Native DLL (Windows x64)

Navigate to the library's native directory (find it via `haxelib path live2d-haxe`) and build:

```bash
cd native
mkdir build
cd build

# Configure with CMake, pointing to your Cubism SDK, specifying x64 architecture
cmake .. -DCUBISM_ROOT="C:/SDK/CubismSdkForNative-5-r.5" -A x64

# Build (Release mode recommended)
cmake --build . --config Release
```

After building, you will find:

- `live2d_capi.dll` - The C API bridge (for cpp target), located in `lib/win/Release/`
- `live2d_hl.hdll` - The HL native extension (for hl target), located in `lib/win/Release/`
- `Live2DCubismCore.dll` - The Cubism Core (auto-copied from SDK), located in `lib/win/` (not in Release subdirectory)

> **Note**: CMake auto-detects HL SDK from installed Lime versions (8.3.0 → 8.0.1, prioritized by `include/hl.h` presence). The .hdll is runtime-compatible with both Lime 8.0.1 and 8.3.0.

## Step 4: Copy DLLs to Your Project (Windows)

The DLLs must be accessible at runtime. Copy them to your project's output directory:

**For cpp target:**
```
your_project/
  export/windows/cpp/bin/
    your_app.exe
    live2d_capi.dll        <-- copy here
    Live2DCubismCore.dll   <-- copy here
```

**For hl target:**
```
your_project/
  bin/hl/bin/
    your_app.exe
    live2d_capi.dll        <-- copy here
    live2d_hl.hdll         <-- copy here
    Live2DCubismCore.dll   <-- copy here
    libhl.dll              <-- auto-copied by Lime
```

> **Note**: `libhl.dll` is automatically copied by Lime from its templates. Do not manually copy it to avoid version mismatch.

You can automate this with a post-build script (see `copy.bat` and `copy_hl.bat` in the test directory).

## Step 5: Prepare Live2D Model Assets

Place your Live2D model assets in your project's assets directory:

```
assets/
  live2d/
    Haru/
      Haru.model3.json
      Haru.moc3
      Haru.physics3.json
      Haru.pose3.json
      Haru.exp3.json
      motions/
        Idle_01.motion3.json
        ...
      Haru.2048/
        texture_00.png
```

Make sure the assets are included in your `Project.xml`:
```xml
<assets path="assets/live2d" rename="assets/live2d" />
```

## Usage (Flixel/OpenFL Backend)

### Basic: Single Model with L2DFlixelComponent

```haxe
import live2d.cubism.flixel.L2DFlixelComponent;
import openfl.display.Sprite;

class MyState extends FlxState
{
    var l2d:L2DFlixelComponent;
    
    override public function create()
    {
        super.create();
        
        // Load a Live2D model
        l2d = new L2DFlixelComponent('assets/live2d/Haru/', 'Haru.model3.json');
        
        // Position and scale
        l2d.x = FlxG.width / 2;
        l2d.y = FlxG.height / 2;
        l2d.scale = 0.3;
        
        // Add the OpenFL sprite to the display list
        FlxG.stage.addChild(l2d.getSprite());
    }
    
    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // Update model (motion, physics, etc.)
        l2d.update(elapsed);
        
        // Render after update
        l2d.render();
    }
    
    override public function destroy()
    {
        // Remove sprite from stage before destroy
        if (l2d != null && l2d.getSprite() != null)
        {
            FlxG.stage.removeChild(l2d.getSprite());
        }
        l2d.destroy();
        super.destroy();
    }
}
```

### Multiple Models with L2DFlixelManager

```haxe
import live2d.cubism.flixel.L2DFlixelComponent;
import live2d.cubism.flixel.L2DFlixelManager;

class MyState extends FlxState
{
    var bg:L2DFlixelComponent;
    var character:L2DFlixelComponent;
    
    override public function create()
    {
        super.create();
        
        // L2DFlixelManager handles framework init and texture caching
        bg = L2DFlixelManager.create('assets/live2d/Background/', 'bg.model3.json');
        character = L2DFlixelManager.create('assets/live2d/Haru/', 'Haru.model3.json');
        
        // Add sprites
        FlxG.stage.addChild(bg.getSprite());
        FlxG.stage.addChild(character.getSprite());
    }
    
    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        L2DFlixelManager.updateAll(elapsed);
        L2DFlixelManager.renderAll();
    }
    
    override public function destroy()
    {
        L2DFlixelManager.destroyAll();
        super.destroy();
    }
}
```

### Playing Motions and Expressions

```haxe
// Play a specific motion (group, index, priority)
// Priority: 0=None, 1=Idle, 2=Normal, 3=Force
var handle = l2d.startMotion('TapBody', 0, 3);

// Check if motion is finished
if (l2d.model.notNull() && CubismAPI.isMotionFinished(l2d.model, handle))
{
    trace('Motion finished!');
}

// Play a random Idle motion
l2d.startIdleMotion();

// Set an expression
l2d.setExpression('smile');

// Set a random expression
l2d.setRandomExpression();
```

### Interactive: Hit Test and Dragging

```haxe
// Check if mouse click hits a specific area
if (FlxG.mouse.justPressed)
{
    var mx = FlxG.mouse.screenX;
    var my = FlxG.mouse.screenY;
    
    if (l2d.hitTest('Body', mx, my))
    {
        l2d.startMotion('TapBody', 0, 3);
    }
}

// Follow mouse with eyes/head
if (FlxG.mouse.pressed)
{
    l2d.setDragging(FlxG.mouse.screenX, FlxG.mouse.screenY);
}
```

### Framework Behavior Control

v0.5.0 adds runtime enable/disable for all 7 Framework behavior modules, plus external lip sync value input:

```haxe
// Toggle behavior modules at runtime (all enabled by default)
l2d.core.setBreathEnabled(false);      // Disable breathing animation
l2d.core.setPhysicsEnabled(false);     // Disable physics simulation
l2d.core.setEyeBlinkEnabled(false);    // Disable auto-blinking
l2d.core.setExpressionEnabled(false);  // Disable expression updates
l2d.core.setLookEnabled(false);        // Disable look/gaze tracking
l2d.core.setLipSyncEnabled(false);     // Disable lip sync
l2d.core.setPoseEnabled(false);        // Disable pose transitions

// Read current enabled state
trace(l2d.core.breathEnabled);   // true/false

// External lip sync (microphone/audio RMS → mouth open amount)
l2d.core.setLipSyncValue(0.5);   // 0.0~1.0 mouth openness
l2d.core.setLipSyncValue(-1.0);  // <0 reverts to wav file handler mode
```

### Moc Version Checking

v0.5.0 adds moc3 version consistency checking API. Loading incompatible models now outputs detailed error messages instead of silent crashes:

```haxe
import live2d.cubism.L2DCore;

// Static methods, no model instance needed
var coreVer = L2DCore.getCoreVersion();         // Core DLL version number
var latestMoc = L2DCore.getLatestMocVersion();  // Highest supported moc version
var ok = L2DCore.hasMocConsistency("path/to/model.moc3");  // Check compatibility

// L2DCore automatically checks on load
// On incompatibility: [L2D] ERROR: moc3 file incompatible with current Core!
//   Core supports moc version ≤ X
//   Possible fix: re-export from Cubism Editor with lower target version
```

### Low-Level API (CubismAPI)

For advanced use, the `CubismAPI` class provides direct access to all C API functions:

```haxe
import live2d.cubism.core.CubismAPI;
import live2d.cubism.core.L2DModel;

// Framework lifecycle
CubismAPI.frameworkStartUp();

// Model lifecycle
var model:L2DModel = CubismAPI.loadModel('assets/live2d/Haru/', 'Haru.model3.json');
CubismAPI.update(model);
CubismAPI.releaseModel(model);

// Parameters
var paramCount = CubismAPI.getParameterCount(model);
var eyeXIndex = CubismAPI.findParameterIndex(model, 'ParamEyeBallX');
var eyeXValue = CubismAPI.getParameterValue(model, eyeXIndex);
CubismAPI.setParameterValue(model, eyeXIndex, 0.5, 1.0);

// Drawable data
var drawCount = CubismAPI.getDrawableCount(model);
var vertCount = CubismAPI.getDrawableVertexCount(model, 0);
var opacity = CubismAPI.getDrawableOpacity(model, 0);
var isVisible = CubismAPI.isDrawableVisible(model, 0);
```

### Migrating from v0.4 to v0.5

v0.5.0 removes `L2DComponent` and `L2D` deprecated typedefs as breaking changes. Update your imports:

```haxe
// v0.4 old (removed)
import live2d.cubism.L2DComponent;       // ❌ No longer exists
import live2d.cubism.L2D;                 // ❌ No longer exists

// v0.5 new
import live2d.cubism.flixel.L2DFlixelComponent;
import live2d.cubism.core.CubismAPI;

// Still available as aliases
import live2d.cubism.L2DManager;          // ✅ Alias for L2DFlixelManager
import live2d.cubism.L2DModel;            // ✅ Alias for core.L2DModel
```

## Usage (Heaps Backend)

The Heaps backend (`#if heaps`) runs on the HL target only. It uses `h2d.Object` as the scene graph node and `h3d.mat.Texture` for textures, with a unified `hxsl.Shader` for mask/color/opacity.

### hxml configuration

```hxml
-cp .
-lib heaps
-lib hlsdl
-lib live2d-haxe
-D heaps
-D live2d_haxe
-dce full
-main MyHeapsApp
-hl bin/heaps/app.hl
```

> `-dce full` is required to eliminate `hxd.snd.Mp3Data` (which has `@:hlNative("fmt","mp3_open")` and would otherwise trigger a `fmt.hdll` signature mismatch at runtime).

### Basic: Single Model with L2DHeapsObject

```haxe
import live2d.cubism.heaps.L2DHeapsObject;

class MyHeapsApp extends hxd.App
{
    var l2d:L2DHeapsObject;

    override function init()
    {
        // Load a Live2D model and attach to s2d
        l2d = new L2DHeapsObject('assets/live2d/Haru/', 'Haru.model3.json', s2d);

        // Position and scale (via core — see transform note below)
        l2d.core.x = s2d.width / 2;
        l2d.core.y = s2d.height / 2;
        l2d.core.scale = (s2d.height * 0.8) / l2d.modelHeight;

        // Play idle motion
        l2d.startIdleMotion();
    }

    override function update(dt:Float)
    {
        // No need to call l2d.core.update() or l2d.core.render() —
        // L2DHeapsObject auto-updates and renders in sync(ctx).

        // Interaction (example: eye tracking on mouse hold)
        if (hxd.Key.isDown(hxd.Key.MOUSE_LEFT))
        {
            l2d.setDragging(s2d.mouseX, s2d.mouseY);
        }
        else
        {
            l2d.setDragging(l2d.core.x, l2d.core.y);
        }
    }
}
```

### Transform Note

`L2DHeapsObject` extends `h2d.Object`, which already has `x`, `y`, `alpha` fields and a `scale(v)` method (multiplicative scaling). To avoid double-transform (L2DCore applies `core.x/y/scale` in vertex computation, and the container would inherit `h2d.Object`'s transform), the object keeps its own `x`, `y`, `scaleX`, `scaleY`, `alpha` at identity (0/0/1/1/1).

- **Position**: set `l2d.core.x`, `l2d.core.y` (screen-space coordinates)
- **Scale**: set `l2d.core.scale` — do NOT use `scaleX`/`scaleY` or `scale(v)` method
- **Opacity**: set `l2d.core.alpha` (h2d.Object's `alpha` field cannot be overridden)
- **Advanced access**: `l2d.core` is public for direct access to all `L2DCore` fields and methods

### Playing Motions and Expressions

```haxe
// Play a motion (same API as Flixel backend)
var handle = l2d.startMotion('TapBody', 0, 3);

// Play a random Idle motion
l2d.startIdleMotion();

// Set an expression
l2d.setExpression('smile');

// Set a random expression
l2d.setRandomExpression();
```

### Interactive: Hit Test and Dragging

```haxe
// Check if mouse click hits a specific area
if (hxd.Key.isPressed(hxd.Key.MOUSE_LEFT))
{
    var mx = s2d.mouseX;
    var my = s2d.mouseY;

    if (l2d.hitTest('Body', mx, my))
    {
        l2d.startMotion('TapBody', 0, 3);
    }
}

// Follow mouse with eyes/head
if (hxd.Key.isDown(hxd.Key.MOUSE_LEFT))
{
    l2d.setDragging(s2d.mouseX, s2d.mouseY);
}
```

### Framework Behavior Control

Same API as the Flixel backend — all 7 behavior modules can be toggled at runtime:

```haxe
l2d.setBreathEnabled(false);       // Disable breathing animation
l2d.setPhysicsEnabled(false);      // Disable physics simulation
l2d.setEyeBlinkEnabled(false);     // Disable auto-blinking
l2d.setExpressionEnabled(false);   // Disable expression updates
l2d.setLookEnabled(false);         // Disable look/gaze tracking
l2d.setLipSyncEnabled(false);      // Disable lip sync
l2d.setPoseEnabled(false);         // Disable pose transitions

// External lip sync (microphone/audio RMS → mouth open amount)
l2d.setLipSyncValue(0.5);          // 0.0~1.0 mouth openness
l2d.setLipSyncValue(-1.0);         // <0 reverts to wav file handler mode
```

### Running the Demo

The `test/HeapsDemo.hx` demo shows full interaction (model switching, hit test, eye tracking, scale wheel, behavior toggles). From the `test/` directory:

```bash
# Compile
haxe heaps_demo.hxml

# Copy native DLLs/HDLLs to output directory
.\copy_heaps.bat

# Run
cd bin/heaps
hl heaps_demo.hl
```

## Extensions (v0.8+)

The Extension Layer provides high-level utilities that reduce boilerplate for common Live2D interaction patterns. All extensions are **optional** — users adopt them by constructing classes with a `L2DCore` reference. No existing API is changed.

**Design principles:** zero native changes, dependency injection (receive `L2DCore`, don't inherit), interface-first for backend-specific concerns, composable, stateful `update(dt)`. See [ARCHITECTURE.md → Extension Layer (v0.8+)](./ARCHITECTURE.md#extension-layer-v08) for full design notes.

### L2DMotionQueue — Priority Queue with Idle Recovery

```haxe
import live2d.cubism.ext.L2DMotionQueue;
import live2d.cubism.ext.L2DEventDispatcher;

var dispatcher = new L2DEventDispatcher(core);
var queue = new L2DMotionQueue(core, dispatcher);
// Note: the default native Update() already auto-plays a random Idle motion
// when the motion queue is empty. Do NOT call enableIdleRecovery() unless you
// have disabled the native auto-idle — otherwise the two will race and produce
// "can't start motion" warnings.
// queue.enableIdleRecovery("Idle", 3.0);

// In update loop:
queue.update(dt);

// Triggered by user input:
queue.enqueue("TapBody", 0, 3);  // Force: interrupt current
queue.enqueue("Talk", 2, 2);     // Normal: queue after current
```

### L2DLookAt — Damped Mouse/Touch Follow

```haxe
import live2d.cubism.ext.L2DLookAt;

var lookAt = new L2DLookAt(core);
lookAt.followSpeed = 0.2;  // lerp coefficient, 0..1
lookAt.deadzone = 5;       // px, prevents micro-jitter

// In update loop:
lookAt.update(dt);

// On mouse move:
lookAt.setTarget(mouseX, mouseY);

// On mouse release:
lookAt.release();  // eases back to model center
```

### L2DLipSync — Audio-Driven Mouth Sync

```haxe
import live2d.cubism.ext.L2DLipSync;
import live2d.cubism.ext.L2DCallbackAudioSource;

var source = new L2DCallbackAudioSource(() -> computeRMS());
var lipSync = new L2DLipSync(core, source);
lipSync.attack = 0.5;    // snappier opening
lipSync.release = 0.15;  // slower closing
lipSync.curve = 1.5;     // aggressive mapping
lipSync.enable();        // disables C-side wav mode

// In update loop:
lipSync.update(dt);

// To stop:
lipSync.disable();  // reverts to wav file mode
```

### L2DEventDispatcher — Typed Event Subscription

```haxe
import live2d.cubism.ext.L2DEventDispatcher;

var dispatcher = new L2DEventDispatcher(core);
var token = dispatcher.onMotionFinished((group, no, handle) -> {
    trace('Motion finished: $group#$no');
});

// Hit test multiple areas at once (dispatches HitTest on first hit):
dispatcher.hitTestAreas(["Head", "Body"], clickX, clickY);

// Unsubscribe later:
dispatcher.off(token);
```

### L2DModelConstants — Compile-Time Constants from model3.json

```haxe
import live2d.cubism.ext.L2DModelConstants;

@:build(live2d.cubism.ext.L2DModelConstants.build('assets/live2d/Haru/Haru.model3.json'))
class HaruConstants {}

// Now you have compile-time constants:
l2d.startMotion(HaruConstants.Motions.Idle, 0, 1);    // "Idle"
l2d.hitTest(HaruConstants.HitAreas.Head, x, y);        // "Head"
l2d.setExpression(HaruConstants.Expressions.F01);      // "F01"
// HaruConstants.Motions.Idel  // compile error: prevents typo
```

### InputAdapter — Unified Input Across Backends

The `IL2DInputAdapter` interface normalizes mouse/touch events from different frameworks into unified `(x, y)` callbacks. Three built-in implementations:

| Adapter | Backend | Style | Note |
| --- | --- | --- | --- |
| `L2DOpenFLInputAdapter` | OpenFL | Event-based | Takes a `Sprite` in constructor |
| `L2DFlixelInputAdapter` | Flixel | Polling-based | Call `adapter.update()` in `FlxState.update` |
| `L2DHeapsInputAdapter` | Heaps | Event-based | Uses `hxd.Window.addEventTarget` |

```haxe
import live2d.cubism.ext.heaps.L2DHeapsInputAdapter;

var adapter = new L2DHeapsInputAdapter();
adapter.bindMove((x, y) -> lookAt.setTarget(x, y));
adapter.bindDown((x, y) -> dispatcher.hitTestAreas(["Head", "Body"], x, y));
// On cleanup:
adapter.dispose();
```

### Extension Layer API Reference

#### L2DMotionQueue

| Property/Method | Description |
| --- | --- |
| `hasActiveMotion` | Whether a motion is currently playing (read-only) |
| `pendingCount` | Number of motions waiting in queue (read-only) |
| `onMotionBegan` | Dynamic callback `(group, no, handle) -> Void` |
| `onMotionFinished` | Dynamic callback `(group, no, handle) -> Void` |
| `onQueueEmpty` | Dynamic callback `() -> Void` |
| `new(core, ?dispatcher)` | Construct with L2DCore and optional event dispatcher |
| `enqueue(group, no=0, priority=2)` | Enqueue a motion. Priority: 1=Idle, 2=Normal, 3=Force. Returns `MotionHandle` |
| `clear()` | Clear queue and forget current motion (does NOT stop C-side) |
| `enableIdleRecovery(group="Idle", delay=3.0)` | Auto-play random idle motion after delay. **Warning:** do NOT use with the default native auto-idle (enabled in `LAppModel_CalcOnly::Update`) — the two will race |
| `disableIdleRecovery()` | Disable idle recovery |
| `update(dt)` | Poll current motion completion, advance queue, trigger idle recovery |

#### L2DLookAt

| Property/Method | Description |
| --- | --- |
| `followSpeed` | Lerp coefficient (0..1), default 0.2. Frame-rate-independent |
| `deadzone` | Deadzone radius in pixels, default 5.0 |
| `homeX`, `homeY` | Return-to-center target (defaults to `core.x`/`core.y`) |
| `new(core)` | Construct with L2DCore |
| `setTarget(?x, ?y)` | Set look-at target. Pass null to release |
| `release()` | Release target — eases back to home |
| `pause()` / `resume()` | Temporarily stop/resume applying updates |
| `snapToTarget()` | Jump current directly to target (skip easing) |
| `update(dt)` | Main loop update — writes to `core.setDragging` |

#### L2DLipSync

| Property/Method | Description |
| --- | --- |
| `enabled` | Whether controller is driving `setLipSyncValue` (read-only) |
| `current` | Current smoothed mouth open amount (read-only) |
| `attack` | Opening speed coefficient (0..1), default 0.4 |
| `release` | Closing speed coefficient (0..1), default 0.2 |
| `curve` | Volume-to-mouth mapping exponent, default 1.5 |
| `maxValue` | Maximum mouth open value, default 1.0 |
| `new(core, source)` | Construct with L2DCore and `IL2DAudioSource` |
| `enable()` | Take over lip sync from C-side wav mode |
| `disable()` | Revert to wav file handler mode |
| `update(dt)` | Main loop update — writes to `core.setLipSyncValue` |

#### L2DEventDispatcher

| Property/Method | Description |
| --- | --- |
| `new(core)` | Construct with L2DCore |
| `onMotionBegan(cb)` / `onMotionFinished(cb)` | Subscribe to motion events, returns token |
| `onExpressionSet(cb)` / `onHitTest(cb)` | Subscribe to expression/hit events, returns token |
| `onIdleRecovery(cb)` / `onQueueEmpty(cb)` | Subscribe to queue events, returns token |
| `off(token)` | Cancel a subscription by token |
| `clear()` | Remove all listeners |
| `dispatch(event)` | Dispatch an `L2DEvent` (used by extensions) |
| `notifyExpressionSet(id)` | Convenience: dispatch `ExpressionSet(id)` |
| `hitTestAreas(areas, x, y)` | Hit test multiple areas, dispatch `HitTest` on first hit. Returns Bool |

#### L2DModelConstants (macro)

| Usage | Description |
| --- | --- |
| `@:build(L2DModelConstants.build('path/to/Model.model3.json'))` | Apply to an empty class to generate constants |
| `MyConstants.Motions.GroupName` | Motion group name (compile-time string) |
| `MyConstants.Expressions.Name` | Expression name |
| `MyConstants.HitAreas.Name` | Hit area name |
| `MyConstants.Groups.Name` | Parameter group name (EyeBlink, LipSync, ...) |
| `MyConstants.Textures` | Array of texture paths (runtime `Array<String>`) |

## API Reference

### L2DFlixelComponent (extends FlxBasic)

| Property/Method | Description |
| --- | --- |
| `x`, `y` | Screen position |
| `scale` | Render scale factor |
| `alpha` | Global opacity multiplier |
| `model` | Underlying `L2DModel` handle |
| `modelWidth`, `modelHeight` | Computed model bounds |
| `startMotion(group, no, priority)` | Play a motion |
| `startIdleMotion()` | Play random Idle motion |
| `setExpression(id)` | Set expression by ID |
| `setRandomExpression()` | Set random expression |
| `hitTest(areaName, px, py)` | Hit test at screen coordinates |
| `setDragging(screenX, screenY)` | Set drag/follow target |
| `getSprite()` | Get OpenFL Sprite container |
| `render()` | Redraw all visible drawables |
| `getCanvasWidth()`, `getCanvasHeight()` | Model canvas dimensions |

### L2DHeapsObject (extends h2d.Object, #if heaps)

Auto-updates and renders in `sync(ctx)` — no manual `update`/`render` calls needed.

| Property/Method | Description |
| --- | --- |
| `core` | Underlying `L2DCore` (public, for x/y/scale/alpha/advanced access) |
| `model` | Underlying `L2DModel` handle |
| `modelWidth`, `modelHeight` | Computed model bounds |
| `modelDir`, `modelFileName` | Model path info |
| `startMotion(group, no, priority)` | Play a motion |
| `startIdleMotion()` | Play random Idle motion |
| `setExpression(id)` | Set expression by ID |
| `setRandomExpression()` | Set random expression |
| `hitTest(areaName, px, py)` | Hit test at screen coordinates |
| `setDragging(screenX, screenY)` | Set drag/follow target |
| `getCanvasWidth()`, `getCanvasHeight()` | Model canvas dimensions |
| `setBreathEnabled(b)` | Toggle breathing animation |
| `setEyeBlinkEnabled(b)` | Toggle auto-blink |
| `setExpressionEnabled(b)` | Toggle expression updates |
| `setLookEnabled(b)` | Toggle look/gaze tracking |
| `setPhysicsEnabled(b)` | Toggle physics simulation |
| `setLipSyncEnabled(b)` | Toggle lip sync |
| `setPoseEnabled(b)` | Toggle pose transitions |
| `setLipSyncValue(v)` | Set external lip sync value (0~1, <0 reverts to wav mode) |

> **Transform**: Set `l2d.core.x`, `l2d.core.y` for screen position, `l2d.core.scale` for scale, and `l2d.core.alpha` for opacity. `h2d.Object`'s own `x`/`y`/`scaleX`/`scaleY`/`alpha` are kept at identity to avoid double-transform. Do NOT use `scaleX`/`scaleY` or `scale(v)` method. See [Usage (Heaps Backend) → Transform Note](#transform-note).

### L2DFlixelManager (static)

| Method | Description |
| --- | --- |
| `create(dir, fileName)` | Create model with texture caching |
| `destroy(model)` | Destroy a specific model |
| `destroyAll()` | Destroy all managed models |
| `updateAll(elapsed)` | Update all models |
| `renderAll()` | Render all models |
| `clearTextureCache()` | Free cached textures |
| `getContainer()` | Get global Sprite container |

### L2DCore (platform-independent)

| Property/Method | Description |
| --- | --- |
| `x`, `y` | Screen position |
| `scale` | Render scale factor |
| `alpha` | Global opacity multiplier |
| `model` | Underlying `L2DModel` handle |
| `modelWidth`, `modelHeight` | Computed model bounds |
| `ownsTextures` | Whether this instance owns texture lifecycle (default: true) |
| `breathEnabled` | Breathing animation enabled state |
| `eyeBlinkEnabled` | Auto-blink enabled state |
| `expressionEnabled` | Expression update enabled state |
| `lookEnabled` | Look/gaze tracking enabled state |
| `physicsEnabled` | Physics simulation enabled state |
| `lipSyncEnabled` | Lip sync enabled state |
| `poseEnabled` | Pose transition enabled state |
| `startMotion(group, no, priority)` | Play a motion |
| `startIdleMotion()` | Play random Idle motion |
| `setExpression(id)` | Set expression by ID |
| `setRandomExpression()` | Set random expression |
| `hitTest(areaName, px, py)` | Hit test at screen coordinates |
| `setDragging(screenX, screenY)` | Set drag/follow target |
| `setBreathEnabled(enabled)` | Toggle breathing animation |
| `setEyeBlinkEnabled(enabled)` | Toggle auto-blink |
| `setExpressionEnabled(enabled)` | Toggle expression updates |
| `setLookEnabled(enabled)` | Toggle look/gaze tracking |
| `setPhysicsEnabled(enabled)` | Toggle physics simulation |
| `setLipSyncEnabled(enabled)` | Toggle lip sync |
| `setPoseEnabled(enabled)` | Toggle pose transitions |
| `setLipSyncValue(value)` | Set external lip sync value (0~1, <0 reverts to wav mode) |
| `getContainer()` | Get root display handle |
| `render()` | Redraw all visible drawables |
| `update(elapsed)` | Update model with delta time |
| `destroy()` | Release model and resources |
| `getCanvasWidth()`, `getCanvasHeight()` | Model canvas dimensions |
| `getCoreVersion()` | Get Cubism Core version (static) |
| `getLatestMocVersion()` | Get highest supported moc version (static) |
| `hasMocConsistency(path)` | Check moc3 file compatibility (static) |

### CubismAPI (static facade)

| Method | Description |
| --- | --- |
| `frameworkStartUp()` | Initialize the Cubism framework |
| `frameworkCleanUp()` | Clean up the framework |
| `getBridge()` | Get the current ICubismBridge implementation |
| `setBridge(bridge)` | Set a custom ICubismBridge implementation |
| `loadModel(dir, fileName)` | Load a model from directory |
| `releaseModel(model)` | Release a model |
| `update(model)` | Update model state |
| `setBreathEnabled(model, enabled)` | Toggle breathing animation |
| `setEyeBlinkEnabled(model, enabled)` | Toggle auto-blink |
| `setExpressionEnabled(model, enabled)` | Toggle expression updates |
| `setLookEnabled(model, enabled)` | Toggle look/gaze tracking |
| `setPhysicsEnabled(model, enabled)` | Toggle physics simulation |
| `setLipSyncEnabled(model, enabled)` | Toggle lip sync |
| `setPoseEnabled(model, enabled)` | Toggle pose transitions |
| `setLipSyncValue(model, value)` | Set external lip sync value |
| `getCoreVersion()` | Get Cubism Core version |
| `getLatestMocVersion()` | Get highest supported moc version |
| `hasMocConsistency(path)` | Check moc3 file compatibility |
| ... | All 46 C API functions are available as static methods |

## Project Configuration

In your `Project.xml`:

```xml
<!-- Required -->
<haxelib name="hxcpp" />
<haxelib name="live2d-haxe" />

<!-- For Flixel/OpenFL backend -->
<haxelib name="flixel" />
<haxelib name="openfl" />
```

Make sure your project targets Windows x64.

## Native DLL Build Configuration (Windows)

The CMakeLists.txt in `native/` supports the following options:

| Variable | Default | Description |
| --- | --- | --- |
| `CUBISM_ROOT` | `../CubismSdkForNative-5-r.5` | Path to Cubism SDK |

Example with custom SDK path:

```bash
cmake .. -DCUBISM_ROOT="D:/SDK/CubismSdkForNative-5-r.5" -A x64
```

## Limitations

- **Windows x64 only** (current bridges) - `HxcppWindowsBridge` (#if cpp) uses Windows-specific `GetProcAddress`/`LoadLibraryA`. `HlWindowsBridge` (#if hl) uses `@:hlNative` bindings to a .hdll shim that internally calls `LoadLibraryA`. Linux/macOS support requires new bridge implementations using `dlopen`/`dlsym`.
- **CalcOnly rendering** - C++ side does no GPU rendering; all drawing is via the rendering backend (e.g., OpenFL's `drawTriangles` with GPU acceleration).
- **GPU Shader path** (Flixel/OpenFL backend, default) — Mask, Multiply/Screen color, and opacity handled by `CubismRendererShader` fragment shader. All drawables are batchable regardless of color/opacity. Batch key = (texture, blendMode, maskGroup, mulColor, scrColor, opacity). Automatic fallback to `Sprite.mask` when shader unsupported or model has >3 mask groups.
- **Batched rendering** (Flixel/OpenFL backend) — Drawables sharing the same state are merged into one draw call. Typical models: ~18 batches from ~130 individual draw call. Sprite pooling (32 batch + 16 mask) avoids per-frame allocation.
- **Mask groups** (Flixel/OpenFL backend) — Up to 3 mask groups supported in GPU shader path (RGB channel packing). Models with >3 groups fall back to `Sprite.mask`.
- **Heaps backend — HL target only** — The Heaps backend (`#if heaps`) runs only on HashLink/HL. It does not support the cpp target (no `HxcppWindowsBridge` integration for Heaps). Use the Flixel/OpenFL backend for cpp deployments.
- **Heaps backend — Shader path only** — `HeapsRenderer` always uses `CubismHeapsShader` (hxsl, priority=200) for mask/color/opacity. There is no fallback path; if the shader fails to compile the model will not render. Mask is implemented via a render-target texture (`CubismMaskShader` fills solid color, sampled by `CubismHeapsShader`).
- **Heaps backend — Non-premultiplied alpha** — Heaps' `BlendMode.Alpha` is `SrcAlpha * Src + (1 - SrcAlpha) * Dst` (non-premultiplied), unlike OpenFL's premultiplied alpha. `CubismHeapsShader` applies opacity as `pixelColor.a *= u_opacity` (alpha-only scaling, NOT RGB) to avoid white highlighting during fade-out animations.
- **Heaps backend — `-dce full` required** — Required to eliminate `hxd.snd.Mp3Data` (which has `@:hlNative("fmt","mp3_open")` and would otherwise trigger a `fmt.hdll` signature mismatch at runtime).
- **Heaps backend — Transform via `core`** — `L2DHeapsObject` keeps `h2d.Object`'s own `x`/`y`/`scaleX`/`scaleY`/`alpha` at identity to avoid double-transform. Position, scale, and opacity must be set via `l2d.core.x`, `l2d.core.y`, `l2d.core.scale`, and `l2d.core.alpha`. Do NOT use `scaleX`/`scaleY` or `scale(v)` method.

## License

This library's code is released under the **MIT License**.

The **Live2D Cubism SDK** itself is subject to Live2D's own license terms. You must download and agree to their license separately at:
https://www.live2d.com/download/cubism-sdk/download-native/

## Acknowledgments

- Based on the Live2D Cubism SDK for Native by Live2D Inc.
- Demo video uses Live2D sample models (Haru, Hiyori, Mao, Mark, Natori, Rice). These characters are copyrighted by Live2D Inc. and used in accordance with the [Live2D Free Material License Agreement](https://www.live2d.com/eula/live2d-free-material-license-agreement_en.html) and [Sample Data Terms of Use](https://www.live2d.com/learn/sample/model-terms/).

> 本作品のキャラクターには株式会社Live2Dの著作物であるサンプルデータが株式会社Live2Dの定める規約に従って用いられています。本作品は制作者の完全な自己の裁量で制作されています。
