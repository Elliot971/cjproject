# cjrxtui

`cjrxtui` 是一个使用仓颉（Cangjie）编写的终端 UI 第三方库，面向需要在命令行环境中构建交互式界面的项目。

它提供一套完整的 TUI 运行时：组件模型、事件系统、布局引擎、样式系统、双缓冲渲染、终端控制，以及一组可直接复用的内置组件。

当前版本信息见 `cjpm.toml`：

- 包名：`cjrxtui`
- 版本：`0.1.0`
- 编译器要求：`cjc 1.0.5`
- 输出类型：`static`
- 当前支持平台：Linux `x86_64`

## 这个库能做什么

`cjrxtui` 适合以下场景：

- 命令行管理工具的交互式面板
- 终端表单、列表、选择器、状态栏
- 带键盘和鼠标操作的 TUI 应用
- 可测试、可组合的 MVU 风格终端界面
- 需要脱离真实终端做运行时验证和渲染验证的库/应用

核心能力包括：

- MVU 架构：`Component`、`State`、`Message`、`Action`、`Context`
- 布局系统：垂直/水平布局、间距、边距、对齐、固定尺寸、百分比尺寸、内容尺寸
- 样式系统：背景色、文本色、边框、文本样式、定位、层级、溢出控制
- 渲染系统：`LayoutEngine -> Renderer -> FramePipeline -> TerminalRenderer`
- 双缓冲差分刷新：减少闪烁，按单元格输出 ANSI 更新
- 终端控制：备用屏幕、隐藏光标、Raw 模式、鼠标捕获、终端尺寸探测
- 输入系统：键盘、鼠标、窗口尺寸变化、Tick 事件
- 焦点路由：支持键盘焦点和鼠标点击选中焦点节点
- 异步效果：立即消息、延迟消息、定时消息、批量效果
- 非交互测试能力：可直接对 `AppRuntime` 注入事件并断言帧输出

## 内置组件

当前公开导出的内置组件共 17 个：

| 组件 | 状态类型 | 主要用途 | 典型事件输出 |
|------|----------|----------|--------------|
| `Scrollable` | `ScrollableState` | 可滚动文本区域 | 无 |
| `List` | `ListState` | 列表选择、滚动、点击选中 | `BuiltinEvent.ListItemSelected` |
| `TextInput` | `TextInputState` | 单行文本输入 | `BuiltinEvent.TextInputSubmitted` |
| `Label` | `LabelState` | 静态文本显示 | 无 |
| `Button` | `ButtonState` | 可点击按钮 | `BuiltinEvent.ButtonPressed` |
| `ProgressBar` | `ProgressBarState` | 进度显示 | 无 |
| `Checkbox` | `CheckboxState` | 复选框 | `BuiltinEvent.CheckboxChanged` |
| `Radio` | `RadioState` | 单选组 | `BuiltinEvent.RadioChanged` |
| `Tabs` | `TabsState` | 标签切换 | `BuiltinEvent.TabChanged` |
| `Spinner` | `SpinnerState` | 加载动画 | 无 |
| `Modal` | `ModalState` | 模态框 | `BuiltinEvent.ModalDismissed` |
| `Form` | `FormState` | 表单容器与 Tab 焦点管理 | 无 |
| `Select` | `SelectState` | 下拉选择器 | `BuiltinEvent.SelectChanged` |
| `TextArea` | `TextAreaState` | 多行文本输入 | `BuiltinEvent.TextAreaSubmitted` |
| `Table` | `TableState` | 表格选择与滚动 | `BuiltinEvent.TableRowSelected` |
| `Divider` | `DividerState` | 横向/纵向分割线 | 无 |
| `StatusBar` | `StatusBarState` | 状态栏显示 | 无 |

## 安装

### 本地 path 依赖

开发阶段最推荐先使用本地依赖验证：

```toml
[dependencies]
  cjrxtui = { path = "../cjrxtui" }
```

### Git 仓库依赖

仓库地址：

