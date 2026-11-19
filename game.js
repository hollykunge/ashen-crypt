"use strict";

const roles = {
  knight: {
    names: ["二郎神", "九天玄女"], detail: "横扫近敌，施展镇山诀可击退围攻的精怪。",
    skill: "镇山诀", hp: 156, speed: 106, damage: 31, interval: .33,
    reach: 103, cooldown: 3.6, color: "#ffbf74", sprite: 0
  },
  ranger: {
    names: ["后羿", "青鸟仙子"], detail: "以弓箭牵制远敌，连珠箭可同时射中多个目标。",
    skill: "连珠箭", hp: 109, speed: 122, damage: 24, interval: .24,
    reach: 490, cooldown: 3.3, color: "#8af1c6", sprite: 1
  },
  mage: {
    names: ["雷部天师", "电母"], detail: "以雷符攻敌，可在瞄准处召下五雷印。",
    skill: "五雷印", hp: 105, speed: 101, damage: 35, interval: .43,
    reach: 460, cooldown: 4.1, color: "#ddb2ff", sprite: 2
  }
};

const monsters = {
  skeleton: { hp: 44, speed: 81, damage: 9, size: 57, radius: 15, sprite: 3 },
  ghoul: { hp: 59, speed: 119, damage: 12, size: 63, radius: 18, sprite: 4 },
  sentinel: { hp: 410, speed: 69, damage: 24, size: 105, radius: 31, sprite: 5 }
};
const waves = [
  { skeleton: 4, name: "清山门", issuer: "土地公", order: "驱逐山魈，为香客开路" },
  { skeleton: 5, ghoul: 2, name: "护灶火", issuer: "灶君", order: "击退山魈与火狐，护住灶火" },
  { skeleton: 5, ghoul: 4, name: "守丹台", issuer: "太上老君", order: "扫清丹台前的精怪" },
  { skeleton: 6, ghoul: 6, name: "开云路", issuer: "青鸟使者", order: "击退群妖，打通昆仑云路" },
  { skeleton: 4, ghoul: 3, sentinel: 1, name: "伏山兽", issuer: "西王母", order: "降伏失控的镇山兽与随从" }
];

const ui = Object.fromEntries(Array.from(document.querySelectorAll("[id]"), el => [el.id, el]));
const classButtons = [...document.querySelectorAll(".class-choice")];
const ctx = ui.arena.getContext("2d");
const W = ui.arena.width;
const H = ui.arena.height;
const bounds = { left: 105, right: W - 105, top: 165, bottom: H - 93 };
const stance = { x: Math.round(W * .38), y: Math.round(H * .58) };
const footwork = {
  left: stance.x - 65, right: stance.x + 65,
  top: stance.y - 28, bottom: stance.y + 28
};
const portrait = matchMedia("(max-width: 600px) and (orientation: portrait)");
let viewLeft = 0;
const crypt = new Image();
const softBackdrop = document.createElement("canvas");
softBackdrop.width = 1000;
softBackdrop.height = 500;
const artRoot = "mobile/art/immortals/";
const sideRoot = "mobile/art/side/";
function artwork(file) {
  const image = new Image();
  image.src = sideRoot + file + ".png";
  return image;
}
const actors = ["frames-male", "frames-female"].map(artwork);
const foes = ["shanxiao", "fire-fox", "guardian"].map(artwork);
const stageFloor = H * .79;
const stageDepth = .28;
const snowFloor = .79;
const foeSpriteScale = 1.26;
const floorY = y => stageFloor + (y - stance.y) * stageDepth;
const grip = [[59,56], [63,52], [62,54], [63,59], [37,33], [77,43], [69,64], [60,48], [52,54], [61,44], [79,35], [61,56]];
const bladeAngles = [-.58, -.68, -.49, -.86, -2.20, -.12, .40, -.72, -.71, .18, -.67, -.62];
const soles = [
  { 1: [65, 88], 11: [54, 89], 2: [34, 88] },
  { 1: [62, 88], 11: [53, 89], 2: [33, 88] }
];
const attackRelease = 2 / 6;
const bladeCues = [.17, .43, .69];
const bladeShares = [0, .27, .56, 1];
const comboWindow = 1.25;
const waveSpacing = 176;
const travelSpeed = 240;
crypt.addEventListener("load", () => {
  const context = softBackdrop.getContext("2d");
  context.imageSmoothingQuality = "high";
  context.drawImage(crypt, 0, 0, softBackdrop.width, softBackdrop.height);
});
crypt.src = sideRoot + "kunlun-snow-pass.webp";
const styleButtons = [...document.querySelectorAll("[data-style]")];
const help = document.querySelector("footer");
let style = 0;

const input = {
  keys: new Set(), aiming: false, x: 0, y: 0, clickAttack: false,
  buttonAttack: false, goal: null
};
const gameKeys = new Set(["KeyW", "KeyA", "KeyS", "KeyD", "ArrowUp", "ArrowLeft", "ArrowDown", "ArrowRight", "KeyJ", "KeyQ", "KeyM", "KeyV", "Space", "Escape"]);
const coarsePointer = matchMedia("(pointer: coarse)").matches;
const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
let selected = "knight";
let mode = "selection";
let player;
let enemies;
let projectiles;
let loot;
let effects;
let popups;
let waveIndex;
let nextWave;
let layerNumber = 1;
let sectionX = 0;
let snowDrift = 0;
let announcement;
let kills;
let ash;
let lastFrame = 0;
let controlMode = 1;
let battleSpeed = 1;
let muted = true;
let audio;

const clamp = (n, min, max) => Math.max(min, Math.min(n, max));
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

function resizeArena() {
  ui.arena.width = portrait.matches ? 625 : W;
  viewLeft = (W - ui.arena.width) / 2;
  bounds.left = portrait.matches ? viewLeft + 33 : 105;
  bounds.right = W - bounds.left;
  if (player && mode !== "selection") {
    for (const entity of [player, ...enemies, ...loot]) entity.x = clamp(entity.x, bounds.left + sectionX, bounds.right + sectionX);
    input.goal = null;
    input.aiming = false;
    draw();
  }
}

function select(id) {
  selected = id;
  for (const button of classButtons) {
    const role = roles[button.dataset.class];
    button.setAttribute("aria-pressed", String(button.dataset.class === id));
    button.querySelector("img").src = artRoot + "portrait-" + (role.sprite * 2 + style) + ".webp";
    button.querySelector(".class-title").textContent = role.names[style];
  }
  ui["class-detail"].textContent = roles[id].detail;
}

function clearInput() {
  input.keys.clear();
  input.clickAttack = false;
  input.buttonAttack = false;
  input.goal = null;
  input.aiming = false;
  if (player) player.attackBuffer = 0;
}

function updateFightControls() {
  ui["fight-mode"].textContent = ["手动", "自动普攻", "全自动"][controlMode];
  ui["fight-mode"].dataset.level = String(controlMode);
  ui["fight-mode"].setAttribute("aria-label", ui["fight-mode"].textContent + "，点击切换战斗操作");
  ui["fight-speed"].textContent = battleSpeed + "×";
  ui["fight-speed"].setAttribute("aria-label", "战斗速度 " + battleSpeed + " 倍");
}

