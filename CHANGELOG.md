# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-07-13

### v1.1.0 — Perf panel + VTuber model adapter + Physics tuner + Mask SSAA + Demo polish

**One-line:** New features: cross-backend performance panel (`L2DPerfPanel` + 3 implementations), VTube Studio model adapter (`L2DVTuberModel` with subdir scanning), runtime physics tuner (`L2DPhysicsTuner` with gravity/wind/strength control), mask RT 2× SSAA, and demo polish (dynamic statusText Y). No breaking changes.

**Full description:**

This release adds four new extension-layer utilities and one internal Heaps optimization. All changes are additive — no existing API is removed or renamed.

- **A3. Performance Panel** — New `ext/L2DPerfPanel.hx` abstract base class plus three backend implementations: `L2DHeapsPerfPanel` (h2d.Text), `L2DOpenFLPerfPanel` (TextField), `L2DFlixelPerfPanel` (FlxText). Displays frame time, draw calls, batch count, mask RT size, model info, and enabled modules. Auto-hooks to `L2DCore` + renderer for real-time stats.
- **P1b. VTube Studio Model Adapter** — New `ext/L2DVTuberModel.hx` parses `.vtube.json` files used by VTube Studio. Extracts `FileReferences.Model`, `FileReferences.IdleAnimation`, and `Hotkeys[]` (ToggleExpression / TriggerAnimation). Implements `buildFileMap()` to scan the model directory + 6 common subdirectories (`expressions/`, `expr/`, `motions/`, `motion/`, `animations/`, `animation/`) and `resolveFilePath()` to map bare filenames to relative paths. Works with `L2DCore.loadExpressionFile()` / `applyExpressionFile()`.
- **P2. Physics Tuner** — New `ext/L2DPhysicsTuner.hx` provides runtime control over physics parameters. Two layers: (1) native physics options via `setGravity()`/`setWind()`/`reset()`/`stabilize()` — directly writes to SDK's `CubismPhysics::_options`; (2) Haxe-side strength blending via `physicsStrength` (0.0–1.0) — snapshots physics-affected parameter values before/after `core.update()` and interpolates. Parses `.physics3.json` metadata (FPS, input/output counts, setting names). Native layer adds 4 C APIs: `l2d_set_physics_options`, `l2d_get_physics_options`, `l2d_reset_physics`, `l2d_stabilize_physics`.
- **D6. Mask SSAA** — Heaps mask RT now uses 2× supersampling (`MASK_SSAA_FACTOR = 2`). Physical RT dimensions are doubled, vertex positions scaled up, and bilinear filtering during sampling produces smooth mask edges.
- **D3. Demo Polish** — `HeapsDemo.hx` and `L2DDemoState.hx` now compute `statusText.y` dynamically from `infoText.textHeight` / `infoText.height`, preventing overlap when info text varies.
- **Architecture Doc Update** — `ARCHITECTURE.md` D4 section updated to reflect current implementation (3 pre-allocated independent maskDrawables + fallbackPool) instead of old `invalidateBuffer()` approach. README.md/README_CN.md expanded with L2DPhysicsTuner and L2DVTuberModel documentation sections.
- **Cleanup** — Removed unused `live2d_capi.def` (module definition file no longer needed; DLL exports declared inline in source). Updated `CMakeLists.txt` to remove the DEF file reference.

---

### v1.1.0 — 性能面板 + VTuber 模型适配器 + 物理调优器 + Mask SSAA + Demo 打磨

**一行描述：** 新增跨后端性能面板（`L2DPerfPanel` + 3 个实现）、VTube Studio 模型适配器（`L2DVTuberModel` 子目录扫描）、运行时物理调优器（`L2DPhysicsTuner` 重力/风力/强度控制）、Mask RT 2× SSAA，以及 Demo 打磨（动态 statusText Y）。无破坏性变更。

**完整描述：**

本版本新增四个扩展层工具和一项 Heaps 内部优化。所有改动都是新增——不删除、不重命名任何既有 API。

- **A3. 性能面板** — 新增 `ext/L2DPerfPanel.hx` 抽象基类 + 三个后端实现：`L2DHeapsPerfPanel`（h2d.Text）、`L2DOpenFLPerfPanel`（TextField）、`L2DFlixelPerfPanel`（FlxText）。显示帧时间、draw call 数、batch 数、mask RT 尺寸、模型信息、启用模块。自动挂载到 `L2DCore` + 渲染器实时采集统计。
- **P1b. VTube Studio 模型适配器** — 新增 `ext/L2DVTuberModel.hx`，解析 VTube Studio 使用的 `.vtube.json` 文件。提取 `FileReferences.Model`、`FileReferences.IdleAnimation`、`Hotkeys[]`（ToggleExpression / TriggerAnimation）。实现 `buildFileMap()` 扫描模型目录 + 6 个常见子目录（`expressions/`、`expr/`、`motions/`、`motion/`、`animations/`、`animation/`），`resolveFilePath()` 将裸文件名映射为相对路径。与 `L2DCore.loadExpressionFile()` / `applyExpressionFile()` 配合使用。
- **P2. 物理调优器** — 新增 `ext/L2DPhysicsTuner.hx`，提供运行时物理参数控制。两层： (1) 原生物理选项 `setGravity()`/`setWind()`/`reset()`/`stabilize()` —— 直接写入 SDK 的 `CubismPhysics::_options`；(2) Haxe 侧强度混合 `physicsStrength`（0.0–1.0）—— 在 `core.update()` 前后快照物理影响参数并插值。解析 `.physics3.json` 元数据（FPS、输入/输出计数、设置名称）。Native 层新增 4 个 C API：`l2d_set_physics_options`、`l2d_get_physics_options`、`l2d_reset_physics`、`l2d_stabilize_physics`。
- **D6. Mask SSAA** — Heaps mask RT 现在使用 2× 超采样（`MASK_SSAA_FACTOR = 2`）。物理 RT 尺寸翻倍，顶点坐标等比放大，采样时双线性过滤产生平滑的 mask 边缘。
- **D3. Demo 打磨** — `HeapsDemo.hx` 和 `L2DDemoState.hx` 现在动态计算 `statusText.y`（基于 `infoText.textHeight` / `infoText.height`），避免信息文本变化时重叠。
- **架构文档更新** — `ARCHITECTURE.md` D4 节更新为当前实现（3 个预分配独立 maskDrawable + fallbackPool），替换旧的 `invalidateBuffer()` 描述。README.md/README_CN.md 新增 L2DPhysicsTuner 和 L2DVTuberModel 文档节。
- **清理** — 移除无用的 `live2d_capi.def`（模块定义文件不再需要；DLL 导出已在源码中内联声明）。更新 `CMakeLists.txt` 移除 DEF 文件引用。

