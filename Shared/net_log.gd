class_name NetLog
static var enabled: bool = false
static func init_from_args(args: PackedStringArray) -> void:
	enabled = args.has(NetConfig.LOG_NETWORK_ARG)
static func d(tag: String, msg: String) -> void:
	if enabled:
		print("[NET/%s] %s" % [tag, msg])