`https://github.com/Elliot971/cjproject.git`

当仓库发布正式标签后，可以在你的 `cjpm.toml` 中使用 git 依赖，例如：

```toml
[dependencies]
  cjrxtui = { git = "https://github.com/Elliot971/cjproject.git", tag = "v0.1.0" }
```

如果当前尚未创建对应 tag，建议先用 path 依赖完成接入验证。

## 快速开始

### 构建库

```bash
source path/to/cangjie/envsetup.sh
cd cjrxtui
cjpm build
```

### 运行测试

```bash
cjpm test --parallel 1
```

### 最小可运行示例

下面这个示例展示了一个最简单的交互式计数器：

```cangjie
import cjrxtui.*

class CounterState <: State {
    public var count: Int64

    public init() {
        count = 0
    }
}

class Counter <: Component {
    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let counter = (state as CounterState).getOrThrow()

        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Key(keyEvent) =>
                    match (keyEvent.code) {
                        case KeyCode.Up => counter.count += 1
                        case KeyCode.Down => counter.count -= 1
                        case KeyCode.Esc => return Action.exit()
                        case _ => ()
                    }
                case _ => ()
            }
        }

        Action.update(counter)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let counter = (state as CounterState).getOrThrow()

        Node.div(
            Div()
                .width(Dimension.Fixed(24))
                .height(Dimension.Fixed(4))
                .style(
                    Style()
                        .withBorder(Border(BorderStyle.Rounded, Color.BrightCyan))
                        .withPadding(Spacing.all(1))
                        .withBackground(Color.Black)
                )
                .child(Node.text("Count: ${counter.count}", Some(TextStyle().withForeground(Color.BrightWhite).withBold(true))))
                .child(Node.text("Up/Down +/-, Esc exit", Some(TextStyle().withForeground(Color.BrightBlack))))
        )
    }
}

main() {
    App.runInteractive(Counter(), CounterState(), 24, 4)
}
```

运行效果验证：

- 程序启动后能进入交互式终端界面
- `Up` / `Down` 键能修改计数值
- 终端界面刷新正常，没有明显闪烁或残影
- `Esc` 能正常退出并恢复终端状态

满足这些条件，说明这个库最基本的运行时、事件和渲染链路是有效的。

## 第三方库接入后，怎样算验证成功

对于一个 TUI 第三方库，通常至少验证这 4 层：

### 1. 编译验证

- `cjpm build` 成功
- 依赖方项目在引入 `cjrxtui` 后能成功编译

### 2. 运行验证

- 可以正常进入交互界面
- 键盘事件有响应
- 退出后终端模式恢复正常

### 3. 组件验证

- 至少有一个内置组件能正确显示
- 至少有一个交互组件能正确产生状态变化或事件输出

### 4. 测试验证

- 仓库内单元测试通过
- 依赖方项目可通过 `AppRuntime` 进行可重复测试

如果你在业务项目里完成了以下动作，基本就可以判定 `cjrxtui` 是可用的：

- 成功引入 `cjrxtui`
- 成功渲染出一个界面
- 能响应 `UiEvent.Key(...)`
- 能正确退出并恢复终端

## 核心设计

`cjrxtui` 的主体由 7 个层次组成：

1. `component/`：组件协议、消息协议、Action、Effect、Context
2. `node/`：声明式视图树定义
3. `style/`：布局和文本样式模型
4. `layout/`：将视图树转换为布局盒模型
5. `render/`：将布局结果写入屏幕缓冲区
6. `buffer/`：双缓冲差分计算
7. `terminal/`：ANSI 输出、Raw 模式与终端能力封装

这一结构使它既能做真实终端交互，也能在测试里直接验证中间结果。

## 核心 API 详解

### 组件模型

所有业务组件都实现 `Component`：

```cangjie
interface Component {
    func update(ctx: Context, msg: Message, state: State): Action
    func view(ctx: Context, state: State): Node
}
```

相关基础类型：