## [1.0.0] - 2026-07-09

### v1.0.0 — First stable release: Heaps performance + DX combo + LipSync backend specialization

**One-line:** First stable release. Heaps rendering hardened (sync ordering fix eliminates double GPU upload, grow-only Dynamic buffer reuse, mask RT cache pool for concurrent models); DX combo (stat-mtime hot-reload + `h2d.filter.Group` chain API); LipSync backend specialization (`L2DAudioSourceBase` + three backend `AudioSource` implementations driving amplitude from live playback position). No breaking changes.

**Full description:**

This release hardens the Heaps backend with three internal optimizations and adds two Heaps-specific DX tools plus a backend-aware LipSync audio source layer. All changes are additive — no existing API is removed or renamed. With these in place the library ships as the first stable (1.0.0) release.

- **D1. Heaps sync ordering fix** — `L2DHeapsObject.sync()` reordered so `core.update(dt)` + `core.render()` run **before** `super.sync(ctx)`. h2d's `sync` is top-down (parent before children); the previous order caused `L2DMeshDrawable.sync` to read stale vertex counts, triggering a second GPU upload during `draw`. The new order ensures the mesh drawable sees the current frame's vertices during its own sync, so `draw` uploads exactly once.
- **D2. Heaps GPU buffer reuse** — `L2DMeshDrawable` now uses a grow-only `h3d.Buffer` (`BufferFlag.Dynamic` + `BufferFlag.RawFormat`) that is reused across frames and reallocated only when capacity is insufficient. `uploadVector` uploads in place; `render` passes an explicit `drawTri` count to limit drawing to the active index range. Eliminates per-frame buffer allocation for the typical 130-drawable model.
- **D3. Heaps Mask RT cache pool** — New `L2DHeapsMaskRTCache` with a POOL strategy: each concurrent model gets its own render-target instance; on release the RT returns to a pool keyed by `"WxH"` for future reuse. `HeapsRenderer.destroyContainer` and `renderMaskToBitmapData` now call `release`/`get` instead of alloc/dispose. A refcount single-RT approach was rejected because concurrent models would overwrite each other's mask data (sync(A) writes masks → sync(B) overwrites the RT → draw(A) samples B's masks).
- **D4. Heaps mask group buffer isolation** — All mask groups share one reusable `maskDrawable` and its `MeshPrimitive` in `renderMaskToBitmapData`. Without isolation, group N's `updateMesh` → `glBufferSubData` overrides the GPU vertex buffer while group N−1's `glDrawElements` is still in flight, causing the GPU to render group N−1's shapes at group N's vertex positions (reproduced as disappearing right-eye mask). Fix: added `MeshPrimitive.invalidateBuffer()` that disposes the current GPU buffer, forcing a fresh allocation per group. Called between groups in `renderMaskToBitmapData` and at the end of `drawSolidTriangles` to prevent cross-call races.
- **C1. L2DAudioSourceBase shared base** — New `ext/L2DAudioSourceBase.hx` implementing `IL2DAudioSource` by composing `L2DWavFileAudioSource`. Exposes `update(dt)`, `getAmplitude()`, `rewind()`, `currentTime`, `duration`, `looping`. Backend subclasses only need to set `wav.positionProvider` in their constructor; the base class handles WAV decoding and RMS.
- **C2/C3/C4. Three backend AudioSources** — `ext/heaps/L2DHeapsAudioSource.hx` (`hxd.res.Sound` + `hxd.snd.Channel.position` in seconds), `ext/openfl/L2DOpenFLAudioSource.hx` (`openfl.media.Sound` + `SoundChannel.position` ms→s, with manual pause/resume since `SoundChannel` has no native pause), `ext/flixel/L2DFlixelAudioSource.hx` (`FlxSound.time` ms→s). All three let `L2DLipSync` read amplitude from the backend's currently playing audio channel instead of pre-decoding a wav.
- **C5. LipSync docs** — `IL2DAudioSource.hx` now lists every implementation (`L2DCallbackAudioSource`, `L2DWavFileAudioSource`, `L2DAudioSourceBase` + three backend subclasses). `L2DLipSync.hx` usage example updated to the two-step pattern: `source.update(dt); lipSync.update(dt)` — because `L2DLipSync.update` only calls `source.getAmplitude()` and never calls `source.update(dt)`.
- **A1. Heaps hot-reload** — `L2DHeapsObject.hotReloadEnabled` toggles stat-mtime polling (~5 syscalls/frame) inside `sync()`. Watches the model3.json + same-name `.moc3` + `FileReferences.Physics`/`Pose`/`Expressions[].File`. On change, `reload()` does construct-new-then-swap: builds a new `L2DCore`, checks `model.notNull()` to detect half-written files, preserves transform (x/y/scale/alpha), disposes the old core, rebuilds the watch list, and restarts idle motion. Failures set `reloadPending` for a next-frame retry.
- **A2. Heaps filter chain API** — `L2DHeapsObject` gains `addFilter(f)`, `removeFilter(f):Bool`, `clearFilters()`, `getFilters():Array<Filter>`. Backed by `h2d.filter.Group`, lazily created and bound to `this.filter` on first `addFilter`. Works with the built-in `Glow`/`Blur`/`Outline`/`ColorMatrix`/`DropShadow` filters; mask RT (sync phase) and filters (draw phase) are temporally and target-independent, so they compose cleanly.
- **Demos** — `HeapsDemo.hx` and `L2DDemoState.hx` add three keys: **H** toggles hot-reload, **F** cycles a 5-mode filter chain (none → glow → blur → outline → glow+blur → clear), **V** toggles LipSync driven by `L2DCallbackAudioSource` with a synthesized sine-wave amplitude (no wav file required; comments show how to swap in `L2DHeapsAudioSource`/`L2DFlixelAudioSource`).
- **Version** — `haxelib.json` bumped 0.9.0 → 1.0.0.