function cycleControlMode() {
  if (mode !== "battle") return;
  clearInput();
  controlMode = (controlMode + 1) % 3;
  updateFightControls();
}

function cycleBattleSpeed() {
  if (mode !== "battle") return;
  battleSpeed = battleSpeed % 3 + 1;
  updateFightControls();
}

function begin() {
  clearInput();
  const role = roles[selected];
  player = {
    ...stance, role, hp: role.hp, maxHp: role.hp, level: 1, xp: 0,
    angle: 0, skill: 0, dash: 0, hit: 0, dodge: 0, motion: null, stride: 0, stepX: 1, stepY: 0,
    attackBuffer: 0, combo: 0, comboLeft: 0, cutIn: 0
  };
  enemies = [];
  projectiles = [];
  loot = [];
  effects = [];
  popups = [];
  waveIndex = -1;
  layerNumber = 1;
  sectionX = 0;
  snowDrift = 0;
  kills = 0;
  ash = 0;
  mode = "battle";
  help.hidden = false;
  ui.selection.hidden = true;
  ui["battle-portrait"].src = sideRoot + (style ? "portrait-female.webp" : "portrait-male.webp");
  ui.battle.hidden = false;
  ui.overlay.hidden = true;
  ui.skill.lastElementChild.textContent = role.skill;
  ui["player-class"].textContent = role.names[style];
  ui.pause.focus({ preventScroll: true });
  ui.attack.dataset.glyph = ["sword", "bow", "spark"][role.sprite];
  ui.skill.dataset.glyph = ["slash", "fan", "sigil"][role.sprite];
  updateFightControls();
  startWave();
  updateHud();
  draw();
  playSound("start");
}

function startWave() {
  waveIndex += 1;
  const wave = waves[waveIndex];
  const composition = [];
  for (const type of Object.keys(monsters)) {
    for (let index = 0; index < (wave[type] || 0); index += 1) composition.push(type);
  }
  composition.forEach((type, i) => {
    const rank = Math.floor(i / 6);
    const rankSize = Math.min(6, composition.length - rank * 6);
    const boss = type === "sentinel";
    const x = stance.x + sectionX + (boss ? 218 : 219 + rank * 62 + i % 2 * 18);
    const y = stance.y + (boss ? 0 : (i % 6 - (rankSize - 1) / 2) * 39 + rank * 10);
    const base = monsters[type];
    const stats = { ...base, hp: Math.round(base.hp * (1 + (layerNumber - 1) * .10)),
      damage: Math.round(base.damage * (1 + (layerNumber - 1) * .07)) };
    enemies.push({
      x, y, type, stats, hp: stats.hp, hit: 0, attack: 0, spawn: .38 + i * .09,
      stride: i * .9, knockX: 0, knockY: 0, windup: 0
    });
  });
  ui.issuer.textContent = "第 " + layerNumber + " 层 · " + wave.issuer + "敕令 · " + (waveIndex + 1) + " / " + waves.length;
  ui.wave.textContent = wave.name;
  ui.remaining.textContent = composition.length;
  ui.patron.src = artRoot + "patron-" + waveIndex + ".webp";
  ui.objective.textContent = wave.order;
  announce(wave.order, 2.6);
  nextWave = null;
}

function announce(message, duration) {
  ui.callout.textContent = message;
  announcement = duration;
}

function updateMeter(id, value, max) {
  const meter = ui[id];
  meter.firstElementChild.style.width = value / max * 100 + "%";
  meter.setAttribute("aria-valuenow", String(value));
  meter.setAttribute("aria-valuemax", String(max));
}

function updateHud() {
  const { hp, maxHp, xp, level } = player;
  const threshold = level * 3 + 1;
  ui.kills.textContent = kills;
  ui.ash.textContent = ash;
  ui["health-text"].textContent = Math.ceil(hp) + " / " + maxHp;
  ui.level.textContent = "等级 " + level;
  ui["xp-text"].textContent = xp + " / " + threshold + " XP";
  updateMeter("health", Math.ceil(hp), maxHp);
  updateMeter("xp", xp, threshold);
}

function updateCooldown(button, remaining, readyLabel) {
  const label = remaining > 0 ? Math.ceil(remaining) + " 秒" : readyLabel;
  if (button.lastElementChild.textContent !== label) button.lastElementChild.textContent = label;
  button.disabled = remaining > 0 || nextWave !== null;
}

function pauseGame() {
  if (mode !== "battle") return;
  showResult("paused", "战斗暂停", "第 " + layerNumber + " 层 · 第 " + (waveIndex + 1) + " 波 · 已击杀 " + kills, "继续战斗");
}

function showResult(state, title, details, action) {
  mode = state;
  clearInput();
  ui["result-title"].textContent = title;
  ui["result-details"].textContent = details;
  ui.continue.textContent = action;
  ui.overlay.hidden = false;
  ui.pause.disabled = true;
  ui.continue.focus({ preventScroll: true });
}

function continueGame() {
  ui.pause.disabled = false;
  if (mode !== "paused") {
    begin();
    return;
  }
  ui.overlay.hidden = true;
  mode = "battle";
  ui.pause.focus({ preventScroll: true });
}

function returnToSelection() {
  mode = "selection";
  clearInput();
  ui.battle.hidden = true;
  ui.overlay.hidden = true;
  ui.pause.disabled = false;
  help.hidden = true;
  ui.selection.hidden = false;
  classButtons.find(button => button.dataset.class === selected).focus({ preventScroll: true });
}

function movement() {
  const keys = input.keys;
  let x = Number(keys.has("KeyD") || keys.has("ArrowRight")) - Number(keys.has("KeyA") || keys.has("ArrowLeft"));
  let y = Number(keys.has("KeyS") || keys.has("ArrowDown")) - Number(keys.has("KeyW") || keys.has("ArrowUp"));
  if ((x || y) && input.goal) input.goal = null;
  if (input.goal) {
    x = input.goal.x - player.x;
    y = input.goal.y - player.y;
    if (Math.hypot(x, y) < 5) {
      input.goal = null;
      return { x: 0, y: 0 };
    }
  }
  const magnitude = Math.hypot(x, y) || 1;
  return { x: x / magnitude, y: y / magnitude };
}

function nearestEnemy() {
  let nearest;
  let minimum = Infinity;
  for (const enemy of enemies) {
    if (enemy.spawn > 0 || enemy.hp <= 0) continue;
    const gap = distance(player, enemy);
    if (gap < minimum) {
      minimum = gap;
      nearest = enemy;
    }
  }
  return nearest;
}

function targetAt(fallbackDistance) {
  if (input.aiming && input.x > player.x + 5) return { x: input.x, y: input.y };
  return nearestEnemy() || { x: player.x + fallbackDistance, y: player.y };
}

function getAngle(target) {
  if (distance(player, target) < 1) return player.angle;
  return Math.atan2(target.y - player.y, target.x - player.x);
}