- `Message`：消息基接口
- `State`：状态基接口
- `Context`：组件上下文，负责发送消息、请求焦点等
- `Action`：`update` 的返回值，用于驱动运行时行为

### Action

`Action` 是运行时理解组件意图的核心类型，当前支持：

```cangjie
Action.update(state)
Action.updateTopic(topic, state)
Action.none()
Action.command(message)
Action.commandTopic(topic, message)
Action.effect(effect)
Action.batch(actions)
Action.exit()
```

常见使用方式：

- `Action.update(state)`：返回更新后的状态
- `Action.none()`：不做任何额外动作
- `Action.effect(...)`：触发异步效果
- `Action.batch([...])`：批量组合多个动作
- `Action.exit()`：退出应用

### Context

`Context` 公开提供：

- `ctx.send(message)`：向当前运行时发送消息
- `ctx.sendToTopic(topic, message)`：发送主题消息
- `ctx.focus(nodeId)`：请求将焦点切到指定节点
- `ctx.isFirstRender()`：判断当前是否为首次渲染

### Effects

异步效果由 `Effects` 工厂提供：

```cangjie
Effects.send(message)
Effects.sendToTopic(topic, message)
Effects.delay(delayMillis, message)
Effects.delayToTopic(delayMillis, topic, message)
Effects.interval(intervalMillis, repeatCount, message)
Effects.batch(effects)
```

适合这些场景：

- 定时刷新 spinner
- 延迟关闭提示框
- 异步触发后续业务消息
- 将多个副作用打包执行

### 事件系统

终端交互最终会归一化为 `UiEvent`：

```cangjie
UiEvent.Tick
UiEvent.Exit
UiEvent.Key(KeyEvent)
UiEvent.Mouse(MouseEvent)
UiEvent.Click(String, MouseEvent)
UiEvent.Resize(ResizeEvent)
UiEvent.Focus(String)
UiEvent.Blur(String)
```

键盘类型 `KeyCode` 支持：

- 字符键：`KeyCode.Char(...)`
- 命名键：`Up`、`Down`、`Left`、`Right`
- 控制键：`Enter`、`Esc`、`Tab`、`BackTab`、`Backspace`
- 导航键：`Home`、`End`、`PageUp`、`PageDown`
- 编辑键：`Insert`、`Delete`
- 功能键：`Function(Int64)`
- 扩展命名键：`Named(String)`

鼠标类型 `MouseEventKind` 支持：

- `Down(MouseButton)`
- `Up(MouseButton)`
- `Move`
- `Drag(MouseButton)`
- `ScrollUp`
- `ScrollDown`

### 声明式节点树

界面通过 `Node` 和 `Div` 组合：

```cangjie
Node.div(div)
Node.text("hello")
Node.text("hello", Some(textStyle))
Node.richText(richText)
Node.when(condition, node)
Node.list(nodes)
Node.hstack(nodes)
Node.vstack(nodes)
Node.spacer(width, height)
```

`Div` 提供链式构建能力：

```cangjie
Div()
    .child(node)
    .children(nodes)
    .style(style)
    .direction(Direction.Vertical)
    .padding(Spacing.all(1))
    .gap(1)
    .margin(Spacing.symmetric(2, 1))
    .alignItems(Alignment.Center)
    .justifyContent(JustifyContent.SpaceBetween)
    .alignSelf(AlignSelf.Center)
    .width(Dimension.Fixed(40))
    .height(Dimension.Fixed(10))
    .focusable()
    .id("root")
```

### 布局与样式

样式层分为容器样式 `Style` 和文本样式 `TextStyle`。

常用容器能力：

- `Style().withBackground(color)`
- `Style().withDirection(direction)`
- `Style().withPadding(spacing)`
- `Style().withMargin(spacing)`
- `Style().withWidth(dimension)`
- `Style().withHeight(dimension)`
- `Style().withGap(value)`
- `Style().withOverflow(overflow)`
- `Style().withBorder(border)`
- `Style().withPosition(position)`
- `Style().withTop(...) / withRight(...) / withBottom(...) / withLeft(...)`
- `Style().withZIndex(...)`
- `Style().withAlignItems(...)`
- `Style().withJustifyContent(...)`
- `Style().withAlignSelf(...)`