---

### v1.0.0 — 首个稳定版：Heaps 性能 + DX 神器组合 + LipSync 后端特化

**一行描述：** 首个稳定版本。Heaps 渲染加固（sync 时序修复消除双 GPU 上传、grow-only Dynamic buffer 复用、mask RT 缓存池支持并发模型）；DX 神器组合（stat-mtime 热重载 + `h2d.filter.Group` 链式 API）；LipSync 后端特化（`L2DAudioSourceBase` + 三个后端 AudioSource 实现，从实时播放位置驱动振幅）。无破坏性变更。

**完整描述：**

本版本通过三项内部优化加固 Heaps 后端，并新增两项 Heaps 专属 DX 工具和一层后端感知的 LipSync 音频源。所有改动都是新增——不删除、不重命名任何既有 API。补齐后作为首个稳定版（1.0.0）发布。

- **D1. Heaps sync 时序修复** — `L2DHeapsObject.sync()` 重排，使 `core.update(dt)` + `core.render()` 在 `super.sync(ctx)` **之前**执行。h2d 的 `sync` 是 top-down（parent 先于 children）；旧顺序导致 `L2DMeshDrawable.sync` 读到过时的顶点计数，在 `draw` 阶段触发第二次 GPU 上传。新顺序确保 mesh drawable 在自身 sync 时看到本帧顶点，`draw` 只上传一次。
- **D2. Heaps GPU buffer 复用** — `L2DMeshDrawable` 改用 grow-only `h3d.Buffer`（`BufferFlag.Dynamic` + `BufferFlag.RawFormat`），跨帧复用、容量不足才扩容。`uploadVector` 原地上传；`render` 传显式 `drawTri` 计数，仅绘制活跃索引范围。消除典型 130-drawable 模型的逐帧 buffer 分配。
- **D3. Heaps Mask RT 缓存池** — 新增 `L2DHeapsMaskRTCache`，采用 POOL 策略：每个并发模型独享一个 render-target 实例；释放时 RT 按 `"WxH"` 为 key 归还池待复用。`HeapsRenderer.destroyContainer` 和 `renderMaskToBitmapData` 改调 `release`/`get` 而非 alloc/dispose。拒绝 refcount 单 RT 方案，因为并发模型会互相覆盖 mask 数据（sync(A) 写 mask → sync(B) 覆盖 RT → draw(A) 采样到 B 的 mask）。
- **D4. Heaps mask group 缓冲区隔离** — `renderMaskToBitmapData` 中所有 mask group 共享一个可复用的 `maskDrawable` 和 `MeshPrimitive`。不隔离时，group N 的 `updateMesh` → `glBufferSubData` 会在 group N−1 的 `glDrawElements` 仍在执行时覆盖 GPU 顶点缓冲区，导致 GPU 用 group N 的顶点位置渲染 group N−1 的形状（复现为右眼 mask 消失）。修复：新增 `MeshPrimitive.invalidateBuffer()`，销毁当前 GPU 缓冲区，强制每个 group 独立分配。在 `renderMaskToBitmapData` 的 group 间和 `drawSolidTriangles` 末尾调用，防止跨调用竞争。
- **C1. L2DAudioSourceBase 共享基类** — 新增 `ext/L2DAudioSourceBase.hx`，实现 `IL2DAudioSource`，组合 `L2DWavFileAudioSource`。暴露 `update(dt)`、`getAmplitude()`、`rewind()`、`currentTime`、`duration`、`looping`。后端子类只需在构造函数中设 `wav.positionProvider`，基类负责 WAV 解码与 RMS。
- **C2/C3/C4. 三后端 AudioSource** — `ext/heaps/L2DHeapsAudioSource.hx`（`hxd.res.Sound` + `hxd.snd.Channel.position` 秒）、`ext/openfl/L2DOpenFLAudioSource.hx`（`openfl.media.Sound` + `SoundChannel.position` ms→s，因 `SoundChannel` 无原生 pause 故手动实现）、`ext/flixel/L2DFlixelAudioSource.hx`（`FlxSound.time` ms→s）。三者均让 `L2DLipSync` 直接从后端正在播放的音频通道读取振幅，无需预解码 wav。
- **C5. LipSync 文档** — `IL2DAudioSource.hx` 列出全部实现（`L2DCallbackAudioSource`、`L2DWavFileAudioSource`、`L2DAudioSourceBase` + 三个后端子类）。`L2DLipSync.hx` 用法示例改为两步模式：`source.update(dt); lipSync.update(dt)`——因为 `L2DLipSync.update` 只调 `source.getAmplitude()`，不调 `source.update(dt)`。
- **A1. Heaps 热重载** — `L2DHeapsObject.hotReloadEnabled` 开启 sync() 内的 stat-mtime 轮询（~5 syscall/frame）。监听 model3.json + 同名 `.moc3` + `FileReferences.Physics`/`Pose`/`Expressions[].File`。变更时 `reload()` 执行 construct-new-then-swap：建新 `L2DCore`，检查 `model.notNull()` 探测写一半的文件，保留 transform（x/y/scale/alpha），销毁旧 core，重建监听列表，重启 idle motion。失败设 `reloadPending` 下帧重试。
- **A2. Heaps filter chain API** — `L2DHeapsObject` 新增 `addFilter(f)`、`removeFilter(f):Bool`、`clearFilters()`、`getFilters():Array<Filter>`。基于 `h2d.filter.Group`，首次 `addFilter` 时懒创建并绑定到 `this.filter`。兼容内置 `Glow`/`Blur`/`Outline`/`ColorMatrix`/`DropShadow`；mask RT（sync 阶段）与 filter（draw 阶段）时序和目标独立，互不干扰。
- **Demo** — `HeapsDemo.hx` 和 `L2DDemoState.hx` 新增三键：**H** 开关热重载、**F** 循环 5 种 filter 模式（none → glow → blur → outline → glow+blur → clear）、**V** 开关由 `L2DCallbackAudioSource` 合成正弦振幅驱动的 LipSync（无需 wav 文件；注释展示如何换成 `L2DHeapsAudioSource`/`L2DFlixelAudioSource`）。
- **版本** — `haxelib.json` 0.9.0 → 1.0.0。

