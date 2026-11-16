class_name UserPaths
extends RefCounted
## The one place that builds user:// paths. Every save or log path goes through here.


## Joins a sub folder under user://. of("save") is "user://save".
static func of(sub: String) -> String:
	return "user://" + sub