常用文本能力：

- `TextStyle().withForeground(color)`
- `TextStyle().withBackground(color)`
- `TextStyle().withBold(true)`
- `TextStyle().withUnderline(true)`

主要样式类型：

- `Color`：基础 16 色 + `Rgb(UInt8, UInt8, UInt8)`
- `BorderStyle`：`None`、`Single`、`Double`、`Rounded`、`Thick`
- `BorderEdges`：支持全边/水平/垂直/自定义边框
- `Spacing`：`zero`、`all`、`symmetric`
- `Dimension`：`Fixed`、`Percentage`、`Auto`、`Content`
- `Direction`：垂直/水平
- `Overflow`：`Visible`、`Hidden`、`Scroll`、`Auto`
- `Position`：`Relative`、`Absolute`
- `SpinnerType`：`Line`、`Dots`、`Circle`、`Arrow`、`Bounce`、`Hearts`、`Custom`

### App 与运行时 API

`App` 是最常用入口：

```cangjie
App.createSession(root, initialState)
App.createRuntime(root, initialState)
App.createRuntime(root, initialState, config)
App.createRunner()
App.createInteractiveRunner()
App.runInteractive(root, initialState)
App.runInteractive(root, initialState, width, height)
App.runInline(root, initialState, width, height)
```

其中最常见的是：

- `App.runInteractive(...)`：进入备用屏幕并接管终端输入
- `App.runInline(...)`：行内运行，不清空备用屏幕
- `App.createRuntime(...)`：更适合测试、脚本驱动和自定义事件源

运行时配置：

```cangjie
RuntimeConfig(width, height, clearScreenOnStart, mouseCapture)
```

`AppRuntime` 提供可测试接口：

- `bootFrame()`：返回初始帧
- `step(message)`：推进一步消息处理
- `stepKey(name)`：按名字注入按键，如 `"up"`
- `tick()`：发送 Tick
- `dispatch(event)` / `runOnce(event)`：注入运行时事件
- `runLoop(events)`：批量执行事件序列
- `resize(width, height)`：触发尺寸变化
- `currentState()`：读取当前状态
- `snapshot()`：读取运行时快照
- `flushAsync()`：刷新异步消息队列

### 运行时事件源与终端 API

库同时导出了这些更底层能力：

- 事件源：`RuntimeEventSource`、`PollingRuntimeEventSource`
- 内置事件源：`ArrayRuntimeEventSource`、`StdinRuntimeEventSource`、`RawStdinRuntimeEventSource`、`RawStringRuntimeEventSource`、`InteractiveRuntimeEventSource`
- 帧输出：`FrameSink`、`StdoutFrameSink`、`MemoryFrameSink`
- 终端尺寸：`TerminalSize`、`TerminalSizeReader`、`SttyTerminalSizeReader`、`NoopTerminalSizeReader`
- 输入模式：`TerminalModeController`、`SttyTerminalModeController`、`NoopTerminalModeController`
- ANSI 渲染：`TerminalRenderer`

如果你需要自己解析原始输入，也可以直接使用：

```cangjie
parseInputLine(...)
parseRawInput(...)
normalizeKeyName(...)
normalizeRuntimeEvent(...)
forceFlushEsc(...)
```

## 内置组件 API 速览

下面列出每个组件最常用的构造方式和交互行为。

### Scrollable

```cangjie
Scrollable(lines, width, height)
Scrollable(lines, width, height, id)
```

- 状态：`ScrollableState(offset, focused)`
- 支持 `Up` / `Down` / `PageUp` / `PageDown` / `Home` / `End`
- 支持鼠标滚轮滚动

### List

```cangjie
List(items, width, height)
List(items, width, height, id)
```

