# Backend Development Guide

This guide explains how to add a new rendering or native bridge backend to live2d-haxe.

## Overview

Adding a new backend requires implementing two interfaces:

1. **ICubismBridge** — if your target uses a different native library loading mechanism
2. **IL2DRenderer** — if your target uses a different rendering framework

Then create a framework integration class that wraps `L2DCore` into your game framework's lifecycle.

## Step 1: Implement ICubismBridge (if needed)

Only needed if your target doesn't use hxcpp on Windows. Create a class in `live2d.cubism.core.bridge`:

```haxe
package live2d.cubism.core.bridge;

#if your_target_flag

import haxe.io.Bytes;
import live2d.cubism.core.ICubismBridge;
import live2d.cubism.core.L2DModel;

class HxcppLinuxBridge implements ICubismBridge
{
    public function new() {}

    public function frameworkStartUp():Void
    {
        // Load live2d_capi.so via dlopen/dlsym
        // ...
    }

    // Implement all methods...
}

#end
```

Register it in `CubismAPI.getBridge()`:

```haxe
#if your_target_flag
_bridge = new HxcppLinuxBridge();
#end
```

### Key considerations for bridge implementations:

- **DLL loading**: Use the platform's dynamic library API (`dlopen` on Linux/macOS, `LoadLibrary` on Windows)
- **Function pointers**: Cache all function pointers at load time for performance
- **String conversion**: Haxe `String.utf8_str()` provides UTF-8 C strings on hxcpp
- **Bytes output**: Use `out->b.mPtr->GetBase()` to get raw pointer from `haxe.io.Bytes`
- **Model handles**: `L2DModel` is `abstract L2DModel(cpp.Int64)`, cast via `cast(value, cpp.Int64)`
- **Batch metadata**: `getDrawableBatchMetadata()` returns a `Bytes` buffer with 48 bytes per drawable

## Step 2: Implement IL2DRenderer

Create a class in `live2d.cubism.backend.yourframework`:

```haxe
package live2d.cubism.backend.yourframework;

#if your_framework_flag

import live2d.cubism.backend.IL2DRenderer;
import live2d.cubism.backend.L2DDisplayHandle;
import live2d.cubism.backend.L2DTextureHandle;

class YourRenderer implements IL2DRenderer
{
    public function new() {}

    // Implement all methods...
}

#end
```

### Method-by-method guide:

#### Texture Management

