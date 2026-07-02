# live2d-haxe

[English](./README.md)

Live2D Cubism SDK 的 Haxe/Flixel 集成 —— 基于 CalcOnly 渲染，通过 OpenFL drawTriangles 绘制。

本库为 Haxe/Flixel 项目提供独立、可复用的 Live2D Cubism 集成。采用 "CalcOnly" 方案：C++ 端仅负责参数计算（物理、动作、表情等），Haxe 端通过 OpenFL 的 `Sprite.graphics.drawTriangles()` 完成全部渲染。

**目标平台：** 仅 Windows x64（cpp 目标）

## 演示

<video src="docs/test.mp4" controls width="600"></video>

> 演示了模型切换、点击命中测试、表情切换、动作播放、视线追踪和缩放。

## 架构

```
+-------------------+     GetProcAddress      +------------------+
|   Haxe/Flixel     | <=====================> |  live2d_capi.dll |
|   (渲染)           |    函数指针             |  (计算)           |
+-------------------+                         +------------------+
                                                       |
                                                       | 链接
                                                       v
                                              +------------------+
                                              | Live2DCubismCore |
                                              |    .dll + SDK    |
                                              +------------------+
```

- **C++ 原生层**（`live2d_capi.dll`）：封装 Cubism SDK 的扁平 C API。仅执行参数/动作计算，不做 OpenGL/DirectX 渲染。
- **Haxe 层**（`live2d.cubism`）：从 C++ 读取 drawable 数据（顶点、UV、索引、透明度），通过 OpenFL 的 `drawTriangles()` 渲染。
- **GetProcAddress**：运行时通过 `GetProcAddress` 加载函数指针，绕过 hxcpp FFI（避免崩溃）。

## 前置条件

- Haxe 4.2.5+
- hxcpp 4.2.1+
- Lime 8.0.1+
- OpenFL 9.2.1+
- Flixel 4.11.0+
- CMake 3.16+
- Visual Studio 2019/2022（编译原生 C++）
- **Cubism SDK for Native 5-r.5**（未随库附带，见下方说明）

## 第 1 步：下载 Cubism SDK

Cubism SDK **未包含**在本库中。你需要自行下载并同意 Live2D 许可协议。

1. 访问：https://www.live2d.com/download/cubism-sdk/download-native/
2. 下载 **Cubism SDK for Native 5-r.5**（或兼容版本）
3. 解压到某目录，如 `C:/SDK/CubismSdkForNative-5-r.5/`
4. 确保该目录包含 `Framework/src/` 和 `Core/` 子目录

## 第 2 步：编译原生 DLL

```bash
cd native
mkdir build && cd build

# 使用 CMake 配置，指向你的 Cubism SDK
cmake .. -DCUBISM_ROOT="C:/SDK/CubismSdkForNative-5-r.5"

# 构建（推荐 Release 模式）
cmake --build . --config Release
```

构建完成后，在 `lib/win/` 目录下可找到：

- `live2d_capi.dll` — C API 桥接层
- `Live2DCubismCore.dll` — Cubism Core（从 SDK 自动复制）

## 第 3 步：安装 Haxelib

```bash
# 开发模式（开发期间推荐）
haxelib dev live2d-haxe /path/to/live2d-haxe

# 或从 zip 安装
haxelib install live2d-haxe
```

## 第 4 步：复制 DLL 到你的项目

DLL 必须在运行时可访问。将它们复制到项目的输出目录：

```
your_project/
  export/windows/cpp/bin/
    your_app.exe
    live2d_capi.dll        <-- 复制到这里
    Live2DCubismCore.dll   <-- 复制到这里
```

可通过 Lime 的 `<assets>` 标签或构建后脚本自动化。

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
<assets path="assets/live2d" rename="live2d" />
```

## 用法

### 基础：使用 L2DComponent 加载单个模型

```haxe
import live2d.cubism.L2DComponent;
import openfl.display.Sprite;

class MyState extends FlxState
{
    var l2d:L2DComponent;
    
