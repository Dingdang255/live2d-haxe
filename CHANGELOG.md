# Changelog

All notable changes to this project will be documented in this file.

## [0.6.0] - 2026-07-06

### v0.6.0 — HashLink backend support

**One-line:** Add HashLink (HL) target support via .hdll native extension with dynamic loading shim, enabling JIT-accelerated development iteration and Heaps engine compatibility.

**Full description:**

This release adds a complete HashLink backend, allowing live2d-haxe to run on the HL target alongside the existing cpp target. HL provides faster iteration (JIT compilation, no C++ rebuild), lower memory footprint, and compatibility with the Heaps game engine.

- **HlWindowsBridge** — New `ICubismBridge` implementation using `@:hlNative` bindings to `live2d_hl.hdll`. 51 native bindings covering all 46 ICubismBridge methods + init + 2 framework lifecycle calls. String input converted via `hl.Bytes.fromUTF8()`, Bytes output via `@:privateAccess out.b`.
- **live2d_hl.hdll** — C shim (455 lines) that dynamically loads `live2d_capi.dll` at runtime via `LoadLibraryA + GetProcAddress`, forwarding all 47 C API calls through `HL_PRIM`/`DEFINE_PRIM` macros. Uses `int64_t` for pointer handles (`M()`/`P()` helpers), `vbyte*` for byte buffers, `double` for float parameters.
- **L2DModel (HL)** — `abstract L2DModel(hl.I64)` with `isNull()` using `== cast 0`, symmetric with cpp target's `cpp.Int64` design.
- **CMakeLists.txt** — New `live2d_hl` build target: links `libhl.lib`, outputs `.hdll` extension. Auto-detects HL SDK from installed Lime versions (8.3.0 → 8.0.1), with `-DHL_ROOT=path` override. Compatible with both Lime 8.0.1 and 8.3.0 runtimes since .hdll only uses type definitions and export macros.
- **No rendering changes** — OpenFL/Flixel rendering layer works unchanged on HL target (no cpp-specific code in L2DCore, OpenFLRenderer, CubismRendererShader, L2DFlixelComponent, L2DFlixelManager).

---

### v0.6.0 — HashLink 后端支持

**一行描述：** 新增 HashLink (HL) 目标支持，通过 .hdll 原生扩展和动态加载 shim 实现 JIT 加速的开发迭代和 Heaps 引擎兼容。

**完整描述：**

本版本新增完整的 HashLink 后端，允许 live2d-haxe 在 HL 目标上运行，与现有 cpp 目标并存。HL 提供更快的迭代速度（JIT 编译，无需 C++ 重建）、更低内存占用，以及与 Heaps 游戏引擎的兼容性。

- **HlWindowsBridge** — 新的 `ICubismBridge` 实现，使用 `@:hlNative` 绑定到 `live2d_hl.hdll`。51 个原生绑定覆盖全部 46 个 ICubismBridge 方法 + init + 2 个 Framework 生命周期调用。字符串输入通过 `hl.Bytes.fromUTF8()` 转换，Bytes 输出通过 `@:privateAccess out.b` 提取。
- **live2d_hl.hdll** — C shim（455 行），运行时通过 `LoadLibraryA + GetProcAddress` 动态加载 `live2d_capi.dll`，通过 `HL_PRIM`/`DEFINE_PRIM` 宏转发全部 47 个 C API 调用。使用 `int64_t` 作为指针句柄（`M()`/`P()` 辅助函数），`vbyte*` 用于字节缓冲区，`double` 用于浮点参数。
- **L2DModel (HL)** — `abstract L2DModel(hl.I64)`，`isNull()` 使用 `== cast 0`，与 cpp 目标的 `cpp.Int64` 设计对称。
- **CMakeLists.txt** — 新增 `live2d_hl` 构建目标：链接 `libhl.lib`，输出 `.hdll` 扩展名。自动检测已安装的 Lime 版本的 HL SDK（8.3.0 → 8.0.1），支持 `-DHL_ROOT=path` 覆盖。由于 .hdll 仅使用类型定义和导出宏，编译产物兼容 Lime 8.0.1 和 8.3.0 运行时。
- **无渲染层变更** — OpenFL/Flixel 渲染层在 HL 目标上无需修改即可工作（L2DCore、OpenFLRenderer、CubismRendererShader、L2DFlixelComponent、L2DFlixelManager 中无 cpp 特定代码）。