**`loadTexture(path:String):L2DTextureHandle`**
- Load an image file from the given path
- Return an opaque handle (your framework's texture type wrapped as `L2DTextureHandle`)
- Example: `return h2d.Tile.fromBitmap(hxd.Res.load(path).toBitmap());`

**`destroyTexture(tex:L2DTextureHandle):Void`**
- Free the texture resource
- Cast `tex` back to your texture type: `var t:MyTexture = cast tex;`

#### Display Object Management

**`createContainer():L2DDisplayHandle`**
- Create the root container that holds all child display objects
- This is what gets added to the game framework's scene/stage
- Called once per L2DCore instance

**`destroyContainer():Void`**
- Remove the container and all its children from the scene

**`createDisplayObject():L2DDisplayHandle`**
- Create a reusable display object (equivalent to OpenFL Sprite)
- Add it to the container
- Initially hidden (`visible = false`)

**`resetDisplayObject(obj:L2DDisplayHandle):Void`**
- Clear all drawn graphics
- Reset: `visible = false`, `alpha = 1.0`, `blendMode = Normal`, `colorTransform = identity`, `mask = null`
- Called every frame before re-rendering

#### Display Properties

**`setBlendMode(obj, blendValue:Int)`**
- `blendValue` is the Live2D raw value:
  - `0` = Normal
  - `1` = AddCompatible
  - `2` = MultiplyCompatible
  - `3` = Add
  - `6` = Multiply
  - `10` = Screen
- Map to your framework's blend mode

**`setColorTransform(obj, mulR, mulG, mulB, mulA, addR, addG, addB, addA)`**
- Multipliers are in [0,1] range, offsets are in [0,255] range
- Final color = `original * multiplier + offset / 255`
- Only used in fallback path (non-shader)
- For Live2D: `multiplier = multiplyColor * (1 - screenColor)`, `offset = screenColor * 255`

**`setMask(obj, mask)` / `clearMask(obj)`**
- Apply/remove a mask display object
- Only used in fallback path (non-shader)
- If your framework supports alpha-based masking, use the mask as-is
- If your framework uses stencil buffers, render the mask with stencil write and target with stencil test

#### Shader Rendering (GPU path)

**`supportsShaderMask():Bool`**
- Return `true` if your renderer supports GPU shader-based mask/color/opacity
- When `true`, L2DCore uses the shader path for maximum batch merging
- When `false`, falls back to Sprite.mask + ColorTransform path

**`renderMaskToBitmapData(maskShapes, width, height, offsetX, offsetY):L2DTextureHandle`**
- Render mask shapes to an off-screen texture for GPU shader sampling
- `maskShapes` is an array of `{groupIndex, channelFlag, vertices, indices}`
  - `groupIndex` (0-2): which mask group
  - `channelFlag` (Array\<Float\>, 4 elements): RGB channel selector — `[1,0,0,0]` for red, `[0,1,0,0]` for green, `[0,0,1,0]` for blue
  - `vertices`: Array of vertex arrays (each drawable's vertex positions)
  - `indices`: Array of index arrays (each drawable's triangle indices)
- Up to 3 mask groups packed into RGB channels of a single texture
- Return an opaque texture handle for the rendered mask texture
- `width`/`height` are typically 1/4 of the canvas size
- `offsetX`/`offsetY` translate vertex positions into the mask texture's coordinate space

**`drawShaderTexturedTriangles(obj, texture, vertices, uvs, indices, ?maskTexture, ?channelFlag, ?maskOffset, ?maskScale, ?isInverted, ?mulColor, ?scrColor, ?opacity):Void`**
- Core rendering call for the GPU shader path
- All data is pre-transformed (screen-space coords, UV flipped)
- Optional parameters for shader features:
  - `maskTexture`: Off-screen mask texture from `renderMaskToBitmapData`
  - `channelFlag`: RGB channel selector `[1,0,0,0]`, `[0,1,0,0]`, or `[0,0,1,0]`
  - `maskOffset`/`maskScale`: Transform mask UVs from screen-space to mask texture coords
  - `isInverted`: Whether mask is inverted
  - `mulColor`: Multiply color `[R, G, B]` (applied for Multiply blend mode)
  - `scrColor`: Screen color `[R, G, B]` (applied for Screen blend mode)
  - `opacity`: Per-drawable opacity (0..1), applied as RGBA scaling

**`getObjectId(obj:L2DDisplayHandle):Int`**
- Return a unique integer ID for a display object
- Used for dirty tracking (skip redundant resets)

#### Drawing (fallback path)

**`drawTexturedTriangles(obj, texture, vertices, uvs, indices)`**
- Fallback path rendering call (no shader)
- All data is pre-transformed:
  - `vertices`: screen-space x,y pairs (already scaled, translated, Y-flipped)
  - `uvs`: texture coordinates (V already flipped: `1.0 - originalV`)
  - `indices`: triangle indices (already adjusted for batch merging)

**`drawSolidTriangles(obj, vertices, indices)`**
- Draw white-filled triangles (used for mask shapes in fallback path)
- No texture or UV data needed

#### Display List

**`setChildIndex(child, index)`**
- Set the z-order of a child within the container
- Lower index = rendered first (behind)
- Called every frame to ensure correct render order

**`getContainer():L2DDisplayHandle`**
- Return the root container created in `createContainer()`

## Step 3: Create Framework Integration

Create a wrapper class that adapts L2DCore to your game framework's lifecycle:

```haxe
package live2d.cubism.yourframework;

#if your_framework_flag

class L2DYourFrameworkObject extends YourFrameworkBaseClass
{
    public var core:L2DCore;

    public function new(dir:String, fileName:String)
    {
        super();
        var bridge = CubismAPI.getBridge();
        var renderer = new YourRenderer();
        core = new L2DCore(dir, fileName, bridge, renderer);
    }

    // Lifecycle hooks
    public function updateLogic(dt:Float) { core.update(dt); }
    public function renderModel() { core.render(); }

    // Delegate convenience API
    public function startMotion(g, n, p) return core.startMotion(g, n, p);
    // ...
}

#end
```

## Reference Implementation

The `OpenFLRenderer` in `live2d.cubism.backend.openfl` is the reference implementation. Key aspects:

- **GPU Shader path**: `CubismRendererShader` (extends `GraphicsShader`) handles mask sampling, Multiply/Screen color blending, and per-drawable opacity via fragment shader uniforms. Uses `@:glFragmentBody` for custom GLSL injection.
- **Texture injection**: Constructor accepts `textureLoader`, `textureDestroyer`, and `textureToBitmapData` functions, allowing the same renderer to work with both plain `BitmapData` and Flixel's `FlxGraphic`
- **Array to Vector conversion**: `Vector.ofArray()` converts Haxe `Array<Float>` to OpenFL `Vector<Float>` for `drawTriangles()`
- **Blend mode mapping**: Simple switch statement mapping Live2D values to `openfl.display.BlendMode` enum
- **Automatic fallback**: `supportsShaderMask()` returns `true`; users can set `useShaderMask = false` to force fallback to `Sprite.mask` + `ColorTransform`

## Performance Notes

- L2DCore pre-allocates display object pools (32 batch + 16 mask objects)
- `resetDisplayObject` is called only on visible pool objects — unused objects are skipped
- In shader path, `drawShaderTexturedTriangles` is called ~18 times per frame (after batching)
- Batch FFI metadata API: 1 native call per frame instead of ~1400 per-drawable calls
- UV and index data cached at construction (0 FFI at runtime); vertex positions cached with dirty markers
- Vertex data per draw call: typically 50-500 vertices