function hurt(enemy, damage, knock) {
  if (enemy.spawn > 0 || enemy.hp <= 0) return;
  enemy.hp -= damage;
  enemy.hit = .15;
  const angle = Math.atan2(enemy.y - player.y, enemy.x - player.x);
  const weight = enemy.type === "sentinel" ? .15 : 1;
  enemy.knockX += Math.cos(angle) * knock * weight;
  enemy.knockY += Math.sin(angle) * knock * weight;
  player.combo += 1;
  player.comboLeft = comboWindow;
  const stagger = player.combo % 3 - 1;
  popups.push({ x: enemy.x + stagger * 22, y: enemy.y - enemy.stats.size * .66,
    lift: Math.abs(stagger) * 16, text: String(damage), life: .6, color: "#ffdda5" });
  burst(enemy.x, enemy.y, "#efd29b", enemy.stats.size, "impact", .16);
  if (enemy.hp > 0) return;
  kills += 1;
  player.xp += enemy.type === "sentinel" ? 4 : 1;
  loot.push({ x: enemy.x, y: enemy.y, heal: kills % 4 === 0 || enemy.type === "sentinel", age: 0 });
  burst(enemy.x, enemy.y - 12, "#d28f58", 41);
  const threshold = player.level * 3 + 1;
  if (player.xp >= threshold) {
    player.xp -= threshold;
    player.level += 1;
    player.maxHp += 8;
    player.hp = Math.min(player.maxHp, player.hp + 27);
    burst(player.x, player.y, "#facd82", 60);
    announce("升至 " + player.level + " 级", 1.25);
    playSound("level");
  }
  updateHud();
}

function burst(x, y, color, radius, type = "ring", duration = .38) {
  effects.push({ type, x, y, color, radius, life: duration, maxLife: duration });
}

function fire(angle, damage, speed, reach, magic = false, empowered = false) {
  projectiles.push({
    x: player.x + Math.cos(angle) * 15, y: player.y + Math.sin(angle) * 15,
    angle, dx: Math.cos(angle) * speed, dy: Math.sin(angle) * speed,
    life: reach / speed, damage, magic, empowered, color: player.role.color
  });
}

function startMotion(kind, duration) {
  player.motion = { kind, duration, time: 0 };
}

function stepMotion(dt) {
  const motion = player.motion;
  if (!motion) return;
  const previous = motion.time;
  motion.time += dt;
  if (motion.kind === "attack") {
    const cues = player.role.sprite === 0 ? bladeCues : [attackRelease];
    cues.forEach((phase, index) => {
      const cue = phase * motion.duration;
      if (previous < cue && motion.time >= cue) releaseAttack(index);
    });
  }
  if (motion.time >= motion.duration) player.motion = null;
}

function attack(buffer = true, target = null) {
  if (mode !== "battle" || nextWave !== null) return;
  if (player.motion && player.motion.kind !== "hurt") {
    if (buffer && player.motion.kind !== "retreat") player.attackBuffer = .16;
    return;
  }
  const role = player.role;
  player.angle = getAngle(target ?? targetAt(role.reach));
  player.attackBuffer = 0;
  startMotion("attack", role.interval);
}

function releaseAttack(index) {
  const { role, angle } = player;
  const damage = role.damage + (player.level - 1) * 5;
  if (selected === "knight") {
    const final = index === bladeCues.length - 1;
    const life = final ? .24 : .15;
    effects.push({ type: "slash", x: player.x, y: player.y, angle, color: role.color,
      radius: role.reach, life, maxLife: life, stroke: index, final });
    const slice = Math.round(damage * bladeShares[index + 1]) - Math.round(damage * bladeShares[index]);
    for (const enemy of enemies) {
      const offset = Math.atan2(enemy.y - player.y, enemy.x - player.x) - angle;
      if (distance(player, enemy) < role.reach + enemy.stats.radius * .55 && Math.cos(offset) > -.05) {
        hurt(enemy, slice, final ? 99 : 8);
      }
    }
    playSound(final ? "slashFinish" : "slash");
  } else {
    fire(angle, damage, selected === "mage" ? 600 : 840, role.reach, selected === "mage");
    playSound("shot");
  }
}

function useSkill(target = null) {
  if (mode !== "battle" || nextWave !== null || player.skill > 0 || player.dodge > 0) return;
  const role = player.role;
  target ??= targetAt(145);
  const angle = getAngle(target);
  player.angle = angle;
  player.skill = role.cooldown;
  player.cutIn = .47;
  startMotion("skill", .34);
  const power = 63 + (player.level - 1) * 7;
  if (selected === "knight") {
    burst(player.x, player.y, role.color, 157, "seal", .47);
    enemies.forEach(enemy => {
      if (distance(player, enemy) < 157) hurt(enemy, power, 390);
    });
  } else if (selected === "ranger") {
    burst(player.x, player.y, role.color, 69, "seal", .38);
    for (const spread of [-.36, -.18, 0, .18, .36]) fire(angle + spread, Math.round(power * .73), 880, 530, false, true);
  } else {
    const reach = Math.min(distance(player, target), role.reach);
    const center = { x: player.x + Math.cos(angle) * reach, y: player.y + Math.sin(angle) * reach };
    burst(center.x, center.y, role.color, 135, "seal", .47);
    burst(center.x, center.y, "#f4d08c", 74, "thunder", .47);
    enemies.forEach(enemy => {
      if (distance(center, enemy) < 135) hurt(enemy, power + 13, 135);
    });
  }
  playSound("skill");
}

function dash() {
  if (mode !== "battle" || nextWave !== null || player.dash > 0) return;
  input.goal = null;
  player.attackBuffer = 0;
  player.dodge = .17;
  player.dash = 1.35;
  startMotion("retreat", .23);
  burst(player.x, player.y, "#d4c2a1", 39);
  playSound("dash");
}

function frontLimit(y) {
  let limit = footwork.right + sectionX;
  for (const enemy of enemies) {
    if (enemy.spawn > 0 || enemy.hp <= 0 || Math.abs(enemy.y - y) > enemy.stats.radius + 16) continue;
    limit = Math.min(limit, Math.max(player.x, enemy.x - enemy.stats.radius - 34));
  }
  return limit;
}

