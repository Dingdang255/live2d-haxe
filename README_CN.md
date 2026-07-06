# live2d-haxe

[English](./README.md)

Live2D Cubism SDK for Haxe —— 多后端渲染抽象层，基于 CalcOnly 架构。

本库为 Haxe 项目提供独立、可复用的 Live2D Cubism 集成。采用 "CalcOnly" 方案：C++ 端仅负责参数计算（物理、动作、表情等），Haxe 端通过可插拔的后端接口完成全部渲染。

**当前目标平台：** Windows x64（cpp + hl 双目标） | **架构：** 多后端（内置 OpenFL/Flixel，可扩展至其他框架）

详见 [ARCHITECTURE.md](./ARCHITECTURE.md) 架构文档和 [BACKEND_GUIDE.md](./BACKEND_GUIDE.md) 新后端开发指南。

## 演示

### cpp 目标（Flixel/OpenFL）

<video src="https://github.com/user-attachments/assets/c98ea2d4-15c6-4584-9d7d-ad84c42fa06a" controls="controls" style="max-width: 100%;"></video>

> 演示了模型切换、点击命中测试、表情切换、动作播放、视线追踪和缩放。

### hl 目标（HashLink/JIT）

<video src="https://github.com/user-attachments/assets/f8d0088d-1dd3-439c-93a8-d4b3d8b47742" controls="controls" style="max-width: 100%;"></video>

> HashLink JIT 加速演示。更快的开发迭代，无需 C++ 重编译。兼容 Lime 8.0.1 和 8.3.0。

## 架构

```
┌─────────────────────────────────────────────────────┐
│  框架集成层                                          │
│  L2DFlixelComponent / L2DHeapsObject / ...          │
├─────────────────────────────────────────────────────┤
│  核心逻辑层                                          │
│  L2DCore（平台无关）                                  │
├─────────────────────────────────────────────────────┤
│  后端接口层                                          │
│  IL2DRenderer  ·  ICubismBridge                     │
├─────────────────────────────────────────────────────┤
│  后端实现层                                          │
│  OpenFLRenderer · HxcppWindowsBridge · HlWindowsBridge │
└─────────────────────────────────────────────────────┘
         ↕ ICubismBridge (GetProcAddress/dlopen/...)
    live2d_capi.dll/.so/.dylib → Live2DCubismCore
```

- **C++ 原生层**（`live2d_capi.dll`）：封装 Cubism SDK 的扁平 C API。仅执行参数/动作计算，不做 GPU 渲染。
- **核心逻辑层**（`L2DCore`）：平台无关的批处理构建、遮罩分组、顶点变换和渲染调度。
- **后端接口层**（`IL2DRenderer`、`ICubismBridge`）：渲染和原生访问的契约接口，支持多后端。
- **后端实现层**：`OpenFLRenderer`（drawTriangles）、`HxcppWindowsBridge`（GetProcAddress，#if cpp）、`HlWindowsBridge`（@:hlNative，#if hl）。添加新后端只需实现这两个接口。

详见 [ARCHITECTURE.md](./ARCHITECTURE.md) 完整架构说明和 [BACKEND_GUIDE.md](./BACKEND_GUIDE.md) 新后端开发指南。

## 前置条件

- Haxe 4.2.5+
- CMake 3.16+
- Visual Studio 2019/2022（编译原生 C++）
- **Cubism SDK for Native 5-r.5**（未随库附带，见下方说明）

**cpp 目标**需要：
- hxcpp 4.2.1+

**hl 目标**需要：
- Lime 8.0.1+（提供 HL 运行时，无需额外 haxelib）

Flixel/OpenFL 后端（默认）额外需要：
- Lime 8.0.1+
- OpenFL 9.2.1+
- Flixel 4.11.0+

## 第 1 步：下载 Cubism SDK

Cubism SDK **未包含**在本库中。你需要自行下载并同意 Live2D 许可协议。

1. 访问：https://www.live2d.com/download/cubism-sdk/download-native/
2. 下载 **Cubism SDK for Native 5-r.5**（或兼容版本）
3. 解压到某目录，如 `C:/SDK/CubismSdkForNative-5-r.5/`
4. 确保该目录包含 `Framework/src/` 和 `Core/` 子目录

## 第 2 步：安装 Haxelib

方式 A — 下载发布包安装：
```bash
haxelib install live2d-haxe
```