## [0.5.0] - 2026-07-06

### v0.5.0 — Framework behavior control + moc version checking

**One-line:** Add runtime enable/disable control for all 7 Framework behavior modules (Breath, EyeBlink, Expression, Look, Physics, LipSync, Pose), external LipSync value input, and moc3 version consistency checking API.

**Full description:**

This release gives Haxe-side full control over Framework behavior modules that were previously always-on inside C++ with no external control. It also adds moc3 version checking APIs for compatibility validation before model loading.

- **BREAKING CHANGE** — `L2DComponent` and `L2D` typedefs in `live2d.cubism` package have been removed. Use `L2DFlixelComponent` and `CubismAPI` instead. `L2DManager` and `L2DModel` aliases are preserved.
- **Framework Behavior Control** — 7 new `setXxxEnabled()` methods on `L2DCore` allow runtime enable/disable of each behavior module: `setBreathEnabled`, `setEyeBlinkEnabled`, `setExpressionEnabled`, `setLookEnabled`, `setPhysicsEnabled`, `setLipSyncEnabled`, `setPoseEnabled`. All modules default to enabled (backward compatible). Each has a corresponding read-only property (e.g. `breathEnabled`).
- **External LipSync** — `setLipSyncValue(0.0~1.0)` allows driving mouth open amount from external audio/microphone input. Pass negative value to revert to internal wav file handler mode. Uses `model->AddParameterValue()` with 0.8 weight, same as the internal `CubismLipSyncUpdater`.
- **Moc Version Checking** — `L2DCore.getCoreVersion()` and `L2DCore.getLatestMocVersion()` return the Cubism Core version and highest supported moc version. `L2DCore.hasMocConsistency(mocFilePath)` checks a .moc3 file against the current Core without loading a model. L2DCore constructor automatically checks on load and outputs detailed error messages on incompatibility.
- **Manual Updater Management** — The 7 updaters are no longer registered with `_updateScheduler`; instead stored as member pointers in `LAppModel_CalcOnly` and manually called in `Update()` with enabled checks. This enables per-module control without modifying SDK Framework source.
- **frameworkCleanUp Fix** — `l2d_framework_clean_up` function pointer was missing from `HxcppWindowsBridge`, causing the cleanup method to be a no-op. Now properly loads and calls `CubismFramework::Dispose()` + `CubismFramework::CleanUp()`.
- **C++ Robustness** — `LoadAssets` now checks for NULL buffer (file not found) before passing to JSON parser, preventing abort(). `l2d_load_model` returns NULL on failure instead of dangling pointer. Destructor guards against NULL `_modelSetting`.
- **Demo Migration** — Demo (`L2DDemoState.hx`) migrated to new API (`L2DFlixelComponent`/`L2DFlixelManager`), added B/P/L keyboard shortcuts for toggling Breath/Physics/LipSync.

---

### v0.5.0 — Framework 行为控制 + moc 版本检测

**一行描述：** 新增 7 个 Framework 行为模块的运行时开关、外部口型同步值输入、moc3 版本一致性检测 API。

**完整描述：**

本版本让 Haxe 侧获得了对 Framework 行为模块的完整控制权，这些模块之前在 C++ 内部始终运行且无法外部控制。同时新增了 moc3 版本检测 API 用于加载前兼容性校验。

