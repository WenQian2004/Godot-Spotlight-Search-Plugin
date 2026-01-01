# Spotlight Search (Godot 4 Editor Plugin)

Directory: `addons/spotlight_search`

Spotlight Search is a "global search + command palette" plugin for Godot 4, offering capabilities such as file/scene/script search, command filtering, node jumping, history, Pinning, context menus, extended commands, and more, similar to Spotlight / Command Palette in IDEs.

---

## Demo

![Screenshot 1](img/spv201.png)
![Screenshot 2](img/spv202.png)

---

## Core Features

*   **Universal Search**: Quickly find scenes (`.tscn`), scripts (`.gd/.cs`), resources, images, and more.
*   **Command Palette**: Execute editor commands (e.g., New Script, Reload Project, Toggle Fullscreen) directly from the search bar.
*   **Node Tracking**: Tag frequently used nodes in the scene and locate them instantly using the `-track` command.
*   **History & Favorites**: Automatically records usage history and supports Pinning/Favoriting common files or commands.
*   **Context Menu**: Provides utility actions like Copy Path, Show in FileSystem, Copy Node Path, etc.
*   **Highly Extensible**: Support for custom extensions via JSON and GDScript to create your own workflows.

---

## Shortcuts & Key Bindings

Mastering these shortcuts is the key to maximizing your efficiency with Spotlight Search.

### Basic Actions
| Key | Action | Description |
| :--- | :--- | :--- |
| **Alt + Q** | **Open/Close Window** | Default activation shortcut (customizable in settings). |
| **Esc** | **Close / Back** | Closes the context menu if open; otherwise defaults to closing the search window or going back. |
| **↑ / ↓** | **Select Result** | Navigate up and down through the search results list. |
| **Enter** | **Execute / Open** | Open the selected file or execute the selected command. |
| **Tab** | **Autocomplete / Enter** | Fill the search bar with the text of the currently selected item or enter a category. |
| **Left Key** | **Close the right view panel** | Closes the right view panel. |
| **Right Key** | **Open the right view panel** | Opens the right view panel, restoring the default layout. |

### Advanced Actions
| Key | Action | Description |
| :--- | :--- | :--- |
| **Shift + ↓** | **Show Favorites** | Display all favorited commands or files. |
| **Shift + ↑** | **Toggle Favorite** | Add or remove the currently selected command from "Favorites". |
| **Shift + Left Key** | **Full Preview Mode** | Hides the list and shows the preview panel in full screen. Allows custom input in preview. |
| **Shift + Right Key** | **Exit Full Preview** | Exits full screen preview and restores default layout. |

---

## Common Command Prefixes

Type these prefixes in the search bar to filter results or switch modes:

*   **Resource Filters**
	*   `-gdscript`: Search GDScript files (.gd)
	*   `-scene`: Search Scene files (.tscn)
	*   `-image`: Search Image assets (.png, .jpg, etc)
	*   `-resource`: Search Resources (.tres, .res)
	*   `-shader`: Search Shader files
*   **Common Commands**
	*   `-new`: Create New Resources (Script, Scene, Shader)
	*   `-quit`: Quit Editor
	*   `-reload`: Reload Project
	*   `-full`: Toggle Fullscreen
	*   `-zen`: (Experimental) Toggle Zen/Distraction Free Mode
*   **Advanced**
	*   `-config`: Open Plugin Settings
	*   `-track`: Manage/Find Tracked Nodes
	*   `-node`: Browse Engine Nodes
	*   `-class`: Browse All Engine Classes

---

## Installation

1.  Download this repository.
2.  Copy the `addons/spotlight_search` folder to your Godot project's root directory.
3.  Open the Godot Editor, go to **Project -> Project Settings -> Plugins**.
4.  Check **Enable** next to `Spotlight Search`.
5.  Once enabled, you will see a Spotlight button in the top toolbar, or press `Alt + Q` to start using it.

## 🔧 Configuration & Extensions

*   **Settings**: Type `-config` or click the Spotlight button in the toolbar to open Settings. You can adjust max results, exclude folder rules, and shortcut keys.
*   **Extensions**: The plugin supports a JSON-based extension system. You can write your own workflow actions in the `toolkit_extensions` folder. Check "Create Example Extension" in the settings window for a quick start.

---
*Made with ❤️ for Godot Developers.*