function stepPlayer(dt) {
  const { x, y } = player;
  let move = movement();
  const manualAttack = input.clickAttack || input.buttonAttack || input.keys.has("KeyJ");
  const assisted = controlMode !== 0 && !move.x && !move.y && !manualAttack;
  const target = assisted ? nearestEnemy() : null;
  const approach = assisted ? target ?? enemies[0] : null;
  if (approach && !player.motion) {
    const standoff = clamp(player.role.reach * .72, 60, 185);
    const diffY = approach.y - y;
    move = {
      x: clamp((approach.x - x - standoff) / 29, 0, 1),
      y: Math.sign(diffY) * clamp((Math.abs(diffY) - 6) / 26, 0, 1)
    };
  }
  if (controlMode === 2 && target?.windup > 0 && target.windup <= .15 && !player.dash && distance(target, player) < slamRange) dash();
  if (nextWave !== null) {
    player.x = Math.min(sectionX + stance.x + waveSpacing, x + dt * travelSpeed);
    player.y += (stance.y - y) * Math.min(1, dt * 8);
  } else if (player.dodge > 0) {
    player.x = Math.max(footwork.left + sectionX, x - Math.min(dt, player.dodge) * 300);
  } else {
    const step = player.role.speed * dt;
    player.y = clamp(y + move.y * step * .48, footwork.top, footwork.bottom);
    player.x = clamp(x + move.x * step, footwork.left + sectionX, move.x > 0 ? frontLimit(player.y) : footwork.right + sectionX);
  }
  const dx = player.x - x;
  const dy = player.y - y;
  const walkedDistance = Math.hypot(dx, dy);
  if (walkedDistance > .001 && !player.motion) {
    const stepX = dx / walkedDistance;
    const stepY = dy / walkedDistance;
    if (player.stepX * stepX + player.stepY * stepY < .5) player.stride = 0;
    player.stride += walkedDistance;
    player.stepX = stepX;
    player.stepY = stepY;
  } else {
    player.stride = 0;
  }
  for (const timer of ["skill", "dash", "hit", "dodge", "cutIn"]) player[timer] = Math.max(0, player[timer] - dt);
  player.attackBuffer = Math.max(0, player.attackBuffer - dt);
  player.comboLeft = Math.max(0, player.comboLeft - dt);
  if (!player.comboLeft) player.combo = 0;
  stepMotion(dt);
  if (target && !player.motion && distance(target, player) <= player.role.reach + target.stats.radius * .4) {
    if (controlMode === 2 && !player.skill) useSkill(target);
    else attack(false, target);
  } else if (manualAttack || (player.attackBuffer && !player.motion)) {
    attack(false);
  }
}

function damagePlayer(damage) {
  if (player.dodge > 0 || player.hit > 0) return;
  player.hit = .49;
  player.hp = Math.max(0, player.hp - damage);
  player.combo = 0;
  player.comboLeft = 0;
  player.attackBuffer = 0;
  startMotion("hurt", .22);
  burst(player.x, player.y, "#de6051", 34);
  playSound("hurt");
  updateHud();
}

const slamRange = 105;
function stepSentinel(enemy, gap, dt) {
  if (enemy.windup > 0) {
    enemy.windup = Math.max(0, enemy.windup - dt);
    if (enemy.windup === 0) {
      burst(enemy.x, enemy.y, "#e46e4b", slamRange);
      if (gap < slamRange) damagePlayer(enemy.stats.damage);
      enemy.attack = 1.25;
      playSound("skill");
    }
    return true;
  }
  if (gap < slamRange * .72 && enemy.attack <= 0) {
    enemy.windup = .65;
    return true;
  }
  return false;
}

function stepEnemies(dt) {
  for (const enemy of enemies) {
    if (enemy.hp <= 0) continue;
    if (enemy.spawn > 0) {
      enemy.spawn -= dt;
      continue;
    }
    const { stats } = enemy;
    const gap = distance(enemy, player);
    const angle = Math.atan2(player.y - enemy.y, player.x - enemy.x);
    const near = gap < stats.radius + 37;
    enemy.attack -= dt;
    enemy.hit = Math.max(0, enemy.hit - dt);
    const sentinel = enemy.type === "sentinel";
    const slamming = sentinel && stepSentinel(enemy, gap, dt);
    if (!near && !slamming) {
      enemy.x += Math.cos(angle) * stats.speed * dt;
      enemy.y += Math.sin(angle) * stats.speed * dt * .76;
      enemy.stride += dt * 12;
    }
    enemy.x += enemy.knockX * dt;
    enemy.y += enemy.knockY * dt;
    enemy.knockX *= Math.exp(-11 * dt);
    enemy.knockY *= Math.exp(-11 * dt);
    if (!sentinel && near && enemy.attack <= 0 && !player.dodge && !player.hit) {
      enemy.attack = .53;
      damagePlayer(stats.damage);
    }
  }
  for (let i = 0; i < enemies.length; i += 1) {
    const enemy = enemies[i];
    if (enemy.spawn > 0 || enemy.hp <= 0) continue;
    for (let j = i + 1; j < enemies.length; j += 1) {
      const other = enemies[j];
      if (other.spawn > 0 || other.hp <= 0) continue;
      const gap = distance(other, enemy);
      const separation = (enemy.stats.radius + other.stats.radius) * .87;
      if (gap >= separation) continue;
      const angle = Math.atan2(other.y - enemy.y, other.x - enemy.x);
      const displacement = (separation - gap) * Math.min(1, dt * 6);
      const dx = Math.cos(angle) * displacement;
      const dy = Math.sin(angle) * displacement;
      enemy.x -= dx;
      enemy.y -= dy;
      other.x += dx;
      other.y += dy;
    }
  }
  for (const enemy of enemies) {
    const minimum = player.x + enemy.stats.radius + 32;
    enemy.x = clamp(enemy.x, minimum, bounds.right + sectionX + 10);
    enemy.y = clamp(enemy.y, bounds.top, bounds.bottom);
  }
  enemies = enemies.filter(enemy => enemy.hp > 0);
}

function stepProjectiles(dt) {
  for (const shot of projectiles) {
    shot.x += shot.dx * dt;
    shot.y += shot.dy * dt;
    shot.life -= dt;
    const hit = enemies.find(enemy => enemy.spawn <= 0 && enemy.hp > 0 && distance(enemy, shot) < enemy.stats.radius + (shot.magic ? 8 : 3));
    if (hit) {
      hurt(hit, shot.damage, shot.magic ? 105 : 60);
      burst(shot.x, shot.y - 13, shot.color, 24);
      shot.life = 0;
    }
  }
  projectiles = projectiles.filter(shot => shot.life > 0);
}

function stepLoot(dt) {
  for (const drop of loot) {
    drop.age += dt;
    const gap = distance(player, drop);
    if (gap < 19) {
      drop.collected = true;
      ash += drop.heal ? 3 : 1;
      if (drop.heal) player.hp = Math.min(player.maxHp, player.hp + 24);
      playSound("pickup");
      updateHud();
    } else if (gap < 95 || nextWave !== null) {
      const pull = Math.min(1, dt * (nextWave !== null ? 7 : 11));
      drop.x += (player.x - drop.x) * pull;
      drop.y += (player.y - drop.y) * pull;
    }
  }
  loot = loot.filter(drop => !drop.collected);
}

