# live2d-haxe

[中文](./README_CN.md)

Live2D Cubism SDK integration for Haxe/Flixel - CalcOnly rendering via OpenFL drawTriangles.

This library provides a standalone, reusable Live2D Cubism integration for Haxe/Flixel projects. It uses a "CalcOnly" approach where the C++ side only handles parameter calculation (physics, motion, expressions, etc.) while the Haxe side handles all rendering via OpenFL's `Sprite.graphics.drawTriangles()`.

**Target:** Windows x64 only (cpp target)

## Demo

<div align="center">
    <h1>
        <video src="./docs/test.mp4" controls width="600"></video>
    </h1>
</div>


> Demo showing model switching, hit test, expressions, motions, eye tracking, and scaling.

## Architecture

```
+-------------------+     GetProcAddress      +------------------+
|   Haxe/Flixel     | <=====================> |  live2d_capi.dll |
|   (Rendering)     |    function pointers    |  (Calculation)   |
+-------------------+                         +------------------+
                                                       |
                                                       | links
                                                       v
                                              +------------------+
                                              | Live2DCubismCore |
                                              |    .dll + SDK    |
                                              +------------------+
```

- **C++ Native Layer** (`live2d_capi.dll`): Flat C API wrapping the Cubism SDK. Only performs parameter/motion calculation, no OpenGL/DirectX rendering.
- **Haxe Layer** (`live2d.cubism`): Reads drawable data (vertices, UVs, indices, opacity) from C++ and renders via OpenFL's `drawTriangles()`.
- **GetProcAddress**: Function pointers are loaded at runtime via `GetProcAddress`, bypassing hxcpp FFI (which causes crashes).

## Prerequisites

- Haxe 4.2.5+
- hxcpp 4.2.1+
- Lime 8.0.1+
- OpenFL 9.2.1+
- Flixel 4.11.0+
- CMake 3.16+
- Visual Studio 2019/2022 (for native C++ compilation)
- **Cubism SDK for Native 5-r.5** (NOT bundled - see below)

## Step 1: Download the Cubism SDK

The Cubism SDK is **NOT** included in this library. You must download it separately and agree to the Live2D license.

1. Visit: https://www.live2d.com/download/cubism-sdk/download-native/
2. Download **Cubism SDK for Native 5-r.5** (or compatible version)
3. Extract to a directory, e.g., `C:/SDK/CubismSdkForNative-5-r.5/`
4. Make sure the directory contains `Framework/src/` and `Core/` subdirectories

## Step 2: Compile the Native DLL

```bash
cd native
mkdir build && cd build

# Configure with CMake, pointing to your Cubism SDK
cmake .. -DCUBISM_ROOT="C:/SDK/CubismSdkForNative-5-r.5"

# Build (Release mode recommended)
cmake --build . --config Release
```

After building, you will find in `lib/win/`:

- `live2d_capi.dll` - The C API bridge
- `Live2DCubismCore.dll` - The Cubism Core (auto-copied from SDK)

## Step 3: Install the Haxelib

```bash
# Development mode (recommended during development)
haxelib dev live2d-haxe /path/to/live2d-haxe

# Or install from zip
haxelib install live2d-haxe
```

## Step 4: Copy DLLs to Your Project

The DLLs must be accessible at runtime. Copy them to your project's output directory:

```
your_project/
  export/windows/cpp/bin/
    your_app.exe
    live2d_capi.dll        <-- copy here
    Live2DCubismCore.dll   <-- copy here
```

You can automate this with a Lime `<assets>` tag or a post-build script.

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
<assets path="assets/live2d" rename="live2d" />
```

## Usage

### Basic: Single Model with L2DComponent

```haxe
import live2d.cubism.L2DComponent;
import openfl.display.Sprite;

class MyState extends FlxState
{
    var l2d:L2DComponent;
    
