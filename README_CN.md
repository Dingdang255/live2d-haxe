# live2d-haxe

[English](./README.md)

Live2D Cubism SDK for Haxe —— 多后端渲染抽象层，基于 CalcOnly 架构。

本库为 Haxe 项目提供独立、可复用的 Live2D Cubism 集成。采用 "CalcOnly" 方案：C++ 端仅负责参数计算（物理、动作、表情等），Haxe 端通过可插拔的后端接口完成全部渲染。

**当前目标平台：** Windows x64（cpp 目标） | **架构：** 多后端（内置 OpenFL/Flixel，可扩展至其他框架）

详见 [ARCHITECTURE.md](./ARCHITECTURE.md) 架构文档和 [BACKEND_GUIDE.md](./BACKEND_GUIDE.md) 新后端开发指南。

## 演示

<video src="https://github.com/user-attachments/assets/c98ea2d4-15c6-4584-9d7d-ad84c42fa06a" controls="controls" style="max-width: 100%;"></video>

> 演示了模型切换、点击命中测试、表情切换、动作播放、视线追踪和缩放。

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
│  OpenFLRenderer · HxcppWindowsBridge · (未来: ...)   │
└─────────────────────────────────────────────────────┘
         ↕ ICubismBridge (GetProcAddress/dlopen/...)
    live2d_capi.dll/.so/.dylib → Live2DCubismCore
```

- **C++ 原生层**（`live2d_capi.dll`）：封装 Cubism SDK 的扁平 C API。仅执行参数/动作计算，不做 GPU 渲染。
- **核心逻辑层**（`L2DCore`）：平台无关的批处理构建、遮罩分组、顶点变换和渲染调度。
- **后端接口层**（`IL2DRenderer`、`ICubismBridge`）：渲染和原生访问的契约接口，支持多后端。
- **后端实现层**：`OpenFLRenderer`（drawTriangles）、`HxcppWindowsBridge`（GetProcAddress）。添加新后端只需实现这两个接口。

详见 [ARCHITECTURE.md](./ARCHITECTURE.md) 完整架构说明和 [BACKEND_GUIDE.md](./BACKEND_GUIDE.md) 新后端开发指南。

## 前置条件

- Haxe 4.2.5+
- hxcpp 4.2.1+
- CMake 3.16+
- Visual Studio 2019/2022（编译原生 C++）
- **Cubism SDK for Native 5-r.5**（未随库附带，见下方说明）

Flixel/OpenFL 后端（当前默认）额外需要：
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

构建完成后，在 `lib/win/` 目录下可找到：

- `live2d_capi.dll` — C API 桥接层
- `Live2DCubismCore.dll` — Cubism Core（从 SDK 自动复制）

## 第 4 步：复制 DLL 到你的项目（Windows）

DLL 必须在运行时可访问。将它们复制到项目的输出目录：

```
your_project/
  export/windows/cpp/bin/
    your_app.exe
    live2d_capi.dll        <-- 复制到这里
    Live2DCubismCore.dll   <-- 复制到这里
```

可通过构建后脚本自动化。

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

### 向后兼容

旧的导入路径通过 deprecated typedef 仍然可用：

```haxe
// 旧写法（已弃用，但仍可工作）
import live2d.cubism.L2DComponent;       // → L2DFlixelComponent
import live2d.cubism.L2DManager;          // → L2DFlixelManager
import live2d.cubism.L2D;                 // → CubismAPI
import live2d.cubism.L2DModel;            // → core.L2DModel

// 新写法（推荐）
import live2d.cubism.flixel.L2DFlixelComponent;
import live2d.cubism.flixel.L2DFlixelManager;
import live2d.cubism.core.CubismAPI;
import live2d.cubism.core.L2DModel;
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
| `startMotion(group, no, priority)` | 播放动作 |
| `startIdleMotion()` | 播放随机空闲动作 |
| `setExpression(id)` | 按 ID 设置表情 |
| `setRandomExpression()` | 设置随机表情 |
| `hitTest(areaName, px, py)` | 在屏幕坐标处进行命中测试 |
| `setDragging(screenX, screenY)` | 设置拖拽/跟随目标 |
| `getContainer()` | 获取根显示对象句柄 |
| `render()` | 重绘所有可见 drawable |
| `update(elapsed)` | 使用 deltaTime 更新模型 |
| `destroy()` | 释放模型和资源 |
| `getCanvasWidth()`, `getCanvasHeight()` | 模型画布尺寸 |

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
| ... | 全部 35 个 C API 函数均可作为静态方法调用 |

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

- **仅 Windows x64**（当前桥接层）— `HxcppWindowsBridge` 使用 Windows 特有的 `GetProcAddress`/`LoadLibraryA`。Linux/macOS 支持需要使用 `dlopen`/`dlsym` 实现新的桥接层。
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
