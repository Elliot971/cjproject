# cjrxtui

仓颉语言响应式终端 UI 框架。

`cjrxtui` 是一个用仓颉（Cangjie）编写的 TUI 库，提供组件化、响应式的终端界面开发体验。基于 MVU（Model-View-Update）架构，内置 12 个常用组件，开箱即用。

## 功能特性

- **MVU 架构**：`Component`、`State`、`Message`、`Action`、`Context` 完整的组件运行时
- **终端集成**：备用屏幕、Raw 模式、鼠标捕获、终端尺寸变化检测
- **输入处理**：键盘事件、鼠标事件（点击 / 滚轮）、焦点路由、点击路由
- **渲染流水线**：`LayoutEngine → Renderer → DoubleBuffer → TerminalRenderer`，差分刷新减少闪烁
- **样式系统**：前景 / 背景颜色、边框、文字样式（粗体 / 斜体 / 下划线）、间距、固定 / 百分比尺寸
- **异步效果**：`Effects.delay`、`Effects.interval` 支持定时器和延迟回调
- **12 个内置组件**：

| 组件 | 说明 |
|------|------|
| `Scrollable` | 可滚动区域 |
| `List` | 可选列表（键盘 / 鼠标导航） |
| `TextInput` | 文本输入框（光标 / 选择 / 粘贴） |
| `Label` | 文本标签 |
| `Button` | 按钮（点击 / Enter 触发） |
| `ProgressBar` | 进度条 |
| `Checkbox` | 复选框 |
| `Radio` | 单选组 |
| `Tabs` | 标签页 |
| `Spinner` | 加载动画（多种样式） |
| `Modal` | 模态对话框 |
| `Form` | 表单容器（自动焦点管理） |

## 安装

### 作为 cjpm 依赖引入

在你的项目 `cjpm.toml` 中添加：

```toml
[dependencies]
  cjrxtui = { path = "../cjrxtui" }
```

或通过 Git 仓库引入：

```toml
[dependencies]
  cjrxtui = { git = "https://github.com/Elliot971/cjproject.git", tag = "v0.1.0" }
```

然后在代码中直接 `import cjrxtui.*` 即可使用所有公共 API。

### 环境要求

- 仓颉编译器 **1.0.4+**
- Linux x86_64（当前支持平台）

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

### 运行示例

先构建库，然后编译并运行示例：

```bash
# 编译计数器示例
cjc examples/counter.cj \
  --import-path target/release/cjrxtui \
  -L target/release/cjrxtui \
  -l cjrxtui -l cjrxtui.app -l cjrxtui.component \
  -l cjrxtui.node -l cjrxtui.style -l cjrxtui.layout \
  -l cjrxtui.render -l cjrxtui.buffer -l cjrxtui.terminal \
  -l cjrxtui.builtin \
  -o target/release/bin/counter_example

# 运行
./target/release/bin/counter_example
```

提供的示例：

| 示例 | 说明 |
|------|------|
| `counter.cj` | 入门：最简交互计数器 |
| `builtin_list.cj` | 单组件：List 可选列表 |
| `builtin_scrollable.cj` | 单组件：Scrollable 滚动区域 |
| `builtin_text_input.cj` | 单组件：TextInput 文本输入 |
| `form_demo.cj` | 进阶：表单交互（多 TextInput + Button） |
| `demo.cj` | 旗舰：全部 12 个组件综合演示 |

## 最小示例

```cangjie
import cjrxtui.*

class MyState <: State {
    var count: Int64 = 0
    public init() {}
}

class MyComponent <: Component {
    public func update(ctx: Context, msg: Message, state: State): Action {
        let s = (state as MyState).getOrThrow()
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
        let s = (state as MyState).getOrThrow()
        Node.div(
            Div()
                .width(Dimension.Fixed(20))
                .child(Node.text("Count: ${s.count}"))
                .child(Node.text("Up/Down/Esc"))
        )
    }
}

main() {
    App.runInteractive(MyComponent(), MyState(), 20, 5)
}
```

## 协作与提交建议

