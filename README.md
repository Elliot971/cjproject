# cjrxtui

`cjrxtui` 是一个使用仓颉（Cangjie）编写的终端 UI 第三方库，面向需要在命令行环境中构建交互式界面的项目。

它提供一套完整的 TUI 运行时：组件模型、事件系统、布局引擎、样式系统、双缓冲渲染、终端控制，以及一组可直接复用的内置组件。

当前版本信息见 `cjpm.toml`：

- 包名：`cjrxtui`
- 版本：`0.1.0`
- 编译器要求：`cjc 1.0.5`
- 输出类型：`static`
- 当前支持平台：Linux `x86_64`

## 功能概览

**核心架构**

- MVU 模式：`Component` / `State` / `Message` / `Action` / `Context`
- 声明式视图树：`Node` + `Div` 链式构建
- 布局引擎：垂直/水平方向、间距、对齐、固定/百分比/内容尺寸
- 样式系统：背景色、文本色、边框、溢出控制、绝对定位、层级
- 渲染管线：`LayoutEngine → Renderer → FramePipeline → TerminalRenderer`
- 双缓冲差分：按单元格计算 diff，仅输出变化部分

**终端控制**

- 备用屏幕、隐藏光标、Raw 模式
- 鼠标捕获（点击、滚轮、移动、拖拽）
- 终端尺寸探测（stty）与窗口 Resize 事件
- Inline 行内模式：不进入备用屏幕，在当前光标位置渲染
- 同步输出（Synchronized Output `?2026h/l`）：减少渲染撕裂

**事件系统**

- 键盘事件：字符键、方向键、功能键、Ctrl 修饰符
- 鼠标事件：点击/释放/移动/拖拽/滚轮
- Hover 追踪：自动派发 `HoverEnter` / `HoverLeave` 事件
- 全局键盘拦截：通过 `RuntimeConfig.globalKeyHandler` 注册全局快捷键
- Tab 焦点路由：支持 Tab/BackTab 在可聚焦节点间循环

**文本处理**

- 富文本（RichText）：多样式文本组合
- 文本自动换行（TextWrap）：按字符 / 按单词 / 按单词+强制断行
- 文本对齐：左/中/右

**异步效果**

- 立即消息、延迟消息、定时消息、批量效果
- 主题订阅（Topic）机制

**测试能力**

- 可脱离终端运行：`AppRuntime` 支持注入事件并断言帧输出
- `MemoryFrameSink`：捕获所有输出帧，用于单元断言

## 内置组件

共 17 个组件，均支持键盘操作与 Hover 状态追踪：

| 组件 | 状态类型 | 用途 | 事件输出 |
|------|----------|------|----------|
| `Scrollable` | `ScrollableState` | 可滚动文本区域 | — |
| `List` | `ListState` | 列表选择、滚动 | `ListItemSelected` |
| `TextInput` | `TextInputState` | 单行文本输入 | `TextInputSubmitted` |
| `Button` | `ButtonState` | 按钮 | `ButtonPressed` |
| `ProgressBar` | `ProgressBarState` | 进度条 | — |
| `Checkbox` | `CheckboxState` | 复选框 | `CheckboxChanged` |
| `Radio` | `RadioState` | 单选组 | `RadioChanged` |
| `Tabs` | `TabsState` | 标签切换 | `TabChanged` |
| `Spinner` | `SpinnerState` | 加载动画 | — |
| `Modal` | `ModalState` | 模态框 | `ModalDismissed` |
| `Form` | `FormState` | 表单容器 | — |
| `Select` | `SelectState` | 下拉选择器 | `SelectChanged` |
| `TextArea` | `TextAreaState` | 多行编辑器 | `TextAreaSubmitted` |
| `Table` | `TableState` | 表格 | `TableRowSelected` |
| `Divider` | `DividerState` | 分割线 | — |
| `StatusBar` | `StatusBarState` | 状态栏 | — |
| `Label` | `LabelState` | 静态文本 | — |

## 安装

### 本地 path 依赖

```toml
[dependencies]
  cjrxtui = { path = "../cjrxtui" }
```

### Git 仓库依赖

```toml
[dependencies]
  cjrxtui = { git = "https://github.com/Elliot971/cjproject.git", tag = "v0.1.0" }
```