function advance(dt) {
  stepPlayer(dt);
  stepProjectiles(dt);
  stepEnemies(dt);
  stepLoot(dt);
  for (const effect of effects) effect.life -= dt;
  for (const popup of popups) {
    popup.life -= dt;
    popup.y -= 30 * dt;
  }
  effects = effects.filter(effect => effect.life > 0);
  popups = popups.filter(popup => popup.life > 0);
  if (announcement > 0) {
    announcement -= dt;
    if (announcement <= 0) ui.callout.textContent = "";
  }
  updateCooldown(ui.skill, player.skill, player.role.skill);
  updateCooldown(ui.dash, player.dash, "后撤");
  ui.attack.disabled = nextWave !== null;
  const summary = "击杀 " + kills + " · 收集灵砂 " + ash;
  if (player.hp <= 0) {
    showResult("defeat", "山门失守", summary, "重新挑战");
    return;
  }
  ui.remaining.textContent = enemies.length;
  if (enemies.length > 0) return;
  if (nextWave === null) {
    const destination = sectionX + stance.x + waveSpacing;
    nextWave = Math.max(.58, (destination - player.x) / travelSpeed);
    player.angle = 0;
    player.motion = null;
    player.stride = 0;
    player.attackBuffer = 0;
    player.dodge = 0;
    input.goal = null;
    input.aiming = false;
    projectiles = [];
    announce(waveIndex + 1 === waves.length ? "第 " + layerNumber + " 层已通关" : "前往下一波", nextWave);
  }
  if (player.x >= sectionX + stance.x + waveSpacing) {
    sectionX += waveSpacing;
    player.y = stance.y;
    player.stride = 0;
    if (waveIndex + 1 === waves.length) {
      layerNumber += 1;
      waveIndex = -1;
      player.hp = player.maxHp;
      playSound("level");
    }
    startWave();
    updateHud();
  }
}

function ellipse(x, y, width, height, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.ellipse(x, y, width, height, 0, 0, Math.PI * 2);
  ctx.fill();
}

const pixelSize = 3;
const snap = value => Math.round(value / pixelSize) * pixelSize;

function pixel(x, y, size, color) {
  ctx.fillStyle = color;
  ctx.fillRect(snap(x), snap(y), size, size);
}

function drawArc(x, y, rx, ry, start, sweep, size, color) {
  ctx.strokeStyle = color;
  ctx.lineWidth = size;
  ctx.lineCap = "round";
  ctx.beginPath();
  ctx.ellipse(x, y, rx, ry, 0, start, start + sweep);
  ctx.stroke();
}

function playerFrame(motion, phase) {
  if (!motion) return 0;
  if (motion.kind === "hurt") return phase < .72 ? 9 : 0;
  if (motion.kind === "retreat") return phase >= .14 && phase < .86 ? 8 : 3;
  if (motion.kind === "skill") return phase < .74 ? 10 : 7;
  if (player.role.sprite === 0) {
    let stroke = bladeCues.length - 1;
    while (stroke >= 0 && phase < bladeCues[stroke]) stroke -= 1;
    if (stroke < 0) return 4;
    const next = bladeCues[stroke + 1] ?? 1;
    const beat = (phase - bladeCues[stroke]) / (next - bladeCues[stroke]);
    if (beat > .72) return next === 1 ? 7 : 4;
    return stroke % 2 === 0 ? 5 : 6;
  }
  if (phase < .14) return 3;
  if (phase < attackRelease) return 4;
  if (phase < .56) return 5;
  return phase < .78 ? 6 : 7;
}

function drawWeapon(frame) {
  const [handX, handY] = grip[frame];
  const x = handX - 47;
  const y = handY - 89;
  ctx.beginPath();
  if (player.role.sprite === 1) {
    ctx.strokeStyle = "#c4a87d";
    ctx.lineWidth = 2;
    ctx.moveTo(x + 2, y - 15);
    ctx.quadraticCurveTo(x + 15, y, x + 1, y + 15);
    ctx.stroke();
    ctx.beginPath();
    ctx.strokeStyle = "#c5baa2";
    ctx.lineWidth = 1;
    ctx.moveTo(x + 2, y - 15);
    ctx.lineTo(x - (frame === 4 ? 10 : 0), y);
    ctx.lineTo(x + 1, y + 15);
    ctx.stroke();
    return;
  }
  const angle = bladeAngles[frame];
  const dx = Math.cos(angle);
  const dy = Math.sin(angle);
  const staff = player.role.sprite === 2;
  ctx.lineWidth = staff ? 3 : 2;
  ctx.strokeStyle = "#775c46";
  ctx.moveTo(x - dx * (staff ? 16 : 5), y - dy * (staff ? 16 : 5));
  ctx.lineTo(x + dx * (staff ? 24 : 5), y + dy * (staff ? 24 : 5));
  ctx.stroke();
  if (staff) {
    ellipse(x + dx * 24, y + dy * 24, 3.8, 3.8, "#c8b6e0");
    return;
  }
  ctx.beginPath();
  ctx.fillStyle = "#dfcfad";
  ctx.moveTo(x + dx * 5 + dy, y + dy * 5 - dx);
  ctx.lineTo(x + dx * 28, y + dy * 28);
  ctx.lineTo(x + dx * 5 - dy * 2, y + dy * 5 + dx * 2);
  ctx.closePath();
  ctx.fill();
}