- **破坏性变更** — `live2d.cubism` 包中的 `L2DComponent` 和 `L2D` typedef 已移除。请使用 `L2DFlixelComponent` 和 `CubismAPI` 替代。`L2DManager` 和 `L2DModel` 别名保留。
- **Framework 行为控制** — `L2DCore` 新增 7 个 `setXxxEnabled()` 方法，允许运行时开关各行为模块：`setBreathEnabled`、`setEyeBlinkEnabled`、`setExpressionEnabled`、`setLookEnabled`、`setPhysicsEnabled`、`setLipSyncEnabled`、`setPoseEnabled`。所有模块默认启用（向后兼容），每个模块有对应的只读属性（如 `breathEnabled`）。
- **外部口型同步** — `setLipSyncValue(0.0~1.0)` 允许从外部音频/麦克风输入驱动口型张开度。传入负值切换回内部 wav 文件处理模式。使用 `model->AddParameterValue()` 加权 0.8，与内部 `CubismLipSyncUpdater` 行为一致。
- **moc 版本检测** — `L2DCore.getCoreVersion()` 和 `L2DCore.getLatestMocVersion()` 返回 Cubism Core 版本和最高支持的 moc 版本。`L2DCore.hasMocConsistency(mocFilePath)` 直接读取 .moc3 文件检查与当前 Core 的一致性，无需加载模型。L2DCore 构造函数在加载时自动检测，不兼容时输出详细错误信息。
- **手动 Updater 管理** — 7 个 Updater 不再注册到 `_updateScheduler`，改为在 `LAppModel_CalcOnly` 中存储为成员指针并在 `Update()` 中手动调用（带 enabled 检查），无需修改 SDK Framework 源码即可实现逐模块控制。
- **frameworkCleanUp 修复** — `HxcppWindowsBridge` 中缺少 `l2d_framework_clean_up` 函数指针加载，导致清理方法为空操作。现已正确加载并调用 `CubismFramework::Dispose()` + `CubismFramework::CleanUp()`。
- **C++ 健壮性** — `LoadAssets` 现在检查 NULL 缓冲区（文件不存在），防止传给 JSON 解析器导致 abort()。`l2d_load_model` 加载失败时返回 NULL 而非悬空指针。析构函数增加 `_modelSetting` NULL 保护。
- **Demo 迁移** — Demo（`L2DDemoState.hx`）已迁移至新 API（`L2DFlixelComponent`/`L2DFlixelManager`），新增 B/P/L 键盘快捷键用于切换 Breath/Physics/LipSync。

## [0.4.0] - 2026-07-05

### v0.4.0 — GPU Shader rendering pipeline

**One-line:** Migrate mask, Multiply/Screen color, and opacity from CPU (Sprite.mask + ColorTransform) to unified GPU fragment shader, with batch FFI metadata API to reduce per-frame native calls from ~4000 to ~10.

**Full description:**

This release replaces the CPU-based rendering pipeline with a GPU shader pipeline, dramatically reducing draw call overhead and enabling full batch merging regardless of per-drawable color or opacity.

- **CubismRendererShader** — Unified `GraphicsShader` using `@:glFragmentBody` that handles mask sampling, Multiply/Screen color blending, and per-drawable opacity via toggle uniforms (`u_useMask`, `u_useColor`, `u_opacity`). Replaces the previous Sprite.mask + ColorTransform + setAlpha approach.
- **GPU Mask Rendering** — Mask shapes are rendered to off-screen `BitmapData` (1/4 canvas resolution) with RGB channel packing (up to 3 mask groups). Dirty markers prevent redundant redraws. Mask UV computed from `openfl_Position` (local coords) to avoid coordinate system issues.
- **Multiply/Screen Color in Shader** — Blend-mode-specific application: Multiply(2/6) → `rgb *= mulColor`, Screen(10) → `rgb = rgb + scrColor * (1 - rgb)`, Normal/Add → no application. Conditional on `u_useColor > 0.5` to prevent state pollution.
- **Opacity in Shader** — `gl_FragColor *= u_opacity` (RGBA scaling) fixes the pre-multiplied alpha white-highlight bug during pose transitions.
- **Batch FFI Metadata API** — New `l2d_get_drawable_batch_metadata()` C API returns all drawable metadata (visible, renderOrder, opacity, textureIndex, blendMode, mulColor, scrColor, vertexDidChange) in a single `Bytes` buffer (48 bytes/drawable). Replaces ~1400 per-drawable FFI calls with 1 call.
- **Vertex Data Caching** — UVs and indices cached at construction (0 FFI at runtime). Vertex positions cached with dirty markers, only refreshed when changed. `fillVertexData()` uses member accumulators instead of anonymous objects to eliminate ~300 heap allocations per frame.
- **Full Batch Merging** — In shader path, ALL drawables are batchable regardless of color/opacity. Batch key = (texture, blendMode, maskGroup, mulColor, scrColor, opacity). Typical models: ~18 batches from ~130 individual draw calls.
- **Sprite Pooling** — 32 batch + 16 mask pre-created Sprites reused every frame. Only visible pool objects are reset, skipping unused ones.
- **Automatic Fallback** — `renderer.supportsShaderMask()` detects shader support; falls back to Sprite.mask path when unavailable or when model has >3 mask groups. Manual override via `useShaderMask = false`.

