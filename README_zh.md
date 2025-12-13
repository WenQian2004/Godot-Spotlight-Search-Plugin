# Spotlight Search（Godot 4 编辑器插件）

目录：`addons/spotlight_search`

Spotlight Search 是一个面向 Godot 4 的"全局搜索 + 命令面板"插件，提供文件/场景/脚本搜索、命令过滤、节点跳转、历史记录、Pin 固定、上下文菜单、扩展命令等能力，类似 IDE 中的 Spotlight / Command Palette。

---

## 演示

![演示截图 1](img/sp01.png)
![演示截图 2](img/sp02.png)

---

## 功能概览

- 快速搜索工程资源
  - 支持场景（`.tscn`）、脚本（`.gd` / `.cs`）、图片、音频、通用资源等。
  - 模糊匹配文件名，按得分排序。
- 命令前缀过滤
  - `-gd`：只搜索 GDScript。
  - `-sc`：只搜索场景。
  - `-img`：只搜索图片。
  - `-res`：只搜索资源。
  - `-track`：在“已标记节点”中搜索（配合 Inspector 按钮）。
  - `-node`：浏览引擎内置 Node 类型及其属性。
  - `-class`：浏览引擎类的属性与方法。
- 常用操作命令
  - `-new`：创建脚本、Shader 等资源文件。
  - `-scene`：当前场景的运行、重载、保存。
  - `-color`：颜色解析与拷贝工具，支持 `#HEX` / `rgb()` 等。
  - `-reload`：重载整个工程。
  - `-quit`：退出编辑器。
  - `-fs`：切换编辑器全屏/窗口模式。
- 历史记录与固定（Pin）
  - 记录打开过的文件和命令，支持在空输入状态下查看最近记录。
  - 通过右键菜单将文件 Pin 到顶部。
- 上下文菜单
  - 文件/资源：复制路径、复制文件名、在 FileSystem 中定位、外部编辑器打开、打开所在文件夹、Pin/Unpin。
  - 节点：复制 `$` 开头的节点路径、复制节点名称、在场景树中聚焦、复制节点。
- 节点跟踪（Tracked Nodes）
  - 在 Inspector 中给任意 Node 添加/移除 “Add to Spotlight Search” 标记。
  - 使用 `-track` 前缀在当前场景中快速搜索这些标记节点。
- 可配置与扩展
  - 在配置窗口中设置：
	- 最大结果数量。
	- 需要排除的目录（如 `addons/`、`.git/`、`.import/` 等）。
	- 激活快捷键（默认 Alt+Q）。
	- 导入/管理外部 JSON 命令配置。
  - 支持通过 JSON + GDScript 编写扩展命令，以及通过 API 注册自定义动作。

---

## 安装与启用

1. 将本插件目录复制到工程：
   - 拷贝整个 `addons/spotlight_search` 文件夹到你的 Godot 工程根目录。
2. 在 Godot 4 编辑器中启用插件：
   - 依次打开：`Project > Project Settings... > Plugins`。
   - 找到 `Spotlight Search`，将状态切换为 `Active`。
3. 启用后，编辑器顶部工具栏会出现一个 `Spotlight` 按钮，同时在 Inspector 中会为节点添加“加入 Spotlight 搜索”的按钮。

---

## 基本使用

### 1. 打开 / 关闭 Spotlight 窗口

- 默认快捷键：`Alt + Q`
  - 判断逻辑见 `addons/spotlight_search/managers/config_manager.gd:124-137`。
- 其他方式：
  - 点击编辑器顶栏中的 `Spotlight` 按钮，会打开配置窗口（而不是搜索窗口）。
  - 要开启搜索窗口，需要使用快捷键。

Spotlight 窗口脚本：`addons/spotlight_search/ui/spotlight_window.gd`。  
场景：`addons/spotlight_search/ui/spotlight_window.tscn`。

### 2. 基础搜索

1. 打开 Spotlight 窗口后，光标会自动聚焦到搜索框。
2. 直接输入关键字即可按文件名进行模糊搜索：
   - 支持中间匹配与顺序模糊匹配，例如输入 `plg` 可以匹配到 `spotlight_plugin.gd`。
3. 不输入任何内容时（空输入），会显示：
   - 固定（Pin）在顶部的文件。
   - 最近访问过的文件。
   - 适量推荐的场景和脚本等资源。

搜索核心逻辑位于 `addons/spotlight_search/services/search_logic.gd` 与 `addons/spotlight_search/services/query_service.gd`。

