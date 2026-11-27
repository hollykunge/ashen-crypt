extends "res://scripts/sheet.gd"

# 角色信息与挂机统计：点挂机页左上角的头像打开。数值每半秒跟着场上刷新一次。

signal roster_requested

const Gear = preload("res://scripts/gear.gd")
const Roster = preload("res://scripts/roster.gd")
const SideArt = preload("res://scripts/side_art.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")

var profile: Gear
var run
var live: Dictionary = {}
var refresh_left := 0.0

func present(main) -> void:
	profile = main.profile
	run = main.run
	_fit_width()
	_rebuild(main)
	open()

func tick(main, delta: float) -> void:
	if not visible:
		return
	refresh_left -= delta
	if refresh_left > 0.0:
		return
	refresh_left = 0.5
	_fill_live(main)

func _rebuild(main) -> void:
	_clear()
	live.clear()
	_title("角色信息")
	var person := profile.character()
	var female: bool = person.get("gender") == "female"
	var stem := String(person.get("day_stem", "geng"))
	var element := WuXing.stem_element(stem)

	var top: HBoxContainer = ui._hbox(12)
	body.add_child(top)
	var face: TextureRect = ui._image(SideArt.portrait(person.get("gender", "")))
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(66, 86)
	face.modulate = Roster.ELEMENT_TINTS[element].lerp(Color.WHITE, 0.67)
	top.add_child(face)
	var names: VBoxContainer = ui._vbox(2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(names)
	names.add_child(ui._label(profile.display_name(), 24, ui.INK))
	var month: Dictionary = WuXing.BRANCHES.get(person.get("month_branch", ""), {})
	var hour: Dictionary = WuXing.BRANCHES.get(person.get("hour_branch", ""), {})
	names.add_child(_text("%s · %s · %s · %s月 %s时" % ["男" if not female else "女", Gear.fate_caption(stem),
		String(profile.origin().get("name", "")), month.get("name", ""), hour.get("name", "")], 13, ui.GOLD))
	names.add_child(_text("%s · 第 %d 层" % [profile.realm().name, profile.layer()], 13, ui.MUTED))

	_section("修行")
	var place := profile.place()
	live.journey = _pairs([["所在", String(place.get("name", ""))], ["地气", Gear.ling_caption(profile.ling())],
		["灵砂", ""], ["本层材料", ""]])
	body.add_child(live.journey)

	_section("属性")
	live.stats = _pairs([["攻击", ""], ["生命", ""], ["灵力", ""], ["暴击", ""], ["免伤", ""], ["出手间隔", ""]])
	body.add_child(live.stats)

	_section("挂机统计")
	live.farm = _pairs([["本次挂机", ""], ["击杀", ""], ["灵砂", ""], ["材料", ""]])
	body.add_child(live.farm)
	body.add_child(_text("离线时按每时 %d 击杀的五成结算，最多计 12 小时。" % roundi(profile.kills_per_hour()), 12, ui.MUTED))

	var row: HBoxContainer = ui._hbox(8)
	body.add_child(row)
	var back: Button = ui._button("返回选角", false, 44)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void: roster_requested.emit())
	row.add_child(back)
	var done: Button = ui._button("关闭", true, 44)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(close)
	row.add_child(done)
	_fill_live(main)

func _put(grid: GridContainer, row: int, value: String) -> void:
	var label: Label = grid.get_child(row * 2 + 1)
	label.text = value

func _fill_live(main) -> void:
	if live.is_empty():
		return
	var stem := profile.ling()
	_put(live.journey, 2, "%d" % (profile.silver() + int(main.pending_silver)))
	_put(live.journey, 3, "%s %d" % [Gear.material(stem).get("name", ""), profile.stock(stem)])
	_put(live.stats, 0, "%d" % int(run.hero.damage))
	_put(live.stats, 1, "%d / %d" % [int(run.hp), int(run.max_hp)])
	_put(live.stats, 2, "%d" % int(run.max_mana))
	_put(live.stats, 3, "%d%%" % roundi(float(run.crit_chance) * 100.0))
	_put(live.stats, 4, "%d%%" % roundi(float(run.damage_reduction) * 100.0))
	_put(live.stats, 5, "%.2f 秒" % float(run.hero.interval))
	var seconds: float = main.farm_seconds
	_put(live.farm, 0, clock(seconds))
	_put(live.farm, 1, _rate(main.farm_kills, seconds))
	_put(live.farm, 2, _rate(main.farm_silver, seconds))
	_put(live.farm, 3, _rate(main.farm_materials, seconds))

static func _rate(count: int, seconds: float) -> String:
	if seconds < 10.0:
		return "%d" % count
	return "%d · 每时 %d" % [count, roundi(count / seconds * 3600.0)]
