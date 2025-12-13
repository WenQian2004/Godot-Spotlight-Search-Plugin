@tool
extends RefCounted
class_name SpotlightProvider

## Base class for Spotlight Search providers.
## Extend this class to create custom search providers.
##
## Example:
## ```gdscript
## extends SpotlightProvider
##
## func get_prefix() -> String:
##     return "-todo"
##
## func get_name() -> String:
##     return "Todo Manager"
##
## func query(search_text: String) -> Array[Dictionary]:
##     var results = []
##     # Your custom logic here
##     return results
## ```

const SearchData = preload("res://addons/spotlight_search/data/search_data.gd")

## Returns the command prefix that triggers this provider (e.g., "-todo")
## Override this in your provider class.
func get_prefix() -> String:
	push_warning("[SpotlightProvider] get_prefix() not implemented")
	return ""

## Returns the display name of this provider
## Override this in your provider class.
func get_name() -> String:
	return "Unnamed Provider"

## Returns the description shown in command list
func get_description() -> String:
	return "Custom provider"

## Returns the icon name from EditorIcons
func get_icon() -> String:
	return "Search"

## Called when the user types this provider's prefix.
## Return an array of result dictionaries.
## Each dictionary should have:
## - file_name: String (display title)
## - desc: String (subtitle)
## - icon_name: String (optional, EditorIcons name)
## - action_id: String (optional, action to execute)
## - args: Array (optional, arguments for action)
##
## Override this in your provider class.
func query(search_text: String) -> Array[Dictionary]:
	push_warning("[SpotlightProvider] query() not implemented")
	return []

## Called when the user selects an item from this provider's results.
## Return true if the action was handled, false otherwise.
## Override this in your provider class if needed.
func execute(action_id: String, args: Array) -> bool:
	return false

## Convert a dictionary result to SearchData
func _to_search_data(result: Dictionary) -> SearchData:
	var item = SearchData.new()
	item.file_name = result.get("file_name", "")
	item.desc = result.get("desc", "")
	item.icon_name = result.get("icon_name", get_icon())
	item.type = SearchData.Type.ACTION
	item.file_path = result.get("action_id", "")
	item.args = result.get("args", [])
	return item

## Convert an array of dictionary results to SearchData array
func _to_search_data_array(results: Array[Dictionary]) -> Array[SearchData]:
	var out: Array[SearchData] = []
	for r in results:
		out.append(_to_search_data(r))
	return out
