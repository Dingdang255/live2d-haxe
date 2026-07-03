# Changelog

All notable changes to this project will be documented in this file.

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