---

### v0.4.0 — GPU Shader 渲染管线

**一行描述：** 将遮罩、正片叠底/滤色颜色、透明度从 CPU（Sprite.mask + ColorTransform）迁移至统一 GPU 片段着色器，新增批量 FFI 元数据 API 将每帧原生调用从 ~4000 次降至 ~10 次。

**完整描述：**

本版本用 GPU 着色器管线替代了 CPU 渲染管线，大幅减少 draw call 开销，并实现了不论颜色或透明度如何均可完全合批。

- **CubismRendererShader** — 统一 `GraphicsShader`，使用 `@:glFragmentBody` 处理遮罩采样、正片叠底/滤色混合和逐 drawable 透明度，通过开关 uniform（`u_useMask`、`u_useColor`、`u_opacity`）控制。替代了之前的 Sprite.mask + ColorTransform + setAlpha 方案。
- **GPU 遮罩渲染** — 遮罩形状渲染至离屏 `BitmapData`（1/4 画布分辨率），使用 RGB 通道打包（最多 3 个遮罩组）。脏标记防止冗余重绘。遮罩 UV 从 `openfl_Position`（局部坐标）计算，避免坐标系问题。
- **着色器中的正片叠底/滤色** — 按混合模式应用：Multiply(2/6) → `rgb *= mulColor`，Screen(10) → `rgb = rgb + scrColor * (1 - rgb)`，Normal/Add → 不应用。以 `u_useColor > 0.5` 为条件，防止状态污染。
- **着色器中的透明度** — `gl_FragColor *= u_opacity`（RGBA 同时缩放）修复了预乘 Alpha 下 Pose 过渡时部件变白的 bug。
- **批量 FFI 元数据 API** — 新增 `l2d_get_drawable_batch_metadata()` C API，在单个 `Bytes` 缓冲区中返回所有 drawable 元数据（visible、renderOrder、opacity、textureIndex、blendMode、mulColor、scrColor、vertexDidChange，48 bytes/drawable）。用 1 次调用替代 ~1400 次逐 drawable FFI 调用。
- **顶点数据缓存** — UV 和索引在构造时缓存（运行时 0 FFI）。顶点位置带脏标记缓存，仅在变化时刷新。`fillVertexData()` 使用成员累加器替代匿名对象，消除每帧 ~300 次堆分配。
- **完全合批** — 着色器路径下，所有 drawable 均可合批，不受颜色/透明度限制。批键 = (texture, blendMode, maskGroup, mulColor, scrColor, opacity)。典型模型：~18 个批次，来自 ~130 个独立 draw call。
- **Sprite 池化** — 32 batch + 16 mask 预创建 Sprite 每帧复用。仅重置可见的池对象，跳过未使用的。
- **自动回退** — `renderer.supportsShaderMask()` 检测着色器支持；不可用或模型超过 3 个遮罩组时自动回退至 Sprite.mask 路径。可通过 `useShaderMask = false` 手动覆盖。

## [0.3.0] - 2026-07-03

### v0.3.0 — Multi-platform abstraction layer

**One-line:** Add multi-backend architecture with ICubismBridge and IL2DRenderer interfaces, extracting platform-independent logic into L2DCore.

**Full description:**

This release introduces a four-layer architecture that decouples platform-specific code from core Live2D logic, making it straightforward to add new rendering backends (Heaps, Kha, etc.) or native bridge implementations (Linux, macOS) in the future.

