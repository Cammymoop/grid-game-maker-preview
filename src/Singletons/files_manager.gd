extends Node

func init_folders():
	var directory: = Directory.new()
	if directory.open("user://") != OK:
		print_debug("Could not open user directory")
		return
	
	if not directory.dir_exists("games"):
		directory.make_dir("games")
	if not directory.dir_exists("images"):
		directory.make_dir("images")
	if not directory.dir_exists("levels"):
		directory.make_dir("levels")
	if not directory.dir_exists("worlds"):
		directory.make_dir("worlds")