## [0.9.0] - 2026-07-08

### v0.9.0 — Major update: native event bridge + Parts DSL + multi-model group + CLI

**One-line:** Major update with native-side motion UserData event bridge (callback + polling), L2DParts chain DSL + tween, FlxL2DGroup multi-model aggregation, L2DWavFileAudioSource (pure Haxe WAV decode + RMS), L2DDebugOverlay (Heaps+OpenFL), and `haxelib run live2d-haxe` CLI. Includes breaking API cleanup (removed wrapper delegates from L2DHeapsObject/L2DFlixelComponent).

**Full description:**

This release completes the extension layer with all remaining upper-layer utilities deferred from v0.8, plus the first native-side changes since v0.6 (motion UserData event bridge). The breaking change is small in scope (wrapper delegate removal) but improves API clarity: there is now a single source of truth — `L2DCore` — for all behavior, and the framework components expose only framework-specific lifecycle (update/render/destroy, transform getters).

- **Native: Motion UserData event bridge (A1-A4)** — `live2d_capi.h/cpp` gains 8 new C APIs: `l2d_poll_motion_events`, `l2d_get_part_count`, `l2d_get_part_id`, `l2d_find_part_index`, `l2d_get_part_opacity`, `l2d_set_part_opacity`, `l2d_reset_pose`, `l2d_get_pose`. `LAppModel_CalcOnly` overrides `MotionEventFired(csmString&)` (Cubism virtual) to collect UserData strings into a per-model queue; `l2d_poll_motion_events` drains the queue into a caller buffer (null-separated, double-null-terminated) and auto-clears. `live2d_hl.cpp` adds 8 HL_PRIM forwarders. Native code must be rebuilt for v0.9.
- **Haxe bridge layer (B1-B5)** — `ICubismBridge` declares 8 new methods; `HxcppWindowsBridge` implements via `@:cppFileCode` + `untyped __cpp__('...')`; `HlWindowsBridge` implements via `@:hlNative`; `CubismAPI` exposes 8 facade methods; `L2DCore` adds part API + `pollMotionEvents(buf, len)` convenience (`getPartId(partIndex)` included for `L2DParts` construction).
- **L2DParts + L2DPartHandle (C1)** — Chain DSL for part opacity: `parts.part("Hair").set(0.5).show().hide().toggle().tweenTo(0.0, 0.3)`. `L2DParts` caches handles at construction (one per part index), owns active tweens (ease-in-out cubic), exposes `tween(name, target, duration)` + `update(dt)` + `reset()` + `cancelAllTweens()`. `L2DPartTween` has `done` flag + `onComplete` dynamic callback. Fire-and-forget: manager auto-removes finished tweens.
- **Motion UserData event integration (C2)** — `L2DEvent` gains `MotionUserData(value:String)` variant. `L2DEventDispatcher` adds `onMotionUserData(cb)` subscription + `dynamic onMotionUserDataEvent(value)` callback + `pollMotionEvents()` (drains native queue → dispatches `MotionUserData` to both channels). `L2DMotionQueue.update(dt)` calls `dispatcher.pollMotionEvents()` at the top of each frame so users only need to call `motionQueue.update(dt)`.
- **FlxL2DGroup (C3)** — Multi-model aggregation extending `FlxGroup`. `add(component)` / `remove(component)` / `setHitAreas(component, areas)`. `autoMouseHitTest`: on `justPressed`, iterates topmost-first, dispatches via `dispatcher.hitTestAreas`. `autoMouseDrag`: on `justPressed` finds topmost via `hitTestPoint` (bounds-based), calls `core.setDragging` while pressed. `followCamera` + `followTarget` + `followLerp` for camera follow (FlxMath.lerp). `getComponentBounds(c):FlxRect` + `hitTestPoint(x, y)` for FlxCollision integration.
- **L2DWavFileAudioSource (C4)** — Pure Haxe WAV decoder + RMS amplitude source implementing `IL2DAudioSource`. `new(?path)` / `fromBytes(bytes)`. `parseWav` handles RIFF/WAVE PCM 16-bit mono/stereo. `update(dt)` advances playhead (looping). `getAmplitude()` sliding-window RMS (windowSize=1024, normalized to [0,1]). `currentTime` / `duration` read-only. Drop-in replacement for `L2DCallbackAudioSource` when driving `L2DLipSync` from a wav file.
- **L2DDebugOverlay (C5)** — Abstract base class + Heaps/OpenFL implementations. Toggles: `visible`/`showBounds`/`showParams`/`showHitAreas`. Config: `paramsToShow:Array<String>` / `hitAreas:Array<String>`. `textLines` array pattern: base class `drawText` appends, `render()` ends with `flushText()` (subclass batch-renders). `drawParams` uses `CubismAPI.findParameterIndex` + `CubismAPI.getParameterValue`. `L2DHeapsDebugOverlay` (h2d.Graphics + h2d.Text) and `L2DOpenFLDebugOverlay` (Shape + TextField) provided.
- **CLI (C6)** — `haxelib run live2d-haxe` with three commands: `--gen-constants <model3.json> [output.hx] [ClassName] [package]` generates a Haxe constants class (mirrors the `@:build` macro output); `--gen-asset-list <model3.json>` lists all referenced asset files; `--validate <model3.json>` checks that referenced files exist on disk. Correctly parses model3.json structure (`FileReferences.Motions` is an object keyed by group name, not an array). haxelib run CWD detection: pops the last arg if it's an existing directory.
- **Breaking change — wrapper delegate removal (D1-D2)** — `L2DHeapsObject` and `L2DFlixelComponent` no longer expose convenience delegates for `startMotion`/`startIdleMotion`/`setExpression`/`setRandomExpression`/`hitTest`/`setDragging`/`getCanvasWidth`/`getCanvasHeight`/`setBreathEnabled`/`setEyeBlinkEnabled`/`setExpressionEnabled`/`setLookEnabled`/`setPhysicsEnabled`/`setLipSyncEnabled`/`setPoseEnabled`/`setLipSyncValue`. Migration: `l2d.startMotion(...)` → `l2d.core.startMotion(...)`, `l2d.setBreathEnabled(...)` → `l2d.core.setBreathEnabled(...)`, etc. The components still expose `core`, `model`, `modelDir`, `modelFileName`, `modelWidth`, `modelHeight` getters, plus framework-specific lifecycle (`update`/`render`/`destroy`/`getSprite` for Flixel; `sync`/`onRemove` for Heaps) and transform (`x`/`y`/`scale`/`alpha` for Flixel). This eliminates the dual-API confusion and makes `L2DCore` the single source of truth.

