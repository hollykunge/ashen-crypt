extends "res://scripts/sheet.gd"

# 回到挂机时报一声：离开了多久，这段时间挂到了什么。收益在弹出之前已经入账。

const Gear = preload("res://scripts/gear.gd")

var report: Dictionary = {}

func present(main, gained: Dictionary) -> void:
	report = gained
	_fit_width()
	_clear()
	_title("离线收益", main.profile.display_name())
	var away := float(gained.get("away", 0.0))
	var counted := float(gained.get("counted", away))
	var note := "离开 %s" % clock(away)
	if counted < away:
		note += "，计满 %s" % clock(counted)
	body.add_child(_text(note, 14, ui.GOLD))
	var material := Gear.material(String(gained.get("material", "")))
	body.add_child(_pairs([["击杀", "%d" % int(gained.get("kills", 0))],
		["灵砂", "+%d" % int(gained.get("silver", 0))],
		[String(material.get("name", "材料")), "+%d" % int(gained.get("materials", 0))]]))
	body.add_child(_text("离线按挂机效率的五成计。", 12, ui.MUTED))
	var take: Button = ui._button("收下", true, 46)
	take.pressed.connect(close)
	body.add_child(take)
	open()