### 3. 使用命令前缀过滤

在搜索框前面输入命令前缀（以 `-` 开头）可以切换不同的搜索模式：

- 资源过滤：
  - `-gd`：只搜索脚本文件。
  - `-sc`：只搜索场景文件。
  - `-img`：只搜索图片。
  - `-res`：只搜索其他资源。
- 跟踪节点：
  - `-track`：在“已标记节点”中搜索（见下文节点跟踪）。
- 引擎类浏览：
  - `-node`：浏览内置 Node 类型及其暴露属性。
  - `-class`：浏览任意类的属性与方法。
- 新建资源：
  - `-new -script MyScript`：在当前选中的目录下创建一个脚本文件（名称为 `MyScript.gd`）。
  - `-new -shader MyShader`：创建基础 Shader 文件。
- 配置命令：
  - `-config -plugin_setting`：打开插件配置窗口。

命令定义集中在 `addons/spotlight_search/managers/command_manager.gd` 中的 `BUILTIN_COMMANDS` 常量内。

### 4. 历史记录与收藏

- 历史：
  - 执行以 `-` 开头的命令（如 `-gd`、`-new -script` 等）时，会通过 `HistoryManager.add_to_history()` 写入工程设置。
  - 在 Spotlight 窗口中，搜索框为空时按 `Shift + ↑` 会显示“历史记录视图”，包括：
	- 收藏的命令。
	- 最近使用的命令。
- 收藏：
  - 数据结构和读写接口已经在 `addons/spotlight_search/managers/history_manager.gd` 中实现（`add_favorite` / `toggle_favorite` 等）。
  - 当前版本中，底部提示会显示 `F: Toggle Favorite`，但尚未绑定对应按键逻辑，具体情况见 `ISSUES.md` 中的说明。

---

## 节点跟踪（Tracked Nodes）

若你的场景中有一些“关键节点”需要反复定位，可以使用节点跟踪功能：

1. 选中任意场景中的节点，在 Inspector 中可以看到一个由插件注入的按钮：
   - 初始状态：`Add to Spotlight Search`（绿色）。
   - 已跟踪状态：`Remove from Spotlight Search`（红色）。
2. 点击按钮即可将节点加入/移出 `spotlight_tracked` 组，组名在 `addons/spotlight_search/editor/spotlight_tracker.gd:3` 中定义，与搜索逻辑保持同步。
3. 在 Spotlight 搜索框中输入：
   - `-track`：列出所有已标记节点。
   - `-track xxx`：在标记节点中按名称模糊搜索。
4. 选择结果后，可快速在场景树中定位并切换 2D/3D 视图。

相关代码：
- Inspector 插件：`addons/spotlight_search/editor/spotlight_tracker.gd`
- 节点搜索逻辑：`addons/spotlight_search/services/search_logic.gd:29-73`

---

## 右键上下文菜单

在结果列表中，除纯命令项外，可以通过右键打开上下文菜单：

- 文件 / 资源（`default` 菜单）：
  - `Copy Path`：复制资源路径（如 `res://...`）。
  - `Copy File Name`：复制文件名。
  - `Show in FileSystem`：在 FileSystem Dock 中定位。
  - `Open Containing Folder`：在系统文件管理器中打开所在目录。
  - `Open in External Editor`：使用系统默认程序打开该文件。
  - `Pin/Unpin`：将该路径加入或移出 Pin 列表。
- 节点（`node` 菜单）：
  - `Copy Node Path ($...)`：复制 `$` 开头的相对节点路径，自动处理包含空格的情况。
  - `Copy Node Name`：复制节点名称。
  - `Focus in Scene Tree`：在场景树中选中该节点并切换至对应 2D/3D。
  - `Duplicate Node`：复制该节点并添加到同一父节点下。

菜单配置位于：`addons/spotlight_search/services/context_menu_config.gd`。  
行为实现位于：`addons/spotlight_search/services/context_menu_service.gd`。

---

## 配置与扩展

### 1. 打开配置窗口

有两种方式可以打开 Spotlight 配置窗口：

- 在 Spotlight 搜索中使用命令：
  - 输入 `-config -plugin_setting` 并执行。
- 通过内置动作：
  - 插件会注册一个 `open_settings` 动作，在 `addons/spotlight_search/services/action_registry.gd:90-111` 中实现，点击顶栏 `Spotlight` 按钮会调用该动作。