function drawEntity(entity, isPlayer) {
  const { x, hit, stride } = entity;
  const y = floorY(entity.y);
  const size = isPlayer ? (portrait.matches ? 106 : 134) : entity.stats.size * foeSpriteScale;
  const motion = isPlayer ? entity.motion : null;
  const phase = motion ? motion.time / motion.duration : 0;
  let frame = isPlayer ? playerFrame(motion, phase) : 0;
  const striking = [5, 6, 10].includes(frame);
  const sprite = isPlayer ? actors[style] : foes[entity.stats.sprite - 3];
  const isBoss = entity.type === "sentinel";
  ellipse(x, y + 1, size * .24, size * .042, "#1f304672");
  let facing = isPlayer ? (Math.cos(player.angle) >= 0 ? 1 : -1) : (entity.x > player.x ? -1 : 1);
  let runLean = 0;
  let legShear = 0;
  let legRise = 0;
  const walking = isPlayer && !motion && stride > 0;
  const knee = 70;
  if (walking) {
    if (Math.abs(entity.stepX) > .15) facing = Math.sign(entity.stepX);
    const running = nextWave !== null;
    const spriteScale = size / 73;
    const stepLength = (running ? 33 : 22) * spriteScale;
    const steps = stride / stepLength;
    const stepPhase = steps % 1;
    const plant = (.5 - stepPhase) * stepLength;
    frame = stepPhase < .29 ? 1 : stepPhase < .70 ? 11 : 2;
    runLean = running && !reduceMotion ? .11 : 0;
    const [soleX, soleY] = soles[style][frame];
    const localX = entity.stepX * plant * facing / spriteScale;
    const localY = entity.stepY * stageDepth * plant / spriteScale;
    legShear = (localX * Math.cos(runLean) + localY * Math.sin(runLean) - (soleX - 47)) / (soleY - knee);
    legRise = (-localX * Math.sin(runLean) + localY * Math.cos(runLean) - (soleY - 89)) / (soleY - knee);
    if (running && !reduceMotion) {
      for (let i = 0; i < 3 && steps >= i; i += 1) {
        const age = (stepPhase + i) / 3;
        const stampX = x + entity.stepX * (plant - i * stepLength);
        const stampY = y + entity.stepY * stageDepth * (plant - i * stepLength);
        ellipse(stampX, stampY + 1.4, 6, 2, `rgba(88,113,141,${.3 * (1 - age)})`);
        ellipse(stampX - age * 14, stampY - Math.sin(age * Math.PI) * 7, 2.2 - age, 2.2 - age,
          `rgba(242,247,255,${.66 * (1 - age)})`);
      }
    }
  }
  ctx.save();
  ctx.imageSmoothingEnabled = false;
  const bounce = reduceMotion || isPlayer ? 0 : Math.floor(stride) % 2 * 2;
  const lunge = striking && !reduceMotion ? 9 : 0;
  const lean = !reduceMotion && entity.windup > 0 ? -6 : 0;
  ctx.translate(x + (lunge + lean) * facing, y - bounce);
  ctx.scale(facing, 1);
  if (runLean) ctx.rotate(runLean);
  if (!isPlayer && hit > .04) {
    const flash = Math.pow(clamp((hit - .04) / .11, 0, 1), 1.7);
    ctx.filter = `brightness(${1 + flash * .62})`;
  } else if (motion?.kind === "hurt" && motion.time < .07) {
    ctx.filter = "brightness(1.35)";
  }
  if (sprite.complete && sprite.naturalWidth) {
    if (isPlayer) {
      ctx.scale(size / 73, size / 73);
      const sx = frame % 4 * 96;
      const sy = Math.floor(frame / 4) * 96;
      if ((player.dodge > 0 || striking) && !reduceMotion) {
        ctx.globalAlpha = .23;
        ctx.drawImage(sprite, sx, sy, 96, 96, -47 + (player.dodge > 0 ? 12 : -10), -89, 96, 96);
        ctx.globalAlpha = 1;
      }
      if (walking) {
        ctx.drawImage(sprite, sx, sy, 96, knee, -47, -89, 96, knee);
        ctx.save();
        ctx.translate(0, knee - 89);
        ctx.transform(1, 0, legShear, 1 + legRise, 0, 0);
        ctx.drawImage(sprite, sx, sy + knee, 96, 96 - knee, -47, 0, 96, 96 - knee);
        ctx.restore();
      } else {
        ctx.drawImage(sprite, sx, sy, 96, 96, -47, -89, 96, 96);
      }
      drawWeapon(frame);
    } else {
      const width = Math.round(sprite.naturalWidth * size / sprite.naturalHeight);
      ctx.drawImage(sprite, -width / 2, -size + 2, width, size);
    }
  } else {
    const color = isPlayer ? player.role.color : ["#d4cab0", "#9b8389", "#bd8877"][entity.stats.sprite - 3];
    ellipse(0, -size * .34, size * .23, size * .32, "#242120");
    ellipse(0, -size * .57, size * .14, size * .13, color);
    ctx.fillStyle = color;
    ctx.fillRect(-size * .2, -size * .43, size * .4, size * .14);
    ctx.fillRect(size * .23, -size * .43, size * .06, size * .41);
  }
  ctx.restore();
  if (!isPlayer && (hit > 0 || isBoss)) {
    const width = isBoss ? 76 : 37;
    const top = y - size - 8;
    ctx.fillStyle = "#201628";
    ctx.fillRect(x - width / 2 - 1, top - 1, width + 2, 6);
    ctx.fillStyle = isBoss ? "#ffd07a" : "#ff637f";
    ctx.fillRect(x - width / 2, top, width * clamp(entity.hp / entity.stats.hp, 0, 1), 4);
  }
}

function drawEffect(effect) {
  const progress = 1 - effect.life / effect.maxLife;
  const ground = floorY(effect.y);
  ctx.save();
  ctx.globalAlpha = 1 - progress;
  if (effect.type === "slash") {
    const direction = Math.cos(effect.angle) < 0 ? -1 : 1;
    const slant = effect.stroke % 2 ? 1 : -1;
    const radius = effect.radius * (.52 + progress * .37) * (effect.final ? 1.13 : 1);
    const height = radius * (effect.final ? .75 : .55);
    ctx.translate(effect.x + direction * 10, ground - 47 + slant * 12);
    ctx.scale(direction, 1);
    ctx.rotate(slant * .50);
    ctx.beginPath();
    for (let rim = 0; rim < 2; rim += 1) {
      for (let i = 0; i <= 22; i += 1) {
        const t = (rim ? 22 - i : i) / 22;
        const angle = -1.04 + 2.16 * t;
        const inset = rim * (.65 + Math.sin(t * Math.PI) * (effect.final ? 16 : 9));
        ctx.lineTo(Math.cos(angle) * (radius - inset), Math.sin(angle) * (height - inset));
      }
    }
    ctx.closePath();
    ctx.fillStyle = effect.color;
    ctx.fill();
    drawArc(0, 0, radius, height, -.76, 1.46, 2.7, "#fff4df");
    for (let i = 0; i < 7; i += 1) {
      pixel(radius * (.70 + progress) + i * 5, (i - 3) * 12 + progress * 9, i % 2 ? 3 : 2, "#ffd19a");
    }
  } else if (effect.type === "impact") {
    const center = ground - effect.radius * .66;
    ctx.strokeStyle = effect.color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    for (let i = 0; i < 7; i += 1) {
      const angle = i * Math.PI * 2 / 7 + effect.radius;
      const ray = (14 + i % 3 * 5 + progress * 20);
      ctx.moveTo(effect.x + Math.cos(angle) * ray * .40, center + Math.sin(angle) * ray * .40);
      ctx.lineTo(effect.x + Math.cos(angle) * ray, center + Math.sin(angle) * ray);
    }
    ctx.stroke();
  } else if (effect.type === "seal") {
    const radius = effect.radius * (.48 + .52 * progress);
    drawArc(effect.x, ground, radius, radius * .2, 0, Math.PI * 2, 3, effect.color);
    drawArc(effect.x, ground, radius * .77, radius * .16, 0, Math.PI * 2, 1.5, "#ffedbf");
    for (let i = 0; i < 5; i += 1) {
      const angle = i * Math.PI * .4;
      drawTalisman(effect.x + Math.cos(angle) * radius, ground + Math.sin(angle) * radius * .17 - 22 - progress * 58, effect.color);
    }
  } else if (effect.type === "thunder") {
    ctx.lineJoin = "round";
    ctx.strokeStyle = effect.color;
    for (let i = 0; i < 5; i++) {
      const offset = (i - 2) * effect.radius * .48;
      const x = effect.x + offset;
      const y = ground - Math.abs(offset) * .18;
      ctx.beginPath();
      ctx.moveTo(effect.x + offset * .65, y - 118);
      ctx.lineTo(x - 8, y - 59);
      ctx.lineTo(x + 8, y - 64);
      ctx.lineTo(x, y);
      ctx.strokeStyle = "#a279ef88";
      ctx.lineWidth = 8;
      ctx.stroke();
      ctx.strokeStyle = effect.color;
      ctx.lineWidth = 2.5;
      ctx.stroke();
    }
  } else {
    const radius = effect.radius * (.25 + .75 * progress);
    drawArc(effect.x, ground, radius, radius * .21, 0, Math.PI * 2, 2, effect.color);
    for (let i = 0; i < 10; i += 1) {
      const angle = i * Math.PI / 5;
      const x = effect.x + radius * 1.07 * Math.cos(angle);
      const y = ground + radius * .23 * Math.sin(angle) - progress * 10;
      pixel(x, y, i % 2 ? 3 : 6, i % 2 ? "#fff1cf" : effect.color);
    }
  }
  ctx.restore();
}