## 快速开始

```bash
source path/to/cangjie/envsetup.sh
cd cjrxtui
cjpm build
cjpm test --parallel 1
```

### 最小示例：交互式计数器

```cangjie
import cjrxtui.*

class CounterState <: State {
    public var count: Int64 = 0
    public init() {}
}

class Counter <: Component {
    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let s = (state as CounterState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Key(keyEvent) =>
                    match (keyEvent.code) {
                        case KeyCode.Up => s.count += 1
                        case KeyCode.Down => s.count -= 1
                        case KeyCode.Esc => return Action.exit()
                        case _ => ()
                    }
                case _ => ()
            }
        }
        Action.update(s)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let s = (state as CounterState).getOrThrow()
        Node.div(
            Div()
                .width(Dimension.Fixed(24))
                .height(Dimension.Fixed(4))
                .style(Style().withBorder(Border(BorderStyle.Rounded, Color.BrightCyan)).withPadding(Spacing.all(1)))
                .child(Node.text("Count: ${s.count}", TextStyle().withForeground(Color.BrightWhite).withBold(true)))
                .child(Node.text("Up/Down +/-, Esc exit", TextStyle().withForeground(Color.BrightBlack)))
        )
    }
}

main() {
    App.runInteractive(Counter(), CounterState())
}
```

## 核心设计

### 架构层次

```
component/   组件协议、消息、Action、Effect、Context
node/        声明式视图树
style/       布局和文本样式模型
layout/      视图树 → 布局盒模型
render/      布局结果 → 屏幕缓冲区
buffer/      双缓冲差分计算
terminal/    ANSI 输出、Raw 模式与终端控制
```

### 组件模型

```cangjie
interface Component {
    func update(ctx: Context, msg: Message, state: State): Action
    func view(ctx: Context, state: State): Node
}
```

### Action

```cangjie
Action.update(state)           // 更新状态
Action.none()                  // 无操作
Action.exit()                  // 退出应用
Action.command(message)        // 发送消息
Action.effect(effect)          // 触发异步效果
Action.batch(actions)          // 批量组合
Action.updateTopic(topic, state)
Action.commandTopic(topic, message)
```

### Context

```cangjie
ctx.send(message)              // 发送消息
ctx.sendToTopic(topic, message)// 主题消息
ctx.focus(nodeId)              // 请求焦点
ctx.isFirstRender()            // 是否首次渲染
```

### Effects

```cangjie
Effects.send(message)
Effects.delay(delayMillis, message)
Effects.interval(intervalMillis, repeatCount, message)
Effects.batch(effects)
```

### 事件类型

```cangjie
UiEvent.Key(KeyEvent)          // 键盘
UiEvent.Mouse(MouseEvent)      // 鼠标
UiEvent.Click(String, MouseEvent) // 节点点击
UiEvent.Resize(ResizeEvent)    // 窗口尺寸变化
UiEvent.Focus(String)          // 焦点获得
UiEvent.Blur(String)           // 焦点失去
UiEvent.HoverEnter(String)     // 鼠标进入节点
UiEvent.HoverLeave(String)     // 鼠标离开节点
UiEvent.Tick                   // 定时心跳
```

### 节点树构建

```cangjie
Node.div(div)                  // 容器节点
Node.text("hello")             // 文本节点
Node.text("hello", textStyle)  // 带样式文本
Node.richText(richText)        // 富文本
Node.when(condition, node)     // 条件渲染
Node.list(nodes)               // 节点列表
Node.hstack(nodes) / .vstack(nodes) // 水平/垂直堆叠
Node.spacer(width, height)     // 占位
```

### Div 链式构建

```cangjie
Div()
    .child(node)
    .children(nodes)
    .style(style)
    .direction(Direction.Vertical)
    .width(Dimension.Fixed(40))
    .height(Dimension.Percentage(50))
    .padding(Spacing.all(1))
    .gap(1)
    .alignItems(Alignment.Center)
    .justifyContent(JustifyContent.SpaceBetween)
    .focusable()
    .id("my-node")
```

### 样式

**容器样式 `Style`**：

```cangjie
Style()
    .withBackground(Color.Black)
    .withBorder(Border(BorderStyle.Rounded, Color.Cyan))
    .withPadding(Spacing.all(1))
    .withMargin(Spacing.symmetric(2, 1))
    .withOverflow(Overflow.Hidden)
    .withPosition(Position.Absolute)
    .withZIndex(10)
```

