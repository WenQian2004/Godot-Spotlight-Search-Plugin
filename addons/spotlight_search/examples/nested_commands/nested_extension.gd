@tool
extends SpotlightSimpleExtension

# 这个扩展示例展示了如何使用 SpotlightSimpleExtension 快速创建嵌套指令

func _init():
	# 1. 创建顶级指令 -git
	var git = add_command("-git", "Git Tools") \
		.set_description("Access Git version control commands.") \
		.set_icon("Tree") \
		.set_tags(["Tool", "Git"])
	
	# 2. 为 -git 添加子命令
	
	# -git commit
	git.add_command("commit", "Commit Changes") \
		.set_description("Stage and commit all changes.") \
		.set_icon("Save") \
		.set_action(func(): print("Executing: git commit"))
	
	# -git push
	git.add_command("push", "Push to Remote") \
		.set_description("Push local commits to remote repository.") \
		.set_icon("ArrowUp") \
		.set_action(func(): print("Executing: git push"))
		
	# -git pull
	git.add_command("pull", "Pull from Remote") \
		.set_description("Fetch and merge changes from remote.") \
		.set_icon("ArrowDown") \
		.set_action(func(): print("Executing: git pull"))
	
	# 3. 支持多级嵌套: -git branch -> new / delete
	var branch = git.add_command("branch", "Branch Management") \
		.set_description("Manage Git branches.") \
		.set_icon("Tree")
		
	branch.add_command("new", "New Branch") \
		.set_description("Create a new branch.") \
		.set_icon("Add") \
		.set_action(func(): print("Executing: git branch new"))
		
	branch.add_command("delete", "Delete Branch") \
		.set_description("Delete an existing branch.") \
		.set_icon("Remove") \
		.set_action(func(): print("Executing: git branch delete"))

func get_id() -> String:
	return "example.git_tools"

func get_display_name() -> String:
	return "Git Tools"

func get_author() -> String:
	return "Example"