方式 B — 从 GitHub 仓库安装：
```bash
haxelib git live2d-haxe https://github.com/Dingdang255/live2d-haxe.git
```

方式 C — 本地开发模式（仅限对本库进行贡献开发时使用）：
```bash
haxelib dev live2d-haxe /path/to/live2d-haxe
```

## 第 3 步：编译原生 DLL（Windows x64）

进入库的 native 目录（可通过 `haxelib path live2d-haxe` 查找路径）并构建：

```bash
cd native
mkdir build
cd build

# 使用 CMake 配置，指向你的 Cubism SDK，指定 x64 架构
cmake .. -DCUBISM_ROOT="C:/SDK/CubismSdkForNative-5-r.5" -A x64

# 构建（推荐 Release 模式）
cmake --build . --config Release
```

构建完成后，你可以找到以下文件：

- `live2d_capi.dll` — C API 桥接层（cpp 目标），位于 `lib/win/Release/`
- `live2d_hl.hdll` — HL 原生扩展（hl 目标），位于 `lib/win/Release/`
- `Live2DCubismCore.dll` — Cubism Core（从 SDK 自动复制），位于 `lib/win/` 目录（不在 Release 子目录）

> **注意**：CMake 自动检测已安装的 Lime 版本的 HL SDK（8.3.0 → 8.0.1，按 `include/hl.h` 存在优先）。.hdll 与 Lime 8.0.1 和 8.3.0 运行时均兼容。

## 第 4 步：复制 DLL 到你的项目（Windows）

DLL 必须在运行时可访问。将它们复制到项目的输出目录：

**cpp 目标：**
```
your_project/
  export/windows/cpp/bin/
    your_app.exe
    live2d_capi.dll        <-- 复制到这里
    Live2DCubismCore.dll   <-- 复制到这里
```

**hl 目标：**
```
your_project/
  bin/hl/bin/
    your_app.exe
    live2d_capi.dll        <-- 复制到这里
    live2d_hl.hdll         <-- 复制到这里
    Live2DCubismCore.dll   <-- 复制到这里
    libhl.dll              <-- Lime 自动复制
```

> **注意**：`libhl.dll` 由 Lime 从其 templates 自动复制，不要手动复制以避免版本不匹配。

可通过构建后脚本自动化（参见 test 目录的 `copy.bat` 和 `copy_hl.bat`）。

## 第 5 步：准备 Live2D 模型资源

将 Live2D 模型资源放在项目的 assets 目录中：

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

确保在 `Project.xml` 中包含资源：
```xml
<assets path="assets/live2d" rename="assets/live2d" />
```

## 用法（Flixel/OpenFL 后端）

### 基础：使用 L2DFlixelComponent 加载单个模型

```haxe
import live2d.cubism.flixel.L2DFlixelComponent;
import openfl.display.Sprite;

class MyState extends FlxState
{
    var l2d:L2DFlixelComponent;
    
    override public function create()
    {
        super.create();
        
        // 加载 Live2D 模型
        l2d = new L2DFlixelComponent('assets/live2d/Haru/', 'Haru.model3.json');
        
        // 位置和缩放
        l2d.x = FlxG.width / 2;
        l2d.y = FlxG.height / 2;
        l2d.scale = 0.3;
        
        // 将 OpenFL Sprite 添加到显示列表
        FlxG.stage.addChild(l2d.getSprite());
    }
    
    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // 更新模型（动作、物理等）
        l2d.update(elapsed);
        
        // 更新后渲染
        l2d.render();
    }
    
    override public function destroy()
    {
        // 销毁前从舞台移除 Sprite
        if (l2d != null && l2d.getSprite() != null)
        {
            FlxG.stage.removeChild(l2d.getSprite());
        }
        l2d.destroy();
        super.destroy();
    }
}
```

### 使用 L2DFlixelManager 管理多个模型

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
        
        // L2DFlixelManager 负责框架初始化和纹理缓存
        bg = L2DFlixelManager.create('assets/live2d/Background/', 'bg.model3.json');
        character = L2DFlixelManager.create('assets/live2d/Haru/', 'Haru.model3.json');
        
        // 添加 Sprite
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

### 播放动作和表情