**文本样式 `TextStyle`**：

```cangjie
TextStyle()
    .withForeground(Color.BrightWhite)
    .withBackground(Color.Blue)
    .withBold(true)
    .withUnderline(true)
    .withWrap(TextWrap.Word)     // 文本自动换行
```

**主要类型**：

- `Color`：基础 16 色 + `Rgb(UInt8, UInt8, UInt8)`
- `BorderStyle`：`None` / `Single` / `Double` / `Rounded` / `Thick`
- `Dimension`：`Fixed` / `Percentage` / `Auto` / `Content`
- `TextWrap`：`NoWrap` / `Character` / `Word` / `WordBreak`
- `TextAlign`：`Left` / `Center` / `Right`
- `Overflow`：`Visible` / `Hidden` / `Scroll` / `Auto`

## 运行时 API

### App 入口

```cangjie
App.runInteractive(root, state)                // 全屏交互运行
App.runInteractive(root, state, width, height) // 指定尺寸
App.runInline(root, state, width, height)      // 行内模式运行
App.createRuntime(root, state, config)         // 创建可编程运行时
App.createRunner()                             // 创建 Runner
```

### RuntimeConfig

```cangjie
RuntimeConfig()                                          // 默认 80×24
RuntimeConfig(width, height, clearScreenOnStart)         // 基础配置
RuntimeConfig(width, height, clear, mouseCapture)        // 启用鼠标
RuntimeConfig(w, h, clear, mouse, globalKeyHandler)      // 全局按键

// 全局键盘拦截示例
RuntimeConfig(80, 24, true, true, { key: KeyEvent =>
    match (key.code) {
        case KeyCode.Char(ch) =>
            if (ch == r'q') { return Some(Action.exit()) }
            None
        case _ => None
    }
})

RuntimeConfig.inline(width, height)                      // Inline 模式工厂方法
```

### AppRuntime（可测试接口）

```cangjie
runtime.bootFrame()            // 初始帧
runtime.step(message)          // 注入消息
runtime.stepKey("up")          // 注入按键
runtime.tick()                 // 发送 Tick
runtime.dispatch(event)        // 注入运行时事件
runtime.runLoop(events)        // 批量事件
runtime.resize(width, height)  // 触发尺寸变化
runtime.currentState()         // 读取状态
runtime.flushAsync()           // 刷新异步队列
```

## 文本自动换行

通过 `TextStyle.withWrap(mode)` 启用文本自动换行，布局引擎会根据可用宽度自动插入换行：

```cangjie
// 按字符强制换行
Node.text("abcdefghij", TextStyle().withWrap(TextWrap.Character))

// 按单词换行（在空格处断行）
Node.text("The quick brown fox jumps", TextStyle().withWrap(TextWrap.Word))

// 按单词换行 + 长单词强制断行
Node.text("Superlongword here", TextStyle().withWrap(TextWrap.WordBreak))
```

| 模式 | 行为 |
|------|------|
| `NoWrap` | 默认，不自动换行 |
| `Character` | 到达宽度边界时按字符强制换行 |
| `Word` | 在空格处断行，保持单词完整 |
| `WordBreak` | 优先空格断行，超长单词强制断行 |

## 全局键盘事件

通过 `RuntimeConfig` 注册全局键盘拦截器，优先于所有组件处理按键：

```cangjie
let config = RuntimeConfig(80, 24, true, true, { key: KeyEvent =>
    match (key.code) {
        case KeyCode.Char(ch) =>
            if (ch == r'q') { return Some(Action.exit()) }   // 全局 q 退出
            None
        case _ => None
    }
})

let runtime = App.createRuntime(MyComponent(), MyState(), config)
```

- 返回 `Some(action)` → 拦截按键，执行 action，不再传递给组件
- 返回 `None` → 不拦截，按键继续正常路由到聚焦组件

## Inline 终端模式

在不进入备用屏幕的情况下，在当前光标位置渲染 TUI：

```cangjie
// 方式 1: 便捷方法
App.runInline(MyComponent(), MyState(), 40, 10)

// 方式 2: 手动配置
let config = RuntimeConfig.inline(40, 10)
let runtime = App.createRuntime(MyComponent(), MyState(), config)
```