---

### v0.9.0 — 大版本更新：native 事件桥接 + Parts DSL + 多模型组 + CLI

**一行描述：** 大版本更新，新增 native 端 motion UserData 事件桥接（回调 + 轮询）、L2DParts 链式 DSL + tween、FlxL2DGroup 多模型聚合、L2DWavFileAudioSource（纯 Haxe WAV 解码 + RMS）、L2DDebugOverlay（Heaps+OpenFL）和 `haxelib run live2d-haxe` CLI。包含破坏性 API 整理（删除 L2DHeapsObject/L2DFlixelComponent 的 convenience delegate）。

**完整描述：**

本版本补齐 v0.8 留待的全部上层扩展，并包含自 v0.6 以来的首次 native 改动（motion UserData 事件桥接）。破坏性变更范围较小（仅删除 wrapper delegate），但提升了 API 清晰度：现在 `L2DCore` 是所有行为的唯一入口，框架组件只暴露框架特定的生命周期（update/render/destroy、transform getter）。

- **Native: Motion UserData 事件桥接 (A1-A4)** — `live2d_capi.h/cpp` 新增 8 个 C API：`l2d_poll_motion_events`、`l2d_get_part_count`、`l2d_get_part_id`、`l2d_find_part_index`、`l2d_get_part_opacity`、`l2d_set_part_opacity`、`l2d_reset_pose`、`l2d_get_pose`。`LAppModel_CalcOnly` 重写 `MotionEventFired(csmString&)`（Cubism 虚函数）将 UserData 字符串收集到 per-model 队列；`l2d_poll_motion_events` 一次性将队列拷贝到调用方缓冲区（null 分隔，双 null 结尾）并自动清空。`live2d_hl.cpp` 添加 8 个 HL_PRIM 转发。v0.9 需要重新编译 native。
- **Haxe 桥接层 (B1-B5)** — `ICubismBridge` 声明 8 个新方法；`HxcppWindowsBridge` 用 `@:cppFileCode` + `untyped __cpp__('...')` 实现；`HlWindowsBridge` 用 `@:hlNative` 实现；`CubismAPI` 暴露 8 个 facade；`L2DCore` 添加 part API + `pollMotionEvents(buf, len)` 便捷方法（含 `getPartId(partIndex)` 供 `L2DParts` 构造使用）。
- **L2DParts + L2DPartHandle (C1)** — Part 透明度链式 DSL：`parts.part("Hair").set(0.5).show().hide().toggle().tweenTo(0.0, 0.3)`。`L2DParts` 在构造时缓存 handle（每个 part index 一个），拥有活动 tween（ease-in-out cubic），暴露 `tween(name, target, duration)` + `update(dt)` + `reset()` + `cancelAllTweens()`。`L2DPartTween` 有 `done` 标志 + `onComplete` dynamic 回调。Fire-and-forget：manager 自动移除完成的 tween。
- **Motion UserData 事件集成 (C2)** — `L2DEvent` 新增 `MotionUserData(value:String)` 变体。`L2DEventDispatcher` 添加 `onMotionUserData(cb)` 订阅 + `dynamic onMotionUserDataEvent(value)` 回调 + `pollMotionEvents()`（拉取 native 队列 → 同时派发到两个通道）。`L2DMotionQueue.update(dt)` 在每帧开头调用 `dispatcher.pollMotionEvents()`，用户只需调 `motionQueue.update(dt)` 即可。
- **FlxL2DGroup (C3)** — 多模型聚合组，继承 `FlxGroup`。`add(component)` / `remove(component)` / `setHitAreas(component, areas)`。`autoMouseHitTest`：`justPressed` 时按 topmost-first 遍历，通过 `dispatcher.hitTestAreas` 派发。`autoMouseDrag`：`justPressed` 时通过 `hitTestPoint`（基于 bounds）找 topmost，pressed 期间调 `core.setDragging`。`followCamera` + `followTarget` + `followLerp` 相机跟随（FlxMath.lerp）。`getComponentBounds(c):FlxRect` + `hitTestPoint(x, y)` 用于 FlxCollision 集成。
- **L2DWavFileAudioSource (C4)** — 纯 Haxe WAV 解码器 + RMS 振幅源，实现 `IL2DAudioSource`。`new(?path)` / `fromBytes(bytes)`。`parseWav` 处理 RIFF/WAVE PCM 16-bit mono/stereo。`update(dt)` 推进播放头（循环）。`getAmplitude()` 滑动窗口 RMS（windowSize=1024，归一化到 [0,1]）。`currentTime` / `duration` 只读。用 wav 文件驱动 `L2DLipSync` 时可直接替换 `L2DCallbackAudioSource`。
- **L2DDebugOverlay (C5)** — 抽象基类 + Heaps/OpenFL 实现。开关：`visible`/`showBounds`/`showParams`/`showHitAreas`。配置：`paramsToShow:Array<String>` / `hitAreas:Array<String>`。`textLines` 数组模式：基类 `drawText` 追加，`render()` 结束调 `flushText()`（子类批量渲染）。`drawParams` 用 `CubismAPI.findParameterIndex` + `CubismAPI.getParameterValue`。提供 `L2DHeapsDebugOverlay`（h2d.Graphics + h2d.Text）和 `L2DOpenFLDebugOverlay`（Shape + TextField）。
- **CLI (C6)** — `haxelib run live2d-haxe` 提供三个命令：`--gen-constants <model3.json> [output.hx] [ClassName] [package]` 生成 Haxe 常量类（与 `@:build` 宏输出对齐）；`--gen-asset-list <model3.json>` 列出所有引用的资源文件；`--validate <model3.json>` 检查引用文件是否存在。正确解析 model3.json 结构（`FileReferences.Motions` 是按 group name 为 key 的对象，不是数组）。haxelib run CWD 检测：若最后参数是已存在目录则 pop 并 setCwd。
- **破坏性变更 — wrapper delegate 删除 (D1-D2)** — `L2DHeapsObject` 和 `L2DFlixelComponent` 不再暴露 `startMotion`/`startIdleMotion`/`setExpression`/`setRandomExpression`/`hitTest`/`setDragging`/`getCanvasWidth`/`getCanvasHeight`/`setBreathEnabled`/`setEyeBlinkEnabled`/`setExpressionEnabled`/`setLookEnabled`/`setPhysicsEnabled`/`setLipSyncEnabled`/`setPoseEnabled`/`setLipSyncValue` 的便捷委托。迁移：`l2d.startMotion(...)` → `l2d.core.startMotion(...)`、`l2d.setBreathEnabled(...)` → `l2d.core.setBreathEnabled(...)` 等。组件仍暴露 `core`、`model`、`modelDir`、`modelFileName`、`modelWidth`、`modelHeight` getter，加框架特定生命周期（Flixel：`update`/`render`/`destroy`/`getSprite`；Heaps：`sync`/`onRemove`）和 transform（Flixel：`x`/`y`/`scale`/`alpha`）。这消除了双 API 困惑，让 `L2DCore` 成为唯一行为入口。