```haxe
// 播放指定动作（组名、索引、优先级）
// 优先级：0=无, 1=空闲, 2=普通, 3=强制
var handle = l2d.startMotion('TapBody', 0, 3);

// 检查动作是否完成
if (l2d.model.notNull() && CubismAPI.isMotionFinished(l2d.model, handle))
{
    trace('动作播放完毕！');
}

// 播放随机空闲动作
l2d.startIdleMotion();

// 设置指定表情
l2d.setExpression('smile');

// 设置随机表情
l2d.setRandomExpression();
```

### 交互：命中测试与拖拽

```haxe
// 检查鼠标点击是否命中指定区域
if (FlxG.mouse.justPressed)
{
    var mx = FlxG.mouse.screenX;
    var my = FlxG.mouse.screenY;
    
    if (l2d.hitTest('Body', mx, my))
    {
        l2d.startMotion('TapBody', 0, 3);
    }
}

// 鼠标跟随（眼睛/头部）
if (FlxG.mouse.pressed)
{
    l2d.setDragging(FlxG.mouse.screenX, FlxG.mouse.screenY);
}
```

### Framework 行为控制

v0.5.0 新增 7 个 Framework 行为模块的运行时开关，以及外部口型同步值输入：

```haxe
// 运行时开关各行为模块（默认全部启用）
l2d.core.setBreathEnabled(false);      // 关闭呼吸动画
l2d.core.setPhysicsEnabled(false);     // 关闭物理演算
l2d.core.setEyeBlinkEnabled(false);    // 关闭自动眨眼
l2d.core.setExpressionEnabled(false);  // 关闭表情更新
l2d.core.setLookEnabled(false);        // 关闭视线追踪
l2d.core.setLipSyncEnabled(false);     // 关闭口型同步
l2d.core.setPoseEnabled(false);        // 关闭姿势过渡

// 读取当前启用状态
trace(l2d.core.breathEnabled);   // true/false

// 外部口型同步（麦克风/音频 RMS → 嘴巴张开度）
l2d.core.setLipSyncValue(0.5);   // 0.0~1.0 嘴巴张开度
l2d.core.setLipSyncValue(-1.0);  // <0 切回 wav 文件处理模式
```

### moc 版本检测

v0.5.0 新增 moc3 版本一致性检测 API，加载不兼容模型时会输出详细错误信息而非静默崩溃：

```haxe
import live2d.cubism.L2DCore;

// 静态方法，无需模型实例
var coreVer = L2DCore.getCoreVersion();         // Core DLL 版本号
var latestMoc = L2DCore.getLatestMocVersion();  // 最高支持的 moc 版本
var ok = L2DCore.hasMocConsistency("path/to/model.moc3");  // 检查兼容性

// L2DCore 加载时自动检测
// 不兼容时输出：[L2D] ERROR: moc3 file incompatible with current Core!
//   Core supports moc version ≤ X
//   Possible fix: re-export from Cubism Editor with lower target version
```

### 底层 API（CubismAPI）

高级用法可直接使用 `CubismAPI` 类访问全部 C API 函数：

```haxe
import live2d.cubism.core.CubismAPI;
import live2d.cubism.core.L2DModel;

// 框架生命周期
CubismAPI.frameworkStartUp();

// 模型生命周期
var model:L2DModel = CubismAPI.loadModel('assets/live2d/Haru/', 'Haru.model3.json');
CubismAPI.update(model);
CubismAPI.releaseModel(model);

// 参数
var paramCount = CubismAPI.getParameterCount(model);
var eyeXIndex = CubismAPI.findParameterIndex(model, 'ParamEyeBallX');
var eyeXValue = CubismAPI.getParameterValue(model, eyeXIndex);
CubismAPI.setParameterValue(model, eyeXIndex, 0.5, 1.0);

// Drawable 数据
var drawCount = CubismAPI.getDrawableCount(model);
var vertCount = CubismAPI.getDrawableVertexCount(model, 0);
var opacity = CubismAPI.getDrawableOpacity(model, 0);
var isVisible = CubismAPI.isDrawableVisible(model, 0);
```

### 从 v0.4 迁移到 v0.5

v0.5.0 移除了 `L2DComponent` 和 `L2D` 两个 deprecated typedef。如果你使用了旧导入路径，请更新：

```haxe
// v0.4 旧写法（已移除）
import live2d.cubism.L2DComponent;       // ❌ 不再存在
import live2d.cubism.L2D;                 // ❌ 不再存在

// v0.5 新写法
import live2d.cubism.flixel.L2DFlixelComponent;
import live2d.cubism.core.CubismAPI;

// 仍可用的别名
import live2d.cubism.L2DManager;          // ✅ 保留为 L2DFlixelManager 的别名
import live2d.cubism.L2DModel;            // ✅ 保留为 core.L2DModel 的别名
```