function drawTalisman(x, y, color) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(.18);
  ctx.fillStyle = color;
  ctx.fillRect(-4, -12, 8, 24);
  ctx.fillStyle = "#9f3829";
  ctx.fillRect(-1, -7, 2, 13);
  ctx.fillRect(-3, -4, 6, 2);
  ctx.fillRect(-3, 1, 6, 2);
  ctx.restore();
}

function drawBackdrop(time) {
  ctx.fillStyle = "#394851";
  ctx.fillRect(0, 0, W, H);
  if (crypt.complete && crypt.naturalWidth) {
    const depth = Math.max(stageFloor / snowFloor, (H - stageFloor) / (1 - snowFloor));
    const scale = Math.max((W + 310) / softBackdrop.width, depth / softBackdrop.height);
    const width = softBackdrop.width * scale;
    const height = softBackdrop.height * scale;
    const route = (waveIndex * waveSpacing + (cameraPosition() - sectionX)) / (waves.length * waveSpacing);
    const travel = reduceMotion ? .50 : clamp(route, 0, 1);
    ctx.drawImage(softBackdrop, (W - width) * travel, stageFloor - height * snowFloor, width, height);
  }

  const mistY = H * (.48 + Math.sin(time * .33) * .018);
  const mist = ctx.createLinearGradient(0, mistY - 68, 0, mistY + 68);
  mist.addColorStop(0, "#acb8c500");
  mist.addColorStop(.5, "#acb8c516");
  mist.addColorStop(1, "#acb8c500");
  ctx.fillStyle = mist;
  ctx.fillRect(0, mistY - 68, W, 136);

  const edge = ctx.createRadialGradient(W / 2, H * .43, H * .22, W / 2, H * .43, W * .59);
  edge.addColorStop(0, "#16141900");
  edge.addColorStop(1, "#121e3152");
  ctx.fillStyle = edge;
  ctx.fillRect(0, 0, W, H);
}

function drawSnow(time) {
  ctx.save();
  for (let i = 0; i < 35; i += 1) {
    const u = ((i * .618 - snowDrift * (1 + i % 4 * .25)) % 1 + 1) % 1;
    const y = H * ((i * .346 + time * (.042 + i % 3 * .012)) % 1);
    const large = i % 4 === 0;
    const x = W * u;
    ctx.globalAlpha = Math.sin(u * Math.PI) * (large ? .47 : .27);
    if (nextWave !== null && !reduceMotion && i % 3 === 0) {
      ctx.strokeStyle = "#e5f5ff";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + 20 + (i % 5) * 11, y - 3);
      ctx.stroke();
    } else {
      ellipse(x, y, large ? 1.6 : .9, large ? 1.6 : .9, "#e5f5ff");
    }
  }
  ctx.restore();
}

function cameraPosition() {
  return nextWave === null ? sectionX : clamp(player.x - stance.x, sectionX, sectionX + waveSpacing);
}

function draw(now = 0) {
  ctx.setTransform(1, 0, 0, 1, -viewLeft, 0);
  ctx.imageSmoothingEnabled = true;
  const time = reduceMotion ? 0 : now / 1000;
  drawBackdrop(time);
  ctx.translate(-cameraPosition(), 0);

  for (const enemy of enemies) {
    const ground = floorY(enemy.y);
    if (enemy.windup > 0) {
      ellipse(enemy.x, ground, slamRange, slamRange * stageDepth, "#d950453d");
      drawArc(enemy.x, ground, slamRange, slamRange * stageDepth, 0, Math.PI * 2, 2, "#a23247");
    }
    if (enemy.spawn > 0 && enemy.spawn < .75) {
      const size = 13 + 17 * enemy.spawn;
      ellipse(enemy.x, ground, size, size * .16, "#202a39ad");
      drawArc(enemy.x, ground, size, size * .16, 0, Math.PI * 2, 1.5, "#b6c5d3");
    }
  }
  for (const drop of loot) {
    const ground = floorY(drop.y);
    const y = ground - 9 + (reduceMotion ? 0 : Math.floor(drop.age * 5) % 2 * 3);
    const color = drop.heal ? "#80ffc1" : "#ffbd68";
    ellipse(drop.x, ground + 1, 9, 3, "#1d152a95");
    pixel(drop.x - 3, y - 6, 6, color);
    pixel(drop.x - 6, y, 12, color);
    pixel(drop.x - 3, y + 9, 6, color);
    pixel(drop.x - 3, y, 6, "#fff2d4");
  }
  if (input.goal) ellipse(input.goal.x, floorY(input.goal.y), 7, 2, "#e3cb9d92");

  const active = enemies.filter(enemy => enemy.spawn <= 0);
  active.push(player);
  active.sort((a, b) => a.y - b.y);
  active.forEach(entity => drawEntity(entity, entity === player));

  for (const shot of projectiles) {
    const dx = Math.cos(shot.angle) * 3;
    const dy = Math.sin(shot.angle) * 3 * stageDepth;
    if (shot.empowered) {
      ctx.strokeStyle = shot.color;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(shot.x - dx * 18, floorY(shot.y) - 36 - dy * 18);
      ctx.lineTo(shot.x, floorY(shot.y) - 36);
      ctx.stroke();
    }
    for (let i = 7; i >= 0; i -= 1) {
      pixel(shot.x - dx * i, floorY(shot.y) - 36 - dy * i, shot.magic && i < 3 ? 9 : 3, i < 2 ? "#fff4dc" : shot.color);
    }
  }
  effects.forEach(drawEffect);
  ctx.textAlign = "center";
  ctx.font = "bold 20px ui-monospace, monospace";
  for (const popup of popups) {
    ctx.globalAlpha = clamp(popup.life * 3, 0, 1);
    ctx.strokeStyle = "#1e1109";
    ctx.lineWidth = 3;
    const y = floorY(popup.y) - 36 - (popup.lift ?? 0);
    ctx.strokeText(popup.text, snap(popup.x), snap(y));
    ctx.fillStyle = popup.color;
    ctx.fillText(popup.text, snap(popup.x), snap(y));
  }
  ctx.globalAlpha = 1;
  ctx.setTransform(1, 0, 0, 1, -viewLeft, 0);
  drawSnow(time);
  if (player.combo >= 2 && nextWave === null) {
    const x = viewLeft + ui.arena.width * .88;
    const y = stageFloor - 143;
    ctx.globalAlpha = Math.min(1, player.comboLeft / .33);
    ctx.textAlign = "right";
    ctx.font = 'bold 31px "Microsoft YaHei", sans-serif';
    ctx.strokeStyle = "#1a1113";
    ctx.lineWidth = 4;
    ctx.strokeText(player.combo + " 连击", x, y);
    ctx.fillStyle = "#ffd697";
    ctx.fillText(player.combo + " 连击", x, y);
    ctx.globalAlpha = 1;
  }
  const portraitImage = ui["battle-portrait"];
  if (!reduceMotion && nextWave === null && player.cutIn > 0 && portraitImage.naturalWidth) {
    const alpha = Math.min(1, (.47 - player.cutIn) / .05, player.cutIn / .19);
    const width = ui.arena.width * .18;
    const height = width * portraitImage.naturalHeight / portraitImage.naturalWidth;
    ctx.globalAlpha = alpha * .9;
    ctx.drawImage(portraitImage, viewLeft + 14 - (1 - alpha) * 25, stageFloor - height * .80, width, height);
    ctx.globalAlpha = 1;
  }
}