- **ICubismBridge** — Interface abstracting the 35 native C API functions. The existing Windows hxcpp implementation is extracted into `HxcppWindowsBridge` (`#if cpp`). New targets only need to implement this interface with their platform's dynamic library loading mechanism (e.g. `dlopen`/`dlsym` for Linux/macOS).
- **IL2DRenderer** — Interface abstracting all rendering operations (texture loading, display object management, triangle drawing, blend modes, color transforms, masking, display list ordering). OpenFL implementation provided as `OpenFLRenderer` (`#if openfl`) with injectable texture loader/destroyer functions for Flixel compatibility.
- **L2DCore** — Platform-independent class containing all batch building, mask grouping, vertex transformation, and render orchestration logic extracted from the previous `L2DComponent`. Delegates all platform-specific rendering to `IL2DRenderer`.
- **Framework integration** — `L2DFlixelComponent` (extends `FlxBasic`) and `L2DFlixelManager` (with `FlxGraphic` texture cache) provide the Flixel-specific wrappers (`#if flixel`).
- **Backward compatibility** — Original `L2D`, `L2DModel`, `L2DComponent`, `L2DManager` types in `live2d.cubism` package are preserved as deprecated typedefs. Existing code continues to work without modification.
- **Dependency change** — `flixel` and `openfl` are no longer hard dependencies in `haxelib.json`; only `hxcpp` is required. Users add the framework libraries they need.
- **Documentation** — Added `ARCHITECTURE.md` (architecture overview) and `BACKEND_GUIDE.md` (step-by-step guide for implementing new backends).

Adding a new backend now only requires implementing `IL2DRenderer` + `ICubismBridge`, then creating a framework wrapper class — all batch/mask/transform logic is inherited from `L2DCore`.

---

### v0.3.0 — 多平台抽象层

**一行描述：** 新增多后端架构，引入 ICubismBridge 和 IL2DRenderer 接口，将平台无关逻辑提取至 L2DCore。

**完整描述：**

本版本引入四层架构，将平台特定代码与 Live2D 核心逻辑解耦，使得未来添加新渲染后端（Heaps、Kha 等）或原生桥接实现（Linux、macOS）变得简单直接。

- **ICubismBridge** — 抽象 35 个原生 C API 函数的接口。现有 Windows hxcpp 实现已提取为 `HxcppWindowsBridge`（`#if cpp`）。新目标平台只需实现该接口，使用对应平台的动态库加载机制（如 Linux/macOS 的 `dlopen`/`dlsym`）。
- **IL2DRenderer** — 抽象所有渲染操作的接口（纹理加载、显示对象管理、三角形绘制、混合模式、颜色变换、遮罩、显示列表排序）。提供 `OpenFLRenderer`（`#if openfl`）作为参考实现，支持通过构造函数注入纹理加载/销毁函数以兼容 Flixel。
- **L2DCore** — 平台无关的核心类，从原 `L2DComponent` 中提取了全部批处理构建、遮罩分组、顶点变换和渲染调度逻辑。所有平台特定的渲染操作通过 `IL2DRenderer` 委托。
- **框架集成** — `L2DFlixelComponent`（继承 `FlxBasic`）和 `L2DFlixelManager`（含 `FlxGraphic` 纹理缓存）提供 Flixel 专属封装（`#if flixel`）。
- **向后兼容** — 原 `live2d.cubism` 包中的 `L2D`、`L2DModel`、`L2DComponent`、`L2DManager` 类型保留为 deprecated typedef，现有代码无需修改即可继续使用。
- **依赖变更** — `haxelib.json` 不再将 `flixel` 和 `openfl` 作为硬依赖，仅保留 `hxcpp`。用户按需引入对应框架库。
- **文档** — 新增 `ARCHITECTURE.md`（架构概览）和 `BACKEND_GUIDE.md`（新后端开发步骤指南）。

现在添加新后端只需实现 `IL2DRenderer` + `ICubismBridge`，再创建一个框架包装类即可——全部批处理/遮罩/变换逻辑从 `L2DCore` 自动继承。
