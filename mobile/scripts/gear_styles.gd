extends RefCounted
## 装备款式：上衣、护腕、护腿、靴子每件记一个款式名（item.style），款式随意起名，不分布衣、皮甲、链甲。
## 皮影主角按款式名换对应的部件图。每个角色的款式图放在
##   res://prototype/cutout/<角色>/gear/<槽>/<款式名>/<部件图>.png
## 同角色的 gear/styles.json 列出每个槽画了哪些款式（打包后的游戏里不好列目录，所以用清单）：
##   {"greaves": ["青布绑腿", "鱼鳞护腿"], "boots": ["云头靴"]}
## 款式名为空、或这个角色没画这一款，就不换图，露出角色本来的样子。

const ROOT := "res://prototype/cutout/"
const SLOTS := ["armor", "gloves", "greaves", "boots"]

static var _catalogs := {}


## 男女主各用哪套皮影
static func who_for(gender: String) -> String:
	return "nvjiang" if gender == "female" else "piying"


## 这个角色每个槽画了哪些款式：{槽: [款式名, ...]}
static func catalog(who: String) -> Dictionary:
	if not _catalogs.has(who):
		var path := ROOT + who + "/gear/styles.json"
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		var out := {}
		if parsed is Dictionary:
			for slot in SLOTS:
				var names = parsed.get(slot, [])
				if names is Array:
					out[slot] = names.filter(func(n): return n is String and not n.is_empty())
		_catalogs[who] = out
	return _catalogs[who]


## 某个槽能选的款式（炉坊里选）
static func names(who: String, slot: String) -> Array:
	return catalog(who).get(slot, [])


static func has_style(who: String, slot: String, style: String) -> bool:
	return not style.is_empty() and style in names(who, slot)


## 外观里各槽的款式名 → 皮影换装用的 {槽: 款式图目录}，只放这个角色画了的款式
static func outfit(who: String, styles: Dictionary) -> Dictionary:
	var out := {}
	for slot in styles:
		if has_style(who, slot, styles[slot]):
			out[slot] = "%s%s/gear/%s/%s" % [ROOT, who, slot, styles[slot]]
	return out


## 测试用：清掉读过的清单
static func clear_cache() -> void:
	_catalogs.clear()
