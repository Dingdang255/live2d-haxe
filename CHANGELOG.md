# Changelog

All notable changes to this project will be documented in this file.

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