## API 参考

### L2DFlixelComponent（继承 FlxBasic）

| 属性/方法 | 说明 |
| --- | --- |
| `x`, `y` | 屏幕坐标 |
| `scale` | 渲染缩放因子 |
| `alpha` | 全局透明度乘数 |
| `model` | 底层 `L2DModel` 句柄 |
| `modelWidth`, `modelHeight` | 计算得到的模型边界 |
| `startMotion(group, no, priority)` | 播放动作 |
| `startIdleMotion()` | 播放随机空闲动作 |
| `setExpression(id)` | 按 ID 设置表情 |
| `setRandomExpression()` | 设置随机表情 |
| `hitTest(areaName, px, py)` | 在屏幕坐标处进行命中测试 |
| `setDragging(screenX, screenY)` | 设置拖拽/跟随目标 |
| `getSprite()` | 获取 OpenFL Sprite 容器 |
| `render()` | 重绘所有可见 drawable |
| `getCanvasWidth()`, `getCanvasHeight()` | 模型画布尺寸 |

### L2DFlixelManager（静态类）

| 方法 | 说明 |
| --- | --- |
| `create(dir, fileName)` | 创建模型（带纹理缓存） |
| `destroy(model)` | 销毁指定模型 |
| `destroyAll()` | 销毁所有管理的模型 |
| `updateAll(elapsed)` | 更新所有模型 |
| `renderAll()` | 渲染所有模型 |
| `clearTextureCache()` | 释放缓存的纹理 |
| `getContainer()` | 获取全局 Sprite 容器 |

### L2DCore（平台无关）

| 属性/方法 | 说明 |
| --- | --- |
| `x`, `y` | 屏幕坐标 |
| `scale` | 渲染缩放因子 |
| `alpha` | 全局透明度乘数 |
| `model` | 底层 `L2DModel` 句柄 |
| `modelWidth`, `modelHeight` | 计算得到的模型边界 |
| `ownsTextures` | 是否持有纹理生命周期（默认 true） |
| `breathEnabled` | 呼吸动画启用状态 |
| `eyeBlinkEnabled` | 自动眨眼启用状态 |
| `expressionEnabled` | 表情更新启用状态 |
| `lookEnabled` | 视线追踪启用状态 |
| `physicsEnabled` | 物理演算启用状态 |
| `lipSyncEnabled` | 口型同步启用状态 |
| `poseEnabled` | 姿势过渡启用状态 |
| `startMotion(group, no, priority)` | 播放动作 |
| `startIdleMotion()` | 播放随机空闲动作 |
| `setExpression(id)` | 按 ID 设置表情 |
| `setRandomExpression()` | 设置随机表情 |
| `hitTest(areaName, px, py)` | 在屏幕坐标处进行命中测试 |
| `setDragging(screenX, screenY)` | 设置拖拽/跟随目标 |
| `setBreathEnabled(enabled)` | 开关呼吸动画 |
| `setEyeBlinkEnabled(enabled)` | 开关自动眨眼 |
| `setExpressionEnabled(enabled)` | 开关表情更新 |
| `setLookEnabled(enabled)` | 开关视线追踪 |
| `setPhysicsEnabled(enabled)` | 开关物理演算 |
| `setLipSyncEnabled(enabled)` | 开关口型同步 |
| `setPoseEnabled(enabled)` | 开关姿势过渡 |
| `setLipSyncValue(value)` | 设置外部口型同步值（0~1，<0 切回 wav） |
| `getContainer()` | 获取根显示对象句柄 |
| `render()` | 重绘所有可见 drawable |
| `update(elapsed)` | 使用 deltaTime 更新模型 |
| `destroy()` | 释放模型和资源 |
| `getCanvasWidth()`, `getCanvasHeight()` | 模型画布尺寸 |
| `getCoreVersion()` | 获取 Cubism Core 版本号（静态） |
| `getLatestMocVersion()` | 获取最高支持的 moc 版本（静态） |
| `hasMocConsistency(path)` | 检查 moc3 文件兼容性（静态） |

### CubismAPI（静态门面）