- 状态：`ListState(selectedIndex, scrollOffset, focused)`
- 支持键盘上下移动、滚轮滚动、点击选中
- 触发：`BuiltinEvent.ListItemSelected(id, index, text)`

### TextInput

```cangjie
TextInput(width)
TextInput(width, id, placeholder)
```

- 状态：`TextInputState(value, cursor, focused, viewOffset)`
- 支持单行编辑、左右移动、退格、删除、回车提交
- 触发：`BuiltinEvent.TextInputSubmitted(id, value)`

### Button

```cangjie
Button(label, width, id)
```

- 状态：`ButtonState(focused, pressed)`
- 支持回车触发和点击触发
- 触发：`BuiltinEvent.ButtonPressed(id, label)`

### Checkbox

```cangjie
Checkbox(label, width, id)
```

- 状态：`CheckboxState(checked, focused)`
- 支持键盘和点击切换
- 触发：`BuiltinEvent.CheckboxChanged(id, checked)`

### Radio

```cangjie
Radio(options, width, id)
```

- 状态：`RadioState(selectedIndex, focused)`
- 支持单选切换
- 触发：`BuiltinEvent.RadioChanged(id, index, option)`

### Tabs

```cangjie
Tabs(labels, width, id)
```

- 状态：`TabsState(selectedIndex, focused)`
- 支持左右或上下切换标签
- 触发：`BuiltinEvent.TabChanged(id, index, label)`

### Spinner

```cangjie
Spinner(label, width, id)
Spinner(label, width, id, spinnerType)
```

- 状态：`SpinnerState(frameIndex)`
- 响应 `UiEvent.Tick`
- 用于加载提示、轮询反馈和状态等待

### Modal

```cangjie
Modal(title, bodyLines, width, height, id)
```

- 状态：`ModalState(open, focused)`
- 支持关闭行为
- 触发：`BuiltinEvent.ModalDismissed(id)`

### ProgressBar

```cangjie
ProgressBar(width, maxValue, id)
```

- 状态：`ProgressBarState(value)`
- 自动将 `value` 约束在 `[0, maxValue]`

### Form

```cangjie
Form(title, width, id, fields)
```

- 状态：`FormState(activeField)`
- `fields` 类型：`Array<(String, Component)>`
- 支持 `Tab` 在字段间切换焦点

### Select

```cangjie
Select(options, width, id)
Select(options, width, maxVisibleItems, id)
```

- 状态：`SelectState(selectedIndex)` 或默认构造状态
- 支持展开、收起、上下高亮、回车确认
- 触发：`BuiltinEvent.SelectChanged(id, index, option)`

### TextArea

```cangjie
TextArea(width, height, id)
```

- 状态：`TextAreaState()` 或 `TextAreaState(text)`
- 支持多行编辑、换行、删除、方向键移动、滚动保持可见
- `Ctrl + Enter` 提交
- 触发：`BuiltinEvent.TextAreaSubmitted(id, text)`

### Table

```cangjie
Table(headers, rows, columnWidths, width, height, id)
```

- 状态：`TableState(selectedRow, scrollOffset, focused)`
- 支持表头、分隔线、选中行高亮、滚轮和分页导航
- 触发：`BuiltinEvent.TableRowSelected(id, rowIndex)`

### Divider

```cangjie
Divider(length)
Divider(length, dir)
Divider(length, dir, label)
Divider(length, dir, label, color)
```

- 状态：`DividerState`
- 支持横向与纵向分割线

### StatusBar

```cangjie
StatusBar(width, id)
StatusBar(width, id, background, foreground)
```

- 状态：`StatusBarState(sections)`
- 用于底部提示、状态摘要、快捷键提示

### Label

```cangjie
Label(text, width)
```

- 状态：`LabelState`
- 用于静态文本或辅助说明

## BuiltinEvent 列表

如果你的根组件要接收内置组件发出的业务事件，可以在 `update` 里匹配这些消息：

