extends RefCounted
## Normalized skill phases. Angles drive the existing puppet joints, distances are in leg lengths.
const DURATION := 1.16
const TAKEOFF := 0.29
const RELEASE := 0.46
const WAIST_LEAD := 0.395
const BLADE_RELEASE := 0.49
const IMPACT := 0.56
const TIMES := [0.0,0.14,0.22,TAKEOFF,RELEASE,IMPACT,0.64,0.75,0.88,1.0]
const CHANNELS := ["torso","neck","arm_near_up","arm_near_lo","blade","arm_far_up","arm_far_lo",
	"hip","dx","foot_near_x","foot_near_y","foot_far_x","foot_far_y","foot_far_heel"]
## 起跳和腾空时刀举到头顶后方（上臂 150°～165°、肘弯回去），近侧手臂不挡脸
const KEYS := [
	[0,-1,24,78,-9,-10,72, 0.92,0.0,0.34,0.0,-0.30,0.0,0],
	[-5,3,42,94,-12,0,62, 0.77,-0.09,0.34,0.0,-0.30,0.0,0],
	[-6,4,160,45,-15,5,66, 0.75,-0.10,0.31,0.08,-0.30,0.0,-5],
	[-9,5,150,75,-15,8,81, 0.91,-0.05,0.33,0.43,-0.30,0.0,-16],
	[-7,4,165,45,-14,-10,72, 0.86,0.12,0.52,0.48,-0.34,0.12,-15],
	[21,-10,49,9,19,-25,86, 0.75,0.27,0.77,0.0,-0.27,0.0,-12],
	[23,-11,46,7,19,-24,82, 0.72,0.28,0.77,0.0,-0.27,0.0,-12],
	[16,-8,32,15,16,-15,60, 0.78,0.24,0.77,0.0,-0.27,0.0,-7],
	[5,-3,26,46,4,-7,55, 0.87,0.10,0.52,0.09,-0.28,0.0,0],
	[0,-1,24,78,-9,-10,72, 0.92,0.0,0.34,0.0,-0.30,0.0,0]
]

static func supports(look: Dictionary) -> bool:
	return look.get("gender") == "male" and look.get("armed",false) and look.get("form") == "sword"

static func pose(phase: float) -> Dictionary:
	var i := clampi(TIMES.bsearch(phase,false)-1,0,TIMES.size()-2)
	var u := smoothstep(TIMES[i],TIMES[i+1],phase)
	var result := {}
	for k in CHANNELS.size():
		var channel: String = CHANNELS[k]
		var amount := u
		if TIMES[i] == RELEASE and channel in ["arm_near_up","arm_near_lo","blade"]:
			amount = smoothstep(BLADE_RELEASE,IMPACT,phase)
		result[channel] = lerpf(KEYS[i][k],KEYS[i+1][k],amount)
	# Load the front hip and unwind the ribs while the weapon is still high.
	# This offset fades into the existing contact pose.
	var lead := smoothstep(WAIST_LEAD,BLADE_RELEASE,phase)*(1.0-smoothstep(BLADE_RELEASE,IMPACT,phase))
	result.torso += 15.0*lead
	result.dx += 0.045*lead
	var t := clampf(inverse_lerp(TAKEOFF,IMPACT,phase),0,1)
	var lift := 0.48*4.0*t*(1.0-t)
	for channel in ["hip","foot_near_y","foot_far_y"]:
		result[channel] += lift
	return result