| 方法 | 说明 |
| --- | --- |
| `frameworkStartUp()` | 初始化 Cubism 框架 |
| `frameworkCleanUp()` | 清理框架 |
| `getBridge()` | 获取当前 ICubismBridge 实现 |
| `setBridge(bridge)` | 设置自定义 ICubismBridge 实现 |
| `loadModel(dir, fileName)` | 从目录加载模型 |
| `releaseModel(model)` | 释放模型 |
| `update(model)` | 更新模型状态 |
| `setBreathEnabled(model, enabled)` | 开关呼吸动画 |
| `setEyeBlinkEnabled(model, enabled)` | 开关自动眨眼 |
| `setExpressionEnabled(model, enabled)` | 开关表情更新 |
| `setLookEnabled(model, enabled)` | 开关视线追踪 |
| `setPhysicsEnabled(model, enabled)` | 开关物理演算 |
| `setLipSyncEnabled(model, enabled)` | 开关口型同步 |
| `setPoseEnabled(model, enabled)` | 开关姿势过渡 |
| `setLipSyncValue(model, value)` | 设置外部口型同步值 |
| `getCoreVersion()` | 获取 Core 版本号 |
| `getLatestMocVersion()` | 获取最高支持的 moc 版本 |
| `hasMocConsistency(path)` | 检查 moc3 文件兼容性 |
| ... | 全部 46 个 C API 函数均可作为静态方法调用 |

## 项目配置

在你的 `Project.xml` 中：

```xml
<!-- 必需 -->
<haxelib name="hxcpp" />
<haxelib name="live2d-haxe" />

<!-- Flixel/OpenFL 后端 -->
<haxelib name="flixel" />
<haxelib name="openfl" />
```

请确保你的项目目标平台为 Windows x64。

## 原生 DLL 构建配置（Windows）

`native/` 目录中的 CMakeLists.txt 支持以下选项：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `CUBISM_ROOT` | `../CubismSdkForNative-5-r.5` | Cubism SDK 路径 |

自定义 SDK 路径示例：

```bash
cmake .. -DCUBISM_ROOT="D:/SDK/CubismSdkForNative-5-r.5" -A x64
```

## 已知限制

- **仅 Windows x64**（当前桥接层）— `HxcppWindowsBridge`（#if cpp）使用 Windows 特有的 `GetProcAddress`/`LoadLibraryA`。`HlWindowsBridge`（#if hl）使用 `@:hlNative` 绑定到内部调用 `LoadLibraryA` 的 .hdll shim。Linux/macOS 支持需要使用 `dlopen`/`dlsym` 实现新的桥接层。
- **CalcOnly 渲染** — C++ 端不做 GPU 渲染；所有绘制通过渲染后端完成（如 OpenFL 的 `drawTriangles`，GPU 加速）。
- **GPU 着色器路径**（默认）— 遮罩、正片叠底/滤色颜色和透明度由 `CubismRendererShader` 片段着色器处理。所有 drawable 均可合批，不受颜色/透明度限制。批键 = (texture, blendMode, maskGroup, mulColor, scrColor, opacity)。着色器不可用或模型超过 3 个遮罩组时自动回退至 `Sprite.mask`。
- **批量渲染** — 状态相同的 drawable 合并为一次 draw call。典型模型：~18 个批次，来自 ~130 个独立 draw call。Sprite 池化（32 batch + 16 mask）避免每帧分配。
- **遮罩组** — GPU 着色器路径最多支持 3 个遮罩组（RGB 通道打包）。超过 3 个组的模型回退至 `Sprite.mask`。

## 许可证

本库代码以 **MIT 许可证** 发布。

**Live2D Cubism SDK** 本身受 Live2D 自身许可条款约束。你必须单独下载并同意其许可：
https://www.live2d.com/download/cubism-sdk/download-native/

## 致谢

- 基于 Live2D Inc. 的 Live2D Cubism SDK for Native
- 演示视频使用了 Live2D 示例模型（Haru、Hiyori、Mao、Mark、Natori、Rice）。这些角色的著作权归 Live2D Inc. 所有，按照 [Live2D 免费素材许可协议](https://www.live2d.com/eula/live2d-free-material-license-agreement_jp.html) 及 [示例数据使用条款](https://www.live2d.com/learn/sample/model-terms/) 使用。

> 本作品のキャラクターには株式会社Live2Dの著作物であるサンプルデータが株式会社Live2Dの定める規約に従って用いられています。本作品は制作者の完全な自己の裁量で制作されています。
