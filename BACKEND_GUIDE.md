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
- **Framework behavior control** (v0.5+): 7 `setXxxEnabled(model, enabled)` methods for Breath/EyeBlink/Expression/Look/Physics/LipSync/Pose, plus `setLipSyncValue(model, value)` for external audio input
- **Moc version checking** (v0.5+): `getCoreVersion()`, `getLatestMocVersion()`, `hasMocConsistency(path)` — static methods, no model handle needed
- **Total methods**: 46 (framework lifecycle 2 + model lifecycle 2 + update 2 + parameters 4 + animation 3 + expression 2 + interaction 2 + drawable 12 + mask 4 + batch 1 + texture 2 + model info 2 + behavior control 7 + lip sync value 1 + version checking 3 - 1 getBridge not in interface)

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

## Reference Implementations

### OpenFLRenderer (live2d.cubism.backend.openfl)

The `OpenFLRenderer` is the primary reference implementation. Key aspects:

- **GPU Shader path**: `CubismRendererShader` (extends `GraphicsShader`) handles mask sampling, Multiply/Screen color blending, and per-drawable opacity via fragment shader uniforms. Uses `@:glFragmentBody` for custom GLSL injection.
- **Texture injection**: Constructor accepts `textureLoader`, `textureDestroyer`, and `textureToBitmapData` functions, allowing the same renderer to work with both plain `BitmapData` and Flixel's `FlxGraphic`
- **Array to Vector conversion**: `Vector.ofArray()` converts Haxe `Array<Float>` to OpenFL `Vector<Float>` for `drawTriangles()`
- **Blend mode mapping**: Simple switch statement mapping Live2D values to `openfl.display.BlendMode` enum
- **Automatic fallback**: `supportsShaderMask()` returns `true`; users can set `useShaderMask = false` to force fallback to `Sprite.mask` + `ColorTransform`
- **Premultiplied alpha**: OpenFL uses premultiplied alpha blending (`One, OneMinusSrcAlpha`). Per-drawable opacity is applied as RGBA scaling: `gl_FragColor *= u_opacity`.

### HeapsRenderer (live2d.cubism.backend.heaps)

The `HeapsRenderer` is the second reference implementation (v0.7.0+, HL target only). Key aspects:

- **GPU Shader path**: `CubismHeapsShader` (extends `hxsl.Shader`, priority=200) runs its `fragment()` before `Base2d.fragment()` (priority=100), modifying the shared `pixelColor` variable. Base2d then writes `output.color = pixelColor`. Mask, Multiply/Screen color, and per-drawable opacity are toggled by uniforms (`u_useMask`, `u_useColor`, `u_opacity`).
- **Mesh rendering**: `L2DMeshDrawable` extends `h2d.Drawable` and wraps a `MeshPrimitive` (extends `h3d.prim.Primitive`) with 8-float RawFormat vertices (x, y, u, v, r, g, b, a). Each frame: `updateMesh()` → `primitive.flush()` (reallocate GPU buffers) → `ctx.beginDrawObject(this, texture)` → `primitive.render(engine)`.
- **Texture loading**: Uses `format.png.Reader` (pure Haxe PNG decoder, no `fmt.hdll` dependency) → `h3d.mat.Texture.fromPixels` with `Filter.Linear`.
- **Mask RT**: `renderMaskToBitmapData()` allocates a `h3d.mat.Texture` with `[Target]` flag, then uses `RenderContext.pushTarget(maskRT)` / `popTarget()` to render mask shapes. A dedicated `maskDrawable` (not in the scene graph) with `CubismMaskShader` (solid-color fill) renders each mask group in its assigned RGB channel (R/G/B for groups 0/1/2). Vertices are converted from screen space to RT-local by subtracting `offsetX`/`offsetY`; the Y-axis flip is handled automatically by `pushTarget`'s view matrix (`viewD = 2/height`, positive).
- **Blend mode difference (critical)**: Heaps `BlendMode.Alpha` uses **non-premultiplied** alpha blending (`SrcAlpha, OneMinusSrcAlpha`), unlike OpenFL's premultiplied (`One, OneMinusSrcAlpha`). Per-drawable opacity must be applied as **alpha-only scaling** (`pixelColor.a *= u_opacity`), NOT RGBA scaling. RGBA scaling would cause double-darkening during blend because the blend stage multiplies by `SrcAlpha` again. Same logic applies to mask: `pixelColor.a *= maskVal` (not `pixelColor.rgb *= maskVal`).
- **hxsl priority sorting**: Shaders are sorted by priority descending (`haxe.ds.ArraySort.sort(shaderDatas, function(s1, s2) return s2.p - s1.p)`). Higher priority executes first. `CubismHeapsShader` uses priority=200 to run before `Base2d` (priority=100), so it can modify `pixelColor` before `Base2d` writes it to `output.color`.
- **u_maskTexture always bound**: The `@param var u_maskTexture : Sampler2D` requires a valid texture binding even when `u_useMask=0`. A 1x1 white texture (`Texture.fromColor(0xFFFFFFFF)`) is bound as default in `createDisplayObject`, both branches of `drawShaderTexturedTriangles`, and `drawTexturedTriangles`.
- **No fallback path**: `supportsShaderMask()` returns `true`; the non-shader path (`drawTexturedTriangles`) still works but `setMask`/`clearMask`/`drawSolidTriangles` are stubbed (shader path only). The `useShaderMask=false` fallback to `Sprite.mask` equivalent is not implemented in v0.7.0.