## [0.8.0] - 2026-07-07

### v0.8.0 — Extension Layer (cross-backend upper-layer extensions)

**One-line:** Add a fifth "Extension Layer" above L2DCore with 5 cross-backend extensions (MotionQueue, LookAt, LipSync, EventDispatcher, ModelConstants macro) + 2 abstraction interfaces (IL2DAudioSource, IL2DInputAdapter) + 3 backend InputAdapters, reducing boilerplate for "talking, responsive, mouse-following" characters. Zero native changes, all backends supported.

**Full description:**

This release introduces the Extension Layer — a set of optional, composable utility classes that sit above `L2DCore` and below the framework integration layer. All extensions are pure Haxe, depend only on `L2DCore`'s public API, and work across all three backends (OpenFL/Flixel/Heaps) without modification. Backend-specific concerns (audio amplitude, input events) are abstracted behind small interfaces (`IL2DAudioSource`, `IL2DInputAdapter`) that community backends can implement.

- **L2DMotionQueue** — Priority queue for motions with idle recovery. Force(3) interrupts current, Normal(2) queues, Idle(1) only when empty. Polls `CubismAPI.isMotionFinished` and auto-advances the queue. Optional idle recovery plays a random motion from an "Idle" group after a configurable delay.
- **L2DLookAt** — Damped mouse/touch → head/eye follow. Frame-rate-independent lerp (`1 - pow(1 - speed, dt*60)`), deadzone to prevent micro-jitter, auto-return to model center when no target is set. Wraps `L2DCore.setDragging`.
- **L2DLipSync** — Audio-driven mouth sync with attack/release smoothing and curve mapping. Reads amplitude from `IL2DAudioSource`, applies `pow(raw, curve) * maxValue`, eases with separate attack (opening) and release (closing) coefficients, writes to `L2DCore.setLipSyncValue`. `enable()` disables C-side wav mode to avoid conflict; `disable()` reverts.
- **L2DEventDispatcher** — Typed callback subscription (one method per event variant) with token-based unsubscribe. Events: `MotionBegan`, `MotionFinished`, `ExpressionSet`, `HitTest`, `IdleRecovery`, `QueueEmpty`. Includes `hitTestAreas()` convenience for batch hit testing.
- **L2DModelConstants** — `@:build` macro that parses `.model3.json` at compile time and generates `public static inline var` constants for motion groups, expressions, hit areas, parameter groups, and textures. Prevents string typos: `HaruConstants.Motions.Idel` fails to compile.
- **IL2DAudioSource** — Interface for audio amplitude measurement. `L2DCallbackAudioSource` wraps a user-supplied `() -> Float` getter as the default implementation. Backend-specific AudioSources (wav decode + RMS) deferred to v0.9.
- **IL2DInputAdapter** — Interface for input event normalization. Three implementations: `L2DOpenFLInputAdapter` (event-based, MouseEvent), `L2DFlixelInputAdapter` (polling-based, FlxG.mouse, requires `adapter.update()` call), `L2DHeapsInputAdapter` (event-based, hxd.Stage).
- **No breaking changes** — All extensions are optional, independent classes. Existing `L2DFlixelComponent`, `L2DHeapsObject`, `L2DCore`, `ICubismBridge`, `IL2DRenderer`, and native code are unchanged. Users adopt extensions by constructing them with a `L2DCore` reference.

---

### v0.8.0 — 扩展层（跨后端上层扩展）

**一行描述：** 在 L2DCore 之上新增第五层"扩展层"，包含 5 个跨后端扩展（MotionQueue、LookAt、LipSync、EventDispatcher、ModelConstants 宏）+ 2 个抽象接口（IL2DAudioSource、IL2DInputAdapter）+ 3 个后端输入适配器，大幅减少"会说话、会响应、会跟手"角色的样板代码。零 native 改动，三后端通吃。