配置窗口脚本：`addons/spotlight_search/ui/config_window.gd`。

### 2. 可配置项

在配置窗口中可以调整：

- 最大结果数：
  - 对应 Project Settings 中的 `addons/spotlight_search/config/max_results`。
  - 由 `ConfigManager.get_max_results()` 读取，影响查询结果截断数量。
- 排除目录：
  - 一行一个模式，例如：`addons/`、`.git/`、`.godot/` 等。
  - 用于文件系统扫描时跳过部分目录，配置项为 `addons/spotlight_search/config/exclude_folders`。
- 快捷键：
  - 可以在配置窗口中点击“Activation Key”，按任意键设置新的 keycode，并勾选/取消 `Alt` / `Ctrl` / `Shift` 修饰键。
  - 最终组合由 `ConfigManager.is_shortcut(event)` 统一判断。
- 外部 JSON 配置：
  - 通过 “Import JSON Config...” 按钮选择 JSON 文件。
  - 被导入的路径会保存在 `addons/spotlight_search/config/external_configs` 对应的字典中，并由 `CommandManager.load_all_commands()` 统一加载。
  - 配置窗口会列出所有已加载/禁用/错误的 JSON 配置文件，方便启用/禁用或移除。

### 3. JSON 命令扩展示例

插件内置了一个完整的 Hello World 扩展示例：

- JSON 文件：
  - `addons/spotlight_search/data/examples/hello_extension.json`
- 动作脚本：
  - `addons/spotlight_search/data/examples/hello_actions.gd`

使用方式：

1. 打开 Spotlight 配置窗口。
2. 点击 “Create Example Extension” 按钮。
3. 插件会在 `res://toolkit_extensions/` 下创建：
   - `hello_extension.json`
   - `hello_actions.gd`
4. 并自动将 JSON 路径注册到外部配置中，重新加载命令。
5. 之后可以在 Spotlight 中输入 `-hello` 体验嵌套命令、参数校验、动作执行等完整流程。

命令解析与执行的主要流程：

- JSON 解析与命令注册：
  - `addons/spotlight_search/managers/command_manager.gd:_load_config_file()` 与 `_register_json_item()`。
- 查询解析：
  - `addons/spotlight_search/services/query_service.gd:_try_parse_command()`。
- 动作执行：
  - `addons/spotlight_search/services/action_service.gd` 与 `addons/spotlight_search/services/action_registry.gd`。

### 4. 通过 API 注册自定义动作

若你只需要定义若干可复用动作，而不想通过 JSON 搭建完整指令树，可以使用 `ToolkitAPI`：

- API 脚本：`addons/spotlight_search/api/toolkit_api.gd`
- 核心接口：
  - `ToolkitAPI.register_action(action_id: String, callable: Callable)`
  - `ToolkitAPI.show_toast(message: String, type: String = "info")`

示例（插件中已内置一份示例模板，在 `spotlight_plugin.gd:_get_sample_extension_content()` 中）：

```gdscript
@tool
extends RefCounted

const ToolkitAPI = preload("res://addons/spotlight_search/api/toolkit_api.gd")

func _init():
	ToolkitAPI.register_action("hello_world", _hello_world)

func _hello_world(args: Array = []):
	var name = args[0] if args.size() > 0 else "User"
	ToolkitAPI.show_toast("Hello " + name + "!", "success")
```

结合 JSON 中的 `action_id`，即可从 Spotlight 面板中执行这些动作。

### 5. Provider 基类（预留接口）

`addons/spotlight_search/api/base_provider.gd` 中提供了 `SpotlightProvider` 基类，用于实现前缀驱动的自定义 Provider：

- 通过 `get_prefix()` 定义触发前缀（例如 `-todo`）。
- 在 `query(search_text)` 中返回一个字典数组，内部会被转换为 `SearchData` 并显示在结果列表中。
- `execute(action_id, args)` 用于在用户选择结果时执行自定义逻辑。

当前版本尚未在核心查询流程中自动扫描/注册 Provider

---


## 兼容性

- 代码中大量使用：
  - `DisplayServer`、`Window` 新属性。
  - `@tool` + `RefCounted` 模式。
  - Godot 4 的类型常量（如 `TYPE_*`、`PROPERTY_USAGE_*`）。
  - `EditorInterface` 的 4.x API（如 `open_scene_from_path`、`restart_editor` 等）。
- 因此本插件定位为 **Godot 4.x 编辑器插件**，不建议在 Godot 3 项目中使用。

---
