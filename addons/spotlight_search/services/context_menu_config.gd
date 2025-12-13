extends RefCounted

const ID_COPY_PATH = "copy_path"
const ID_COPY_NODE_PATH = "copy_node_path"
const ID_COPY_NODE_NAME = "copy_node_name"
const ID_SHOW_IN_FS = "show_in_fs"
const ID_TOGGLE_PIN = "toggle_pin"
const ID_COPY_NAME = "copy_name"
const ID_OPEN_EXTERNAL = "open_external"
const ID_OPEN_FOLDER = "open_folder"
const ID_DELETE_FILE = "delete_file"
const ID_DUPLICATE = "duplicate"

const MENUS = {
	"default": [
		{"id": ID_COPY_PATH, "label": "Copy Path", "icon": "ActionCopy"},
		{"id": ID_COPY_NAME, "label": "Copy File Name", "icon": "Rename"},
		{"type": "separator"},
		{"id": ID_SHOW_IN_FS, "label": "Show in FileSystem", "icon": "FileSystem"},
		{"id": ID_OPEN_FOLDER, "label": "Open Containing Folder", "icon": "Folder"},
		{"id": ID_OPEN_EXTERNAL, "label": "Open in External Editor", "icon": "ExternalLink"},
		{"type": "separator"},
		{"id": ID_TOGGLE_PIN, "label": "Pin/Unpin", "icon": "Pin"}
	],
	"node": [
		{"id": ID_COPY_NODE_PATH, "label": "Copy Node Path ($...)", "icon": "NodePath"},
		{"id": ID_COPY_NODE_NAME, "label": "Copy Node Name", "icon": "Rename"},
		{"type": "separator"},
		{"id": ID_SHOW_IN_FS, "label": "Focus in Scene Tree", "icon": "SceneTreeEditor"},
		{"id": ID_DUPLICATE, "label": "Duplicate Node", "icon": "Duplicate"}
	],
	"script": [
		{"id": ID_COPY_PATH, "label": "Copy Path", "icon": "ActionCopy"},
		{"id": ID_COPY_NAME, "label": "Copy File Name", "icon": "Rename"},
		{"type": "separator"},
		{"id": ID_SHOW_IN_FS, "label": "Show in FileSystem", "icon": "FileSystem"},
		{"id": ID_OPEN_EXTERNAL, "label": "Open in External Editor", "icon": "ExternalLink"},
		{"type": "separator"},
		{"id": ID_TOGGLE_PIN, "label": "Pin/Unpin", "icon": "Pin"}
	]
}