**完整描述：**

本版本引入扩展层——一组可选、可组合的工具类，位于 `L2DCore` 之上、框架集成层之下。所有扩展均为纯 Haxe 实现，只依赖 `L2DCore` 的 public API，无需修改即可在三个后端（OpenFL/Flixel/Heaps）上使用。后端特定差异（音频取样、输入事件）通过小接口（`IL2DAudioSource`、`IL2DInputAdapter`）抽象，社区后端可自行实现。

- **L2DMotionQueue** — 动作优先级队列，支持空闲恢复。Force(3) 立即打断当前动作，Normal(2) 排队，Idle(1) 仅在队列空时入队。轮询 `CubismAPI.isMotionFinished` 并自动推进队列。可选空闲恢复在队列空超过配置延迟后自动播放 "Idle" 组的随机动作。
- **L2DLookAt** — 阻尼式鼠标/触摸 → 头部/眼睛跟随。帧率无关 lerp（`1 - pow(1 - speed, dt*60)`），死区防止微抖，无目标时自动回中。封装 `L2DCore.setDragging`。
- **L2DLipSync** — 音频驱动的口型同步，支持 attack/release 平滑和曲线映射。从 `IL2DAudioSource` 读取音量，应用 `pow(raw, curve) * maxValue`，用独立的 attack（张嘴）和 release（合嘴）系数做缓动，写入 `L2DCore.setLipSyncValue`。`enable()` 关闭 C 侧 wav 模式避免冲突；`disable()` 恢复。
- **L2DEventDispatcher** — 类型化回调订阅（每个事件变体一个方法）+ token 取消订阅。事件：`MotionBegan`、`MotionFinished`、`ExpressionSet`、`HitTest`、`IdleRecovery`、`QueueEmpty`。包含 `hitTestAreas()` 批量 hit test 便捷方法。
- **L2DModelConstants** — `@:build` 宏，在编译期解析 `.model3.json` 并生成 `public static inline var` 常量，覆盖动作组、表情、hit area、参数组和纹理。防止字符串 typo：`HaruConstants.Motions.Idel` 编译失败。
- **IL2DAudioSource** — 音频音量测量接口。`L2DCallbackAudioSource` 包装用户提供的 `() -> Float` getter 作为默认实现。后端专用 AudioSource（wav 解码 + RMS）留待 v0.9。
- **IL2DInputAdapter** — 输入事件统一化接口。三个实现：`L2DOpenFLInputAdapter`（事件式，MouseEvent）、`L2DFlixelInputAdapter`（轮询式，FlxG.mouse，需调 `adapter.update()`）、`L2DHeapsInputAdapter`（事件式，hxd.Stage）。
- **无破坏性变更** — 所有扩展均为可选独立类。现有 `L2DFlixelComponent`、`L2DHeapsObject`、`L2DCore`、`ICubismBridge`、`IL2DRenderer` 和 native 代码均不变。用户通过构造扩展类并传入 `L2DCore` 引用即可使用。

## [0.7.0] - 2026-07-07

### v0.7.0 — Heaps engine backend support

**One-line:** Add Heaps 1.9.1 rendering backend via `HeapsRenderer` + `L2DHeapsObject` + `CubismHeapsShader`, enabling Live2D models to run natively on the Heaps game engine (HL target) without OpenFL/Flixel dependency.

**Full description:**

This release adds a complete Heaps backend, allowing live2d-haxe to render Live2D models through Heaps' `h2d` scene graph. This unlocks Heaps-based Haxe projects (games, tools, editors) to use Live2D without bridging through OpenFL. The Heaps backend runs on the HL target only (Heaps does not support hxcpp).

- **HeapsRenderer** — New `IL2DRenderer` implementation using `h2d.Object` as container, `L2DMeshDrawable extends h2d.Drawable` as display object (8-float RawFormat vertices: x, y, u, v, r, g, b, a), and `h3d.mat.Texture` as texture. All 19 `IL2DRenderer` methods implemented. Texture loading via `format.png.Reader` (pure Haxe PNG decoder, no `fmt.hdll` dependency).
- **L2DMeshDrawable** — `h2d.Drawable` subclass wrapping a `MeshPrimitive extends h3d.prim.Primitive`. Each frame: `updateMesh()` → `primitive.flush()` (reallocate GPU buffers via `Buffer.uploadVector` + `Indexes.upload`) → `ctx.beginDrawObject(this, texture)` → `primitive.render(engine)` (`engine.renderIndexed`). Note: `h3d.prim.Primitive` has no public constructor, so `MeshPrimitive.new()` does not call `super()`.
- **CubismHeapsShader** — `hxsl.Shader` subclass (priority=200) handling mask sampling, Multiply/Screen color blending, and per-drawable opacity. Runs `fragment()` before `Base2d.fragment()` (priority=100) to modify the shared `pixelColor` variable. Toggle uniforms: `u_useMask`, `u_useColor`, `u_opacity`. Mask UVs computed from `absolutePosition.xy` (screen space) via `u_maskOffset` / `u_maskScale`.
- **CubismMaskShader** — Solid-color fill `hxsl.Shader` for mask RT rendering. Outputs flat `u_color` per fragment. Used by `HeapsRenderer.renderMaskToBitmapData()` to draw mask shapes in R/G/B channels (one per mask group, up to 3 groups).
- **Mask RT** — `renderMaskToBitmapData()` allocates `h3d.mat.Texture` with `[Target]` flag, uses `RenderContext.pushTarget(maskRT)` / `popTarget()` to render mask shapes off-screen. Screen-space vertices converted to RT-local by subtracting `offsetX`/`offsetY`. Y-axis flip handled automatically by `pushTarget`'s view matrix.
- **L2DHeapsObject** — `h2d.Object` subclass wrapping `L2DCore` + `HeapsRenderer`. Auto-updates and renders in `sync(ctx)` via `hxd.Timer.dt` — adding it to the scene is enough, no manual `update`/`render` calls. Exposes Flixel-aligned convenience API (`startMotion`, `setExpression`, `hitTest`, `setDragging`, `setBreathEnabled`, etc.) and `core` field for advanced access.
- **Non-premultiplied alpha** — Critical difference from OpenFL backend: Heaps `BlendMode.Alpha` uses `SrcAlpha, OneMinusSrcAlpha` (non-premultiplied), while OpenFL uses `One, OneMinusSrcAlpha` (premultiplied). Per-drawable opacity is applied as **alpha-only scaling** (`pixelColor.a *= u_opacity`) in Heaps, vs RGBA scaling (`gl_FragColor *= u_opacity`) in OpenFL. RGBA scaling in Heaps causes double-darkening during alpha transitions (e.g. pose changes).
- **DCE full required** — The hxml uses `-dce full` (not `-dce no`) to eliminate `hxd.snd.Mp3Data` which has `@:hlNative("fmt","mp3_open")`. With `-dce no`, the installed `fmt.hdll` signature mismatch causes runtime crash.
- **No breaking changes** — Existing OpenFL/Flixel backends, `L2DCore`, `ICubismBridge`, native code, and `haxelib.json` dependencies are unchanged. Heaps backend is opt-in via `-D heaps` and `-lib heaps` + `-lib hlsdl`.