## Performance Notes

- L2DCore pre-allocates display object pools (32 batch + 16 mask objects)
- `resetDisplayObject` is called only on visible pool objects — unused objects are skipped
- In shader path, `drawShaderTexturedTriangles` is called ~18 times per frame (after batching)
- Batch FFI metadata API: 1 native call per frame instead of ~1400 per-drawable calls
- UV and index data cached at construction (0 FFI at runtime); vertex positions cached with dirty markers
- Vertex data per draw call: typically 50-500 vertices

## HashLink Backend Notes

The HL target requires a `.hdll` native extension (C shim) because HL cannot use `untyped __cpp__()` or direct `LoadLibraryA` from Haxe code.

### Architecture

```
Haxe (@:hlNative)  →  live2d_hl.hdll  →  live2d_capi.dll  →  Live2DCubismCore.dll
    HL VM loads        Dynamic loading      C API bridge        Live2D SDK Core
```

### Type Mapping (HL ↔ C)

| Haxe type | HL C type | C API type | Notes |
|-----------|-----------|------------|-------|
| `hl.I64` | `_I64` / `int64_t` | `void*` (pointer) | Model handles, M()/P() helpers |
| `hl.Bytes` | `_BYTES` / `vbyte*` | `const char*` / `float*` / `int*` | String input, byte buffers |
| `Int` | `_I32` | `int` | Counts, indices |
| `Float` | `_F64` | `float` (cast) | Delta time, positions |
| `Bool` | `_BOOL` | `bool` | Visibility, flags |

### Key Differences from HxcppWindowsBridge

1. **String handling**: cpp uses `str.utf8_str()`, HL uses `hl.Bytes.fromUTF8(str)` for input, null-terminator scanning + `getString()` for output
2. **Bytes access**: cpp uses `out->b.mPtr->GetBase()`, HL uses `@:privateAccess out.b`
3. **Function loading**: cpp uses `@:cppFileCode` inline C, HL uses .hdll `HL_PRIM`/`DEFINE_PRIM` macros
4. **Float precision**: HL passes `_F64` (double), .hdll casts to `float` before calling C API

### Building the .hdll

```bash
cd dev/native
cmake -B build -DCUBISM_ROOT=/path/to/CubismSdkForNative-5-r.5 -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target live2d_hl
```

Output: `dev/lib/win/live2d_hl.hdll`

### Running with HL target

```bash
cd dev/test
lime test hl
```

Required DLLs/HDLLs in the HL output directory:
- `live2d_hl.hdll` — HL native extension (loaded by HL VM)
- `live2d_capi.dll` — C API bridge (loaded by .hdll via LoadLibraryA)
- `Live2DCubismCore.dll` — Live2D SDK Core (dependency of live2d_capi.dll)
- `libhl.dll` — HL runtime (automatically provided by Lime from its templates)

### Lime Version Compatibility

The .hdll is compiled using `hl.h` headers and `libhl.lib` from Lime's HL SDK. Since our .hdll only uses `HL_PRIM`/`DEFINE_PRIM` macros (type definitions and symbol export declarations) and does not call any `hl_*` functions at runtime, a .hdll compiled with one Lime version's SDK is compatible with any HL runtime version:

| Compile with | Run with | Compatible? |
|-------------|----------|-------------|
| Lime 8.3.0 HL SDK | Lime 8.3.0 runtime | Yes |
| Lime 8.3.0 HL SDK | Lime 8.0.1 runtime | Yes |
| Lime 8.0.1 HL SDK* | Lime 8.0.1 runtime | Yes |

\* Lime 8.0.1 does not include `include/hl.h`; CMake auto-detects Lime 8.3.0's headers for compilation.

CMake auto-detection order: `lime/8,3,0` → `lime/8,0,1` (uses first one with `include/hl.h`). Override with `-DHL_ROOT=path`.