    override public function create()
    {
        super.create();
        
        // 加载 Live2D 模型
        l2d = new L2DComponent('assets/live2d/Haru/', 'Haru.model3.json');
        
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

### 使用 L2DManager 管理多个模型

```haxe
import live2d.cubism.L2DManager;

class MyState extends FlxState
{
    var bg:L2DComponent;
    var character:L2DComponent;
    
    override public function create()
    {
        super.create();
        
        // L2DManager 负责框架初始化和纹理缓存
        bg = L2DManager.create('assets/live2d/Background/', 'bg.model3.json');
        character = L2DManager.create('assets/live2d/Haru/', 'Haru.model3.json');
        
        // 添加 Sprite
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

### 播放动作和表情

```haxe
// 播放指定动作（组名、索引、优先级）
// 优先级：0=无, 1=空闲, 2=普通, 3=强制
var handle = l2d.startMotion('TapBody', 0, 3);

// 检查动作是否完成
if (l2d.model.notNull() && L2D.isMotionFinished(l2d.model, handle))
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

### 底层 API（L2D 类）

高级用法可直接使用 `L2D` 类访问全部 C API 函数：

```haxe
import live2d.cubism.L2D;
import live2d.cubism.L2DModel;

// 框架生命周期
L2D.frameworkStartUp();

// 模型生命周期
var model:L2DModel = L2D.loadModel('assets/live2d/Haru/', 'Haru.model3.json');
L2D.update(model);
L2D.releaseModel(model);

// 参数
var paramCount = L2D.getParameterCount(model);
var eyeXIndex = L2D.findParameterIndex(model, 'ParamEyeBallX');
var eyeXValue = L2D.getParameterValue(model, eyeXIndex);
L2D.setParameterValue(model, eyeXIndex, 0.5, 1.0);

// Drawable 数据
var drawCount = L2D.getDrawableCount(model);
var vertCount = L2D.getDrawableVertexCount(model, 0);
var opacity = L2D.getDrawableOpacity(model, 0);
var isVisible = L2D.isDrawableVisible(model, 0);
```

## API 参考

### L2DComponent（继承 FlxBasic）

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

### L2DManager（静态类）

| 方法 | 说明 |
| --- | --- |
| `create(dir, fileName)` | 创建模型（带纹理缓存） |
| `destroy(model)` | 销毁指定模型 |
| `destroyAll()` | 销毁所有管理的模型 |
| `updateAll(elapsed)` | 更新所有模型 |
| `renderAll()` | 渲染所有模型 |
| `clearTextureCache()` | 释放缓存的纹理 |
| `getContainer()` | 获取全局 Sprite 容器 |

## 项目配置

在你的 `Project.xml` 中：

```xml
<!-- 必需的库 -->
<haxelib name="flixel" />
<haxelib name="openfl" />
<haxelib name="live2d-haxe" />

<!-- 必须以 cpp 为目标 -->
<haxedef name="cpp" />
```

## 原生 DLL 构建配置

`native/` 目录中的 CMakeLists.txt 支持以下选项：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `CUBISM_ROOT` | `../CubismSdkForNative-5-r.5` | Cubism SDK 路径 |

自定义 SDK 路径示例：

```bash
cmake .. -DCUBISM_ROOT="D:/SDK/CubismSdkForNative-5-r.5"
```

## 已知限制

- **仅 Windows x64** — 使用 Windows 特有的 `GetProcAddress` 和 `LoadLibraryA`
- **不支持 macOS/Linux** — `@:cppFileCode` 块使用了 `<windows.h>`
- **CalcOnly 渲染** — C++ 端不做 GPU 渲染；所有绘制通过 OpenFL 的 CPU/软件三角形光栅化
- **无着色器效果** — 未实现 Cubism 的正片叠底/滤色混合
- **遮罩性能** — 每 drawable 独立 Sprite 遮罩，在大量遮罩 drawable 时可能较慢

## 许可证

本库代码以 **MIT 许可证** 发布。

**Live2D Cubism SDK** 本身受 Live2D 自身许可条款约束。你必须单独下载并同意其许可：
https://www.live2d.com/download/cubism-sdk/download-native/

## 致谢

- 基于 Live2D Inc. 的 Live2D Cubism SDK for Native