const sounds = {
  start: [146, 98, .4, "sine", .095], slash: [730, 164, .09, "triangle", .10],
  slashFinish: [290, 61, .18, "triangle", .15],
  shot: [480, 118, .15, "triangle", .08], hurt: [119, 49, .19, "sawtooth", .07],
  dash: [230, 108, .18, "sine", .09], skill: [90, 46, .43, "triangle", .17],
  pickup: [480, 715, .09, "sine", .07], level: [330, 660, .35, "sine", .09]
};

function playSound(name) {
  if (muted || !audio || audio.state !== "running") return;
  const [first, last, duration, type, level] = sounds[name];
  const start = audio.currentTime;
  const oscillator = audio.createOscillator();
  const gain = audio.createGain();
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(first, start);
  oscillator.frequency.exponentialRampToValueAtTime(last, start + duration);
  gain.gain.setValueAtTime(.001, start);
  gain.gain.exponentialRampToValueAtTime(level, start + .018);
  gain.gain.exponentialRampToValueAtTime(.001, start + duration);
  oscillator.connect(gain);
  gain.connect(audio.destination);
  oscillator.start(start);
  oscillator.stop(start + duration);
}

function aimAt(event) {
  const rect = ui.arena.getBoundingClientRect();
  input.x = cameraPosition() + viewLeft + (event.clientX - rect.left) / rect.width * ui.arena.width;
  const screenY = (event.clientY - rect.top) / rect.height * H;
  if (event.pointerType !== "touch") {
    const target = enemies.find(enemy => enemy.spawn <= 0 && Math.abs(enemy.x - input.x) < enemy.stats.size * foeSpriteScale * .48 &&
      screenY >= floorY(enemy.y) - enemy.stats.size * foeSpriteScale && screenY <= floorY(enemy.y) + 6);
    input.y = target?.y ?? player.y;
    return;
  }
  input.y = stance.y + (screenY - stageFloor) / stageDepth;
}

ui.arena.addEventListener("pointermove", event => {
  if (mode !== "battle" || event.pointerType === "touch") return;
  aimAt(event);
  input.aiming = true;
});
ui.arena.addEventListener("pointerleave", () => {
  if (!input.clickAttack) input.aiming = false;
});
ui.arena.addEventListener("pointerdown", event => {
  if (mode !== "battle" || nextWave !== null || !event.isPrimary || event.button !== 0) return;
  aimAt(event);
  if (event.pointerType === "touch") {
    input.aiming = false;
    input.goal = { x: clamp(input.x, footwork.left + sectionX, footwork.right + sectionX),
      y: clamp(input.y, footwork.top, footwork.bottom) };
  } else {
    input.aiming = true;
    input.clickAttack = true;
    ui.arena.setPointerCapture(event.pointerId);
    attack();
  }
});
function stopPointerAttack() {
  input.clickAttack = false;
}
ui.arena.addEventListener("pointerup", stopPointerAttack);
ui.arena.addEventListener("pointercancel", stopPointerAttack);
ui.arena.addEventListener("lostpointercapture", stopPointerAttack);

ui.attack.addEventListener("pointerdown", event => {
  if (!event.isPrimary || event.button !== 0) return;
  input.aiming = false;
  input.buttonAttack = true;
  ui.attack.setPointerCapture(event.pointerId);
  attack();
});
for (const type of ["pointerup", "pointercancel", "lostpointercapture"]) {
  ui.attack.addEventListener(type, () => { input.buttonAttack = false; });
}
ui.attack.addEventListener("click", event => {
  if (event.detail === 0) attack();
});

styleButtons.forEach(button => button.addEventListener("click", () => {
  style = Number(button.dataset.style);
  styleButtons.forEach(item => item.setAttribute("aria-pressed", String(item === button)));
  select(selected);
}));
select(selected);
classButtons.forEach(button => button.addEventListener("click", () => select(button.dataset.class)));
ui.start.addEventListener("click", begin);
ui.pause.addEventListener("click", pauseGame);
ui.continue.addEventListener("click", continueGame);
ui.leave.addEventListener("click", returnToSelection);
ui.skill.addEventListener("click", () => useSkill());
ui.dash.addEventListener("click", dash);
ui["fight-mode"].addEventListener("click", cycleControlMode);
ui["fight-speed"].addEventListener("click", cycleBattleSpeed);
ui.sound.addEventListener("click", async () => {
  if (muted) {
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) {
      ui.sound.textContent = "音效不可用";
      return;
    }
    audio ||= new Audio();
    try {
      await audio.resume();
    } catch {
      ui.sound.textContent = "音效不可用";
      return;
    }
  }
  muted = !muted;
  ui.sound.textContent = muted ? "音效关闭" : "音效开启";
  ui.sound.setAttribute("aria-pressed", String(!muted));
  playSound("pickup");
});

window.addEventListener("keydown", event => {
  if (mode === "selection" && (event.code === "ArrowLeft" || event.code === "ArrowRight")) {
    const shift = event.code === "ArrowLeft" ? -1 : 1;
    const i = classButtons.findIndex(button => button.dataset.class === selected);
    const next = classButtons[(i + shift + classButtons.length) % classButtons.length];
    event.preventDefault();
    select(next.dataset.class);
    next.focus();
    return;
  }
  if (!gameKeys.has(event.code) || (mode !== "battle" && mode !== "paused")) return;
  if (event.code === "Space" && [ui.sound, ui.continue, ui.leave, ui["fight-mode"], ui["fight-speed"]].includes(document.activeElement)) return;
  event.preventDefault();
  if (event.code === "Escape" && !event.repeat) {
    if (mode === "paused") continueGame();
    else pauseGame();
    return;
  }
  if (mode !== "battle") return;
  input.keys.add(event.code);
  if (event.code === "KeyJ" && !event.repeat) attack();
  if (event.code === "KeyQ" && !event.repeat) useSkill();
  if (event.code === "KeyM" && !event.repeat) cycleControlMode();
  if (event.code === "KeyV" && !event.repeat) cycleBattleSpeed();
  if (event.code === "Space" && !event.repeat) dash();
});
window.addEventListener("keyup", event => input.keys.delete(event.code));
window.addEventListener("blur", () => {
  clearInput();
  if (mode === "battle" && !coarsePointer) pauseGame();
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden) pauseGame();
});
portrait.addEventListener("change", resizeArena);
resizeArena();

function frame(now) {
  const dt = Math.min(.033, (now - (lastFrame || now)) / 1000);
  lastFrame = now;
  if (mode === "battle") {
    for (let tick = 0; tick < battleSpeed && mode === "battle"; tick += 1) advance(dt);
    if (!reduceMotion) snowDrift = (snowDrift + dt * (nextWave === null ? .06 : .42)) % 4;
    draw(now);
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