---

### v0.7.0 — Heaps 引擎后端支持

**一行描述：** 新增 Heaps 1.9.1 渲染后端，通过 `HeapsRenderer` + `L2DHeapsObject` + `CubismHeapsShader` 实现，让 Live2D 模型原生运行在 Heaps 游戏引擎上（HL 目标），无需依赖 OpenFL/Flixel。

**完整描述：**

本版本新增完整的 Heaps 后端，允许 live2d-haxe 通过 Heaps 的 `h2d` 场景图渲染 Live2D 模型。这让基于 Heaps 的 Haxe 项目（游戏、工具、编辑器）无需通过 OpenFL 桥接即可使用 Live2D。Heaps 后端仅支持 HL 目标（Heaps 不支持 hxcpp）。

- **HeapsRenderer** — 新的 `IL2DRenderer` 实现，使用 `h2d.Object` 作为容器，`L2DMeshDrawable extends h2d.Drawable` 作为显示对象（8-float RawFormat 顶点：x, y, u, v, r, g, b, a），`h3d.mat.Texture` 作为纹理。全部 19 个 `IL2DRenderer` 方法已实现。纹理加载通过 `format.png.Reader`（纯 Haxe PNG 解码器，无 `fmt.hdll` 依赖）。
- **L2DMeshDrawable** — `h2d.Drawable` 子类，封装 `MeshPrimitive extends h3d.prim.Primitive`。每帧：`updateMesh()` → `primitive.flush()`（通过 `Buffer.uploadVector` + `Indexes.upload` 重建 GPU 缓冲区）→ `ctx.beginDrawObject(this, texture)` → `primitive.render(engine)`（`engine.renderIndexed`）。注意：`h3d.prim.Primitive` 无公共构造函数，`MeshPrimitive.new()` 不调用 `super()`。
- **CubismHeapsShader** — `hxsl.Shader` 子类（priority=200），处理遮罩采样、正片叠底/滤色混合和逐 drawable 透明度。`fragment()` 在 `Base2d.fragment()`（priority=100）之前运行，修改共享的 `pixelColor` 变量。开关 uniform：`u_useMask`、`u_useColor`、`u_opacity`。遮罩 UV 通过 `u_maskOffset` / `u_maskScale` 从 `absolutePosition.xy`（屏幕空间）计算。
- **CubismMaskShader** — 纯色填充 `hxsl.Shader`，用于遮罩 RT 渲染。每个片段输出固定 `u_color`。由 `HeapsRenderer.renderMaskToBitmapData()` 使用，按 R/G/B 通道绘制遮罩形状（每个遮罩组一个通道，最多 3 组）。
- **遮罩 RT** — `renderMaskToBitmapData()` 分配带 `[Target]` 标志的 `h3d.mat.Texture`，使用 `RenderContext.pushTarget(maskRT)` / `popTarget()` 离屏渲染遮罩形状。屏幕空间顶点通过减去 `offsetX`/`offsetY` 转换为 RT 局部坐标。Y 轴翻转由 `pushTarget` 的视图矩阵自动处理。
- **L2DHeapsObject** — `h2d.Object` 子类，封装 `L2DCore` + `HeapsRenderer`。在 `sync(ctx)` 中通过 `hxd.Timer.dt` 自动更新和渲染 —— 添加到场景即可，无需手动调用 `update`/`render`。暴露对齐 Flixel 风格的便捷 API（`startMotion`、`setExpression`、`hitTest`、`setDragging`、`setBreathEnabled` 等）和 `core` 字段供高级访问。
- **非预乘 Alpha** — 与 OpenFL 后端的关键差异：Heaps `BlendMode.Alpha` 使用 `SrcAlpha, OneMinusSrcAlpha`（非预乘），而 OpenFL 使用 `One, OneMinusSrcAlpha`（预乘）。逐 drawable 透明度在 Heaps 中以**仅 alpha 缩放**应用（`pixelColor.a *= u_opacity`），而 OpenFL 为 RGBA 缩放（`gl_FragColor *= u_opacity`）。在 Heaps 中使用 RGBA 缩放会导致 alpha 过渡时（如 pose 切换）双重变暗。
- **DCE full 必需** — hxml 使用 `-dce full`（而非 `-dce no`）以消除 `hxd.snd.Mp3Data`（含 `@:hlNative("fmt","mp3_open")`）。使用 `-dce no` 时，已安装的 `fmt.hdll` 签名不匹配会导致运行时崩溃。
- **无破坏性变更** — 现有 OpenFL/Flixel 后端、`L2DCore`、`ICubismBridge`、原生代码和 `haxelib.json` 依赖均不变。Heaps 后端通过 `-D heaps` 和 `-lib heaps` + `-lib hlsdl` 按需启用。

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