Inline 模式特点：
- 不切换备用屏幕，渲染完成后内容保留在终端历史中
- 启动时预留 N 行空间，光标上移到起始位置
- 退出时光标移至渲染区域下方，恢复正常终端状态
- 适合：命令行工具中嵌入交互式选择、进度指示等短期 TUI

## 同步输出优化

渲染管线自动采用以下优化策略：

- **Run 合并**：连续相同样式的单元格合并为单次 Print 输出，减少 ANSI 指令数量
- **同步输出包裹**：非空帧自动包裹 `?2026h` / `?2026l` 序列，终端支持时可消除渲染撕裂
- **差分渲染**：双缓冲逐单元格比较，仅输出发生变化的区域

这些优化对用户透明，无需额外配置。

## 内置组件速览

### Scrollable / List / TextInput

```cangjie
Scrollable(lines, width, height, id)   // Up/Down/PageUp/PageDown/Home/End/滚轮
List(items, width, height, id)         // 键盘上下/回车选中/鼠标点击
TextInput(width, id, placeholder)      // 单行编辑/退格/删除/左右移动/回车提交
```

### Button / Checkbox / Radio

```cangjie
Button(label, width, id)              // 回车/空格/点击触发
Checkbox(label, width, id)            // 空格切换/点击切换
Radio(options, width, id)             // 上下选择
```

### Select / Tabs / Spinner

```cangjie
Select(options, width, id)            // 回车展开/上下选择/回车确认
Tabs(labels, width, id)               // 左右切换标签
Spinner(label, width, id)             // 响应 Tick 播放动画
Spinner(label, width, id, SpinnerType.Dots) // 自定义动画类型
```

### Table / TextArea / Modal

```cangjie
Table(headers, rows, colWidths, width, height, id)  // 表头/选中行高亮/分页
TextArea(width, height, id)           // 多行编辑/方向键/Ctrl+Enter 提交
Modal(title, bodyLines, width, height, id)           // 模态框
```

### Form / StatusBar / Divider / Label / ProgressBar

```cangjie
Form(title, width, id, fields)        // Tab 切换字段焦点
StatusBar(width, id)                  // 底部状态栏
Divider(length, dir, label, color)    // 横向/纵向分割线
Label(text, width)                    // 静态文本
ProgressBar(width, maxValue, id)      // 进度条
```

## BuiltinEvent 列表

内置组件通过 `BuiltinEvent` 向父级冒泡业务事件：

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

## 非交互测试

```cangjie
let runtime = App.createRuntime(MyComponent(), MyState(), RuntimeConfig(20, 1, false, false))
let boot = runtime.bootFrame()
let step = runtime.step(UiEvent.Key(KeyEvent(KeyCode.Enter)))

// boot.frame / step.frame 包含 ANSI 输出，可用 contains 断言
// runtime.currentState() 可读取和断言内部状态
```

## 项目结构

```
src/
├── lib.cj                    # 公共导出
├── app/
│   ├── app.cj                # App 入口、工厂方法
│   ├── events.cj             # 输入解析（ANSI 序列/鼠标协议）
│   ├── runner.cj             # AppRunner、事件源、帧输出
│   └── runtime.cj            # RuntimeConfig、AppRuntime 核心
├── buffer/
│   └── buffer.cj             # Cell、ScreenBuffer、DoubleBuffer
├── builtin/
│   ├── components.cj         # 大部分内置组件实现
│   ├── divider.cj / select.cj / statusbar.cj / table.cj / textarea.cj
├── component/
│   ├── component.cj          # Component/Action/Effect 协议
│   ├── context.cj            # Context 类
│   └── events.cj             # UiEvent/KeyEvent/MouseEvent 定义
├── layout/
│   └── layout.cj             # LayoutEngine、文本换行
├── node/
│   └── node.cj               # Node/Div/RichText 定义
├── render/
│   └── renderer.cj           # Renderer、FramePipeline
├── style/
│   └── style.cj              # Style/TextStyle/TextWrap/Color 等
└── terminal/
    └── terminal.cj           # TerminalRenderer、ANSI 输出、Run 合并
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

## 许可证

MIT，见 `LICENSE`。