- 分支策略：`main` 保持可用，功能开发建议从 `feat/<name>` 或 `fix/<name>` 分支发起
- 提交规范：建议使用 `feat:`、`fix:`、`docs:`、`test:`、`refactor:`、`chore:` 前缀
- 提交粒度：一次提交只做一类变更，避免把功能、重构、格式化混在一起
- 发布策略：当 API 或示例达到稳定状态后，打对应标签，例如 `v0.1.0`
- Issue 协作：缺陷和新需求建议通过 GitHub Issues 提交，便于跟踪和归档

## 核心 API

### 组件生命周期

每个组件实现 `Component` 接口：

```cangjie
interface Component {
    // 处理消息，返回新状态或退出操作
    func update(ctx: Context, msg: Message, state: State): Action
    // 根据状态生成视图树
    func view(ctx: Context, state: State): Node
}
```

### State 与 Action

- `State`：组件状态基类，自定义状态需继承此类
- `Action.update(state)`：更新状态并触发重新渲染
- `Action.exit()`：退出应用
- `Action.updateWithEffects(state, effects)`：更新状态并附带异步效果

### Node 节点树

```cangjie
Node.div(Div().width(...).height(...).child(...))   // 容器节点
Node.text("hello")                                   // 纯文本
Node.richText(spans)                                 // 富文本（多种样式）
Node.builtin(builtinComponent)                       // 内置组件节点
```

### 样式

```cangjie
Div()
    .width(Dimension.Fixed(30))          // 固定宽度
    .height(Dimension.Percent(50))       // 百分比高度
    .border(Border.rounded())            // 圆角边框
    .fg(Color.Cyan)                      // 前景色
    .bg(Color.Rgb(30, 30, 46))           // RGB 背景色
    .bold(true)                          // 粗体
    .padding(Spacing(1, 2, 1, 2))        // 上右下左内边距
```

### 异步效果

```cangjie
// 延迟执行
Action.updateWithEffects(state, Effects.delay(1000) { => MyMessage() })

// 定时重复
Action.updateWithEffects(state, Effects.interval(100) { => TickMessage() })
```

### 启动应用

```cangjie
// 交互式运行（全屏，接管终端）
App.runInteractive(component, initialState, width, height)

// 使用自定义事件源运行（用于测试）
App.run(component, initialState, width, height, eventSource)
```

## 交互操作

| 按键 | 功能 |
|------|------|
| `Esc` | 退出应用 |
| `Tab` | 在组件间切换焦点 |
| `↑` `↓` | 导航列表 / 滚动区域 / 调整值 |
| `PageUp` `PageDown` `Home` `End` | 快速导航 |
| `Enter` | 提交输入 / 选择项目 / 按下按钮 |
| 鼠标滚轮 | 滚动列表和可滚动区域 |
| 鼠标点击 | 选择项目 / 放置光标 / 触发按钮 |

## 项目结构

```
src/
├── lib.cj                   # 公共 API 导出
├── app/                     # 应用运行时
│   ├── app.cj               # App 入口工厂方法
│   ├── events.cj            # ANSI 转义序列解析
│   ├── runner.cj            # 事件循环、stdin/resize 事件源
│   └── runtime.cj           # 状态管理、效果调度、渲染协调
├── buffer/                  # 屏幕缓冲
│   └── buffer.cj            # ScreenBuffer、DoubleBuffer 差分更新
├── builtin/                 # 内置组件
│   └── components.cj        # 12 个内置组件实现
├── component/               # 组件核心类型
│   ├── component.cj         # Component、State、Action、Message
│   ├── context.cj           # Context 上下文
│   └── events.cj            # UiEvent、KeyEvent、MouseEvent
├── layout/                  # 布局引擎
│   └── layout.cj            # LayoutEngine（尺寸计算、位置分配）
├── node/                    # 节点树
│   └── node.cj              # Node、Div、Text、RichText
├── render/                  # 渲染器
│   └── renderer.cj          # Renderer、FramePipeline
├── style/                   # 样式系统
│   └── style.cj             # Style、Color、Border、Spacing、Dimension
└── terminal/                # 终端控制
    └── terminal.cj          # TerminalRenderer、Raw 模式、stty 集成
```

## 路线图

- [ ] Virtual DOM 差分算法
- [ ] Inline 模式（嵌入终端行内，不独占全屏）
- [ ] Flexbox 高级布局（flex-grow / flex-shrink）
- [ ] 主题系统
- [ ] 更多内置组件（Table、Tree、Chart）

## 许可证

MIT