    override public function create()
    {
        super.create();
        
        // Load a Live2D model
        l2d = new L2DComponent('assets/live2d/Haru/', 'Haru.model3.json');
        
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

### Multiple Models with L2DManager

```haxe
import live2d.cubism.L2DManager;

class MyState extends FlxState
{
    var bg:L2DComponent;
    var character:L2DComponent;
    
    override public function create()
    {
        super.create();
        
        // L2DManager handles framework init and texture caching
        bg = L2DManager.create('assets/live2d/Background/', 'bg.model3.json');
        character = L2DManager.create('assets/live2d/Haru/', 'Haru.model3.json');
        
        // Add sprites
        FlxG.stage.addChild(bg.getSprite());
        FlxG.stage.addChild(character.getSprite());
    }
    
    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        L2DManager.updateAll(elapsed);
        L2DManager.renderAll();
    }
    
    override public function destroy()
    {
        L2DManager.destroyAll();
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
if (l2d.model.notNull() && L2D.isMotionFinished(l2d.model, handle))
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

### Low-Level API (L2D class)

For advanced use, the `L2D` class provides direct access to all C API functions:

```haxe
import live2d.cubism.L2D;
import live2d.cubism.L2DModel;

// Framework lifecycle
L2D.frameworkStartUp();

// Model lifecycle
var model:L2DModel = L2D.loadModel('assets/live2d/Haru/', 'Haru.model3.json');
L2D.update(model);
L2D.releaseModel(model);

// Parameters
var paramCount = L2D.getParameterCount(model);
var eyeXIndex = L2D.findParameterIndex(model, 'ParamEyeBallX');
var eyeXValue = L2D.getParameterValue(model, eyeXIndex);
L2D.setParameterValue(model, eyeXIndex, 0.5, 1.0);

// Drawable data
var drawCount = L2D.getDrawableCount(model);
var vertCount = L2D.getDrawableVertexCount(model, 0);
var opacity = L2D.getDrawableOpacity(model, 0);
var isVisible = L2D.isDrawableVisible(model, 0);
```

## API Reference

### L2DComponent (extends FlxBasic)

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

### L2DManager (static)

| Method | Description |
| --- | --- |
| `create(dir, fileName)` | Create model with texture caching |
| `destroy(model)` | Destroy a specific model |
| `destroyAll()` | Destroy all managed models |
| `updateAll(elapsed)` | Update all models |
| `renderAll()` | Render all models |
| `clearTextureCache()` | Free cached textures |
| `getContainer()` | Get global Sprite container |

## Project Configuration

In your `Project.xml`:

```xml
<!-- Required libraries -->
<haxelib name="flixel" />
<haxelib name="openfl" />
<haxelib name="live2d-haxe" />

<!-- Must target cpp -->
<haxedef name="cpp" />
```

## Build Configuration for the Native DLL

The CMakeLists.txt in `native/` supports the following options:

| Variable | Default | Description |
| --- | --- | --- |
| `CUBISM_ROOT` | `../CubismSdkForNative-5-r.5` | Path to Cubism SDK |

Example with custom SDK path:

```bash
cmake .. -DCUBISM_ROOT="D:/SDK/CubismSdkForNative-5-r.5"
```

## Limitations

- **Windows x64 only** - Uses Windows-specific `GetProcAddress` and `LoadLibraryA`
- **No macOS/Linux support** - The `@:cppFileCode` block uses `<windows.h>`
- **CalcOnly rendering** - C++ side does no GPU rendering; all drawing is via OpenFL's CPU/software triangle rasterization
- **No shader effects** - Cubism's multiply/screen color blending is not implemented
- **Mask performance** - Per-drawable Sprite masking may be slow with many masked drawables

## License

This library's code is released under the **MIT License**.

The **Live2D Cubism SDK** itself is subject to Live2D's own license terms. You must download and agree to their license separately at:
https://www.live2d.com/download/cubism-sdk/download-native/

## Acknowledgments

- Based on the Live2D Cubism SDK for Native by Live2D Inc.