```cangjie
BuiltinEvent.ListItemSelected(id, index, text)
BuiltinEvent.TextInputSubmitted(id, value)
BuiltinEvent.ButtonPressed(id, label)
BuiltinEvent.CheckboxChanged(id, checked)
BuiltinEvent.RadioChanged(id, index, option)
BuiltinEvent.TabChanged(id, index, label)
BuiltinEvent.ModalDismissed(id)
BuiltinEvent.TableRowSelected(id, rowIndex)
BuiltinEvent.TextAreaSubmitted(id, text)
BuiltinEvent.SelectChanged(id, index, option)
```

## 非交互测试示例

如果你想把它作为第三方库集成到 CI 或测试项目中，推荐直接用 `AppRuntime`：

```cangjie
import cjrxtui.*

class TestState <: State {
    public var count: Int64

    public init() {
        count = 0
    }
}

class TestComponent <: Component {
    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let s = (state as TestState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Key(keyEvent) =>
                    match (keyEvent.code) {
                        case KeyCode.Enter => s.count += 1
                        case _ => ()
                    }
                case _ => ()
            }
        }
        Action.update(s)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let s = (state as TestState).getOrThrow()
        Node.text("count=${s.count}")
    }
}

main() {
    let runtime = App.createRuntime(TestComponent(), TestState(), RuntimeConfig(20, 1, false, false))
    let boot = runtime.bootFrame()
    let step = runtime.step(UiEvent.Key(KeyEvent(KeyCode.Enter)))

    println(boot.frame)
    println(step.frame)
}
```

验证标准：

- 初始帧能正常生成
- 注入 `Enter` 后第二帧内容发生变化
- `runtime.currentState()` 中状态已更新

这说明库不仅能运行，还具备第三方库应该具备的可测试性。

## 项目结构

```text
src/
├── lib.cj
├── app/
│   ├── app.cj
│   ├── events.cj
│   ├── runner.cj
│   └── runtime.cj
├── buffer/
│   └── buffer.cj
├── builtin/
│   ├── components.cj
│   ├── divider.cj
│   ├── select.cj
│   ├── statusbar.cj
│   ├── table.cj
│   └── textarea.cj
├── component/
│   ├── component.cj
│   ├── context.cj
│   └── events.cj
├── layout/
│   └── layout.cj
├── node/
│   └── node.cj
├── render/
│   └── renderer.cj
├── style/
│   └── style.cj
└── terminal/
    └── terminal.cj
```

## 对外公开模块

通过 `src/lib.cj`，库已经统一导出以下模块能力：

- `cjrxtui.app`
- `cjrxtui.builtin`
- `cjrxtui.buffer`
- `cjrxtui.component`
- `cjrxtui.layout`
- `cjrxtui.node`
- `cjrxtui.render`
- `cjrxtui.style`
- `cjrxtui.terminal`

这意味着业务项目通常只需要：

```cangjie
import cjrxtui.*
```

## 发布建议

为了让这个仓库更符合第三方库发布习惯，建议每次发布前至少确认：

- README 中的依赖方式与 API 示例可以实际运行
- `cjpm build` 成功
- `cjpm test --parallel 1` 成功
- 新建一个独立项目用 path 依赖接入成功
- 至少验证一次交互式运行和一次非交互测试运行
- 创建语义化标签，例如 `v0.1.0`

## 协作与提交建议

- 分支建议：`feat/<name>`、`fix/<name>`、`docs/<name>`
- 提交前缀建议：`feat:`、`fix:`、`docs:`、`test:`、`refactor:`、`chore:`
- 一次提交只做一类改动，便于回溯和发布
- 公开 API 变更建议在 README 和后续 `CHANGELOG` 中同步说明

## 路线图

- [ ] 更完善的示例工程与接入模板
- [ ] 更丰富的布局能力
- [ ] 更完整的主题系统
- [ ] 更多内置复合组件
- [ ] 发布标签与版本升级说明

## 许可证

MIT，见 `LICENSE`。
