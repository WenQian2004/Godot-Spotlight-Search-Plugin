@tool
class_name SpotlightCommand extends Resource

## Spotlight Search Command Definition
## Used to map a keyword to an action dynamically.

@export var keyword: String = ""
@export var description: String = ""
@export var icon_name: String = "Search"
@export var action_id: String = ""
@export var default_args: Array = []
