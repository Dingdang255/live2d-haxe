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

    // Implement all 35 methods...
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
- **Function pointers**: Cache all 35 function pointers at load time for performance
- **String conversion**: Haxe `String.utf8_str()` provides UTF-8 C strings on hxcpp
- **Bytes output**: Use `out->b.mPtr->GetBase()` to get raw pointer from `haxe.io.Bytes`
- **Model handles**: `L2DModel` is `abstract L2DModel(cpp.Int64)`, cast via `cast(value, cpp.Int64)`

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
- Remove the container and all children from the scene

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
- If your framework uses shaders, pass these as uniforms
- For Live2D: `multiplier = multiplyColor * (1 - screenColor)`, `offset = screenColor * 255`

**`setMask(obj, mask)` / `clearMask(obj)`**
- Apply/remove a mask display object
- The mask has been drawn with `drawSolidTriangles` (white-filled triangles)
- If your framework supports alpha-based masking, use the mask as-is
- If your framework uses stencil buffers, you'll need to render the mask with stencil write enabled and the target with stencil test enabled

#### Drawing

**`drawTexturedTriangles(obj, texture, vertices, uvs, indices)`**
- All data is pre-transformed:
  - `vertices`: screen-space x,y pairs (already scaled, translated, Y-flipped)
  - `uvs`: texture coordinates (V already flipped: `1.0 - originalV`)
  - `indices`: triangle indices (already adjusted for batch merging)
- This is the core rendering call

**`drawSolidTriangles(obj, vertices, indices)`**
- Draw white-filled triangles (used for mask shapes)
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

- **Texture injection**: Constructor accepts `textureLoader`, `textureDestroyer`, and `textureToBitmapData` functions, allowing the same renderer to work with both plain `BitmapData` and Flixel's `FlxGraphic`
- **Array to Vector conversion**: `Vector.ofArray()` converts Haxe `Array<Float>` to OpenFL `Vector<Float>` for `drawTriangles()`
- **Blend mode mapping**: Simple switch statement mapping Live2D values to `openfl.display.BlendMode` enum
- **ColorTransform**: Direct mapping to `openfl.geom.ColorTransform` constructor
- **Masking**: Uses OpenFL's `sprite.mask` property (alpha-based masking)

## Performance Notes

- L2DCore pre-allocates display object pools (32 batch + 16 mask objects)
- `resetDisplayObject` is called on all pool objects every frame — keep it fast
- `drawTexturedTriangles` is called ~16-24 times per frame (after batching)
- Vertex data per call: typically 50-500 vertices
- The `Array<Float>` → platform vector conversion is the main overhead compared to direct platform APIs
