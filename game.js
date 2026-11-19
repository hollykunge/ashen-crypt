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
const artRoot = "mobile/art/immortals/";
function artwork(file) {
  const image = new Image();
  image.src = artRoot + file + ".webp";
  return image;
}
const actors = Array.from({ length: 6 }, (_, i) => ({
  ready: artwork("ready-" + i), strike: artwork("strike-" + i)
}));
const foes = ["shanxiao", "fire-fox", "guardian"].map(artwork);
const attackRelease = 2 / 6;
crypt.src = artRoot + "battle-terrace.webp";
const styleButtons = [...document.querySelectorAll("[data-style]")];
const help = document.querySelector("footer");
let style = 0;

const input = {
  keys: new Set(), aiming: false, x: 0, y: 0, clickAttack: false,
  buttonAttack: false, goal: null
};
const gameKeys = new Set(["KeyW", "KeyA", "KeyS", "KeyD", "ArrowUp", "ArrowLeft", "ArrowDown", "ArrowRight", "KeyJ", "KeyQ", "Space", "Escape"]);
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
let announcement;
let kills;
let ash;
let lastFrame = 0;
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
    for (const entity of [player, ...enemies, ...loot]) entity.x = clamp(entity.x, bounds.left, bounds.right);
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
}

function begin() {
  clearInput();
  const role = roles[selected];
  player = {
    ...stance, role, hp: role.hp, maxHp: role.hp, level: 1, xp: 0,
    angle: 0, skill: 0, dash: 0, hit: 0, dodge: 0, motion: null, stride: 0
  };
  enemies = [];
  projectiles = [];
  loot = [];
  effects = [];
  popups = [];
  waveIndex = -1;
  kills = 0;
  ash = 0;
  mode = "battle";
  help.hidden = false;
  ui.selection.hidden = true;
  ui.battle.hidden = false;
  ui.overlay.hidden = true;
  ui.skill.lastElementChild.textContent = role.skill;
  ui["player-class"].textContent = role.names[style];
  ui.pause.focus({ preventScroll: true });
  ui.attack.dataset.glyph = ["sword", "bow", "spark"][role.sprite];
  ui.skill.dataset.glyph = ["slash", "fan", "sigil"][role.sprite];
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
    const x = stance.x + (boss ? 218 : 219 + rank * 62 + i % 2 * 18);
    const y = stance.y + (boss ? 0 : (i % 6 - (rankSize - 1) / 2) * 39 + rank * 10);
    const stats = monsters[type];
    enemies.push({
      x, y, type, stats, hp: stats.hp, hit: 0, attack: 0, spawn: .38 + i * .09,
      stride: i * .9, knockX: 0, knockY: 0, windup: 0
    });
  });
  ui.issuer.textContent = wave.issuer + "敕令 · " + (waveIndex + 1) + " / " + waves.length;
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
  button.disabled = remaining > 0;
}

function pauseGame() {
  if (mode !== "battle") return;
  showResult("paused", "战斗暂停", "第 " + (waveIndex + 1) + " 波 · 已击杀 " + kills, "继续战斗");
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
  popups.push({ x: enemy.x, y: enemy.y - enemy.stats.size * .66, text: String(damage), life: .6, color: "#ffdda5" });
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

function burst(x, y, color, radius, type = "ring") {
  effects.push({ type, x, y, color, radius, life: .38, maxLife: .38 });
}

function fire(angle, damage, speed, reach, magic = false) {
  projectiles.push({
    x: player.x + Math.cos(angle) * 15, y: player.y + Math.sin(angle) * 15,
    angle, dx: Math.cos(angle) * speed, dy: Math.sin(angle) * speed,
    life: reach / speed, damage, magic, color: player.role.color
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
  const cue = motion.duration * attackRelease;
  if (motion.kind === "attack" && previous < cue && motion.time >= cue) releaseAttack();
  if (motion.time >= motion.duration) player.motion = null;
}

function attack() {
  if (mode !== "battle" || player.motion) return;
  const role = player.role;
  player.angle = getAngle(targetAt(role.reach));
  startMotion("attack", role.interval);
}

function releaseAttack() {
  const { role, angle } = player;
  const damage = role.damage + (player.level - 1) * 5;
  if (selected === "knight") {
    effects.push({ type: "slash", x: player.x, y: player.y, angle, color: role.color, radius: role.reach, life: .19, maxLife: .19 });
    for (const enemy of enemies) {
      const offset = Math.atan2(enemy.y - player.y, enemy.x - player.x) - angle;
      if (distance(player, enemy) < role.reach + enemy.stats.radius * .55 && Math.cos(offset) > -.05) hurt(enemy, damage, 115);
    }
  } else {
    fire(angle, damage, selected === "mage" ? 600 : 840, role.reach, selected === "mage");
  }
  playSound(selected === "knight" ? "slash" : "shot");
}

function useSkill() {
  if (mode !== "battle" || player.skill > 0 || player.dodge > 0) return;
  const role = player.role;
  const target = targetAt(145);
  const angle = getAngle(target);
  player.angle = angle;
  player.skill = role.cooldown;
  startMotion("skill", .24);
  const power = 63 + (player.level - 1) * 7;
  if (selected === "knight") {
    burst(player.x, player.y, role.color, 157);
    enemies.forEach(enemy => {
      if (distance(player, enemy) < 157) hurt(enemy, power, 390);
    });
  } else if (selected === "ranger") {
    for (const spread of [-.36, -.18, 0, .18, .36]) fire(angle + spread, Math.round(power * .73), 880, 530);
  } else {
    const reach = Math.min(distance(player, target), role.reach);
    const center = { x: player.x + Math.cos(angle) * reach, y: player.y + Math.sin(angle) * reach };
    burst(center.x, center.y, role.color, 135);
    burst(center.x, center.y, "#f4d08c", 74, "thunder");
    enemies.forEach(enemy => {
      if (distance(center, enemy) < 135) hurt(enemy, power + 13, 135);
    });
  }
  playSound("skill");
}

function dash() {
  if (mode !== "battle" || player.dash > 0) return;
  input.goal = null;
  player.dodge = .17;
  player.dash = 1.35;
  startMotion("retreat", .23);
  burst(player.x, player.y, "#d4c2a1", 39);
  playSound("dash");
}

function frontLimit(y) {
  let limit = footwork.right;
  for (const enemy of enemies) {
    if (enemy.spawn > 0 || enemy.hp <= 0 || Math.abs(enemy.y - y) > enemy.stats.radius + 16) continue;
    limit = Math.min(limit, Math.max(player.x, enemy.x - enemy.stats.radius - 34));
  }
  return limit;
}

function stepPlayer(dt) {
  const { x, y } = player;
  if (player.dodge > 0) {
    player.x = Math.max(footwork.left, x - Math.min(dt, player.dodge) * 300);
  } else {
    const move = movement();
    const step = player.role.speed * dt;
    player.y = clamp(y + move.y * step * .48, footwork.top, footwork.bottom);
    player.x = clamp(x + move.x * step, footwork.left, move.x > 0 ? frontLimit(player.y) : footwork.right);
  }
  player.stride = x !== player.x || y !== player.y ? player.stride + dt * 14 : 0;
  for (const timer of ["skill", "dash", "hit", "dodge"]) player[timer] = Math.max(0, player[timer] - dt);
  stepMotion(dt);
  if (input.clickAttack || input.buttonAttack || input.keys.has("KeyJ")) attack();
}

function damagePlayer(damage) {
  if (player.dodge > 0 || player.hit > 0) return;
  player.hit = .49;
  player.hp = Math.max(0, player.hp - damage);
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
    enemy.x = clamp(enemy.x, minimum, bounds.right + 10);
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
  const summary = "击杀 " + kills + " · 收集灵砂 " + ash;
  if (player.hp <= 0) {
    showResult("defeat", "山门失守", summary, "重新挑战");
    return;
  }
  ui.remaining.textContent = enemies.length;
  if (enemies.length > 0) return;
  if (nextWave === null) {
    nextWave = 1.75;
    announce(waveIndex + 1 === waves.length ? "镇山兽已降伏" : "敕令已成", 1.3);
  }
  nextWave -= dt;
  if (nextWave <= 0) {
    if (waveIndex + 1 < waves.length) startWave();
    else {
      showResult("victory", "五令功成", summary, "再战一次");
      playSound("level");
    }
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

function drawPixelArc(x, y, rx, ry, start, sweep, size, color) {
  const dots = Math.ceil(Math.max(rx, ry) * sweep / pixelSize);
  ctx.fillStyle = color;
  for (let i = 0; i <= dots; i += 1) {
    const angle = start + sweep * i / dots;
    ctx.fillRect(snap(x + Math.cos(angle) * rx), snap(y + Math.sin(angle) * ry), size, size);
  }
}

function drawEntity(entity, isPlayer) {
  const { x, y, hit, stride } = entity;
  const size = isPlayer ? 87 : entity.stats.size;
  const motion = isPlayer ? entity.motion : null;
  const phase = motion ? motion.time / motion.duration : 0;
  const striking = (motion?.kind === "attack" || motion?.kind === "skill") && phase >= attackRelease && phase < .86;
  const sprite = isPlayer ? actors[entity.role.sprite * 2 + style][striking ? "strike" : "ready"] : foes[entity.stats.sprite - 3];
  const isBoss = entity.type === "sentinel";
  ellipse(x, y + 1, size * .32, size * .12, "#181122ba");
  if (isPlayer) {
    drawPixelArc(x, y + 1, 24, 9, 0, Math.PI * 2, 3, player.role.color);
  }
  ctx.save();
  const bounce = reduceMotion || motion ? 0 : Math.floor(stride) % 2 * 3;
  const lunge = striking && !reduceMotion ? 9 : 0;
  const recoil = motion?.kind === "hurt" && !reduceMotion ? 6 * Math.sin(phase * Math.PI) : 0;
  const lift = !reduceMotion && entity.windup > 0 ? 6 : 0;
  ctx.translate(snap(x + Math.cos(player.angle) * lunge - recoil), snap(y + Math.sin(player.angle) * lunge) - bounce - lift);
  ctx.scale(isPlayer ? 1 : -1, 1);
  if (hit > 0 && (!isPlayer || (motion?.kind === "hurt" && motion.time < .07))) {
    ctx.filter = isPlayer ? "brightness(1.35)" : "brightness(1.7)";
  }
  if (!reduceMotion && isPlayer) {
    if (motion?.kind === "retreat") ctx.rotate(-.16 * Math.sin(phase * Math.PI));
    if (striking) ctx.rotate(.055 * Math.sin(phase * Math.PI));
  }
  if (sprite.complete && sprite.naturalWidth) {
    const scale = size / sprite.naturalHeight;
    const width = Math.round(sprite.naturalWidth * scale);
    const height = Math.round(sprite.naturalHeight * scale);
    const left = -Math.round(width * .5);
    if (isPlayer && player.dodge > 0 && !reduceMotion) {
      ctx.globalAlpha = .22;
      ctx.drawImage(sprite, left + 13, -height + 3, width, height);
      ctx.globalAlpha = 1;
    }
    ctx.drawImage(sprite, left, -height + 3, width, height);
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
  ctx.save();
  ctx.globalAlpha = 1 - progress;
  if (effect.type === "slash") {
    const radius = effect.radius * (.46 + progress * .43);
    const angle = effect.angle - 1.45;
    drawPixelArc(effect.x, effect.y - 14, radius, radius, angle, 2.9, 9, effect.color);
    drawPixelArc(effect.x, effect.y - 14, radius - 3, radius - 3, angle + .38, 2.14, 6, "#fff4df");
  } else if (effect.type === "thunder") {
    ctx.lineJoin = "round";
    ctx.strokeStyle = effect.color;
    ctx.lineWidth = 3;
    for (let i = 0; i < 5; i++) {
      const offset = (i - 2) * effect.radius * .48;
      const x = effect.x + offset;
      const y = effect.y - Math.abs(offset) * .18;
      ctx.beginPath();
      ctx.moveTo(effect.x + offset * .65, y - 118);
      ctx.lineTo(x - 8, y - 59);
      ctx.lineTo(x + 8, y - 64);
      ctx.lineTo(x, y);
      ctx.stroke();
    }
  } else {
    const radius = effect.radius * (.25 + .75 * progress);
    drawPixelArc(effect.x, effect.y, radius, radius * .64, 0, Math.PI * 2, 4, effect.color);
    for (let i = 0; i < 10; i += 1) {
      const angle = i * Math.PI / 5;
      const x = effect.x + radius * 1.07 * Math.cos(angle);
      const y = effect.y + radius * .75 * Math.sin(angle) - progress * 10;
      pixel(x, y, i % 2 ? 3 : 6, i % 2 ? "#fff1cf" : effect.color);
    }
  }
  ctx.restore();
}

function draw() {
  ctx.setTransform(1, 0, 0, 1, -viewLeft, 0);
  ctx.imageSmoothingEnabled = true;
  ctx.fillStyle = "#211b38";
  ctx.fillRect(0, 0, W, H);
  if (crypt.complete && crypt.naturalWidth) ctx.drawImage(crypt, 0, 0, W, H);
  else {
    ctx.fillStyle = "#463959";
    ctx.fillRect(76, 145, W - 152, H - 213);
  }
  const edge = ctx.createRadialGradient(W / 2, H / 2, H * .23, W / 2, H / 2, W * .59);
  edge.addColorStop(0, "#19102700");
  edge.addColorStop(1, "#130d2950");
  ctx.fillStyle = edge;
  ctx.fillRect(0, 0, W, H);

  for (const enemy of enemies) {
    if (enemy.windup > 0) {
      ellipse(enemy.x, enemy.y, slamRange, slamRange, "#e45a6c35");
      drawPixelArc(enemy.x, enemy.y, slamRange, slamRange, 0, Math.PI * 2, 3, "#ff7b8e");
    }
    if (enemy.spawn > 0 && enemy.spawn < .75) {
      const size = 13 + 17 * enemy.spawn;
      ellipse(enemy.x, enemy.y, size, size * .4, "#373585af");
      drawPixelArc(enemy.x, enemy.y, size, size * .4, 0, Math.PI * 2, 3, "#bc9aff");
    }
  }
  for (const drop of loot) {
    const y = drop.y - 9 + (reduceMotion ? 0 : Math.floor(drop.age * 5) % 2 * 3);
    const color = drop.heal ? "#80ffc1" : "#ffbd68";
    ellipse(drop.x, drop.y + 1, 9, 4, "#1d152a95");
    pixel(drop.x - 3, y - 6, 6, color);
    pixel(drop.x - 6, y, 12, color);
    pixel(drop.x - 3, y + 9, 6, color);
    pixel(drop.x - 3, y, 6, "#fff2d4");
  }
  if (input.goal) ellipse(input.goal.x, input.goal.y, 7, 4, "#e3cb9d92");

  const active = enemies.filter(enemy => enemy.spawn <= 0);
  active.push(player);
  active.sort((a, b) => a.y - b.y);
  active.forEach(entity => drawEntity(entity, entity === player));

  for (const shot of projectiles) {
    const dx = Math.cos(shot.angle) * 3;
    const dy = Math.sin(shot.angle) * 3;
    for (let i = 7; i >= 0; i -= 1) {
      pixel(shot.x - dx * i, shot.y - 15 - dy * i, shot.magic && i < 3 ? 9 : 3, i < 2 ? "#fff4dc" : shot.color);
    }
  }
  effects.forEach(drawEffect);
  ctx.textAlign = "center";
  ctx.font = "bold 20px ui-monospace, monospace";
  for (const popup of popups) {
    ctx.globalAlpha = clamp(popup.life * 3, 0, 1);
    ctx.strokeStyle = "#1e1109";
    ctx.lineWidth = 3;
    ctx.strokeText(popup.text, snap(popup.x), snap(popup.y));
    ctx.fillStyle = popup.color;
    ctx.fillText(popup.text, snap(popup.x), snap(popup.y));
  }
  ctx.globalAlpha = 1;
}

const sounds = {
  start: [146, 98, .4, "sine", .095], slash: [186, 58, .13, "triangle", .13],
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
  input.x = viewLeft + (event.clientX - rect.left) / rect.width * ui.arena.width;
  input.y = (event.clientY - rect.top) / rect.height * H;
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
  if (mode !== "battle" || !event.isPrimary || event.button !== 0) return;
  aimAt(event);
  if (event.pointerType === "touch") {
    input.aiming = false;
    input.goal = { x: clamp(input.x, footwork.left, footwork.right), y: clamp(input.y, footwork.top, footwork.bottom) };
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
ui.skill.addEventListener("click", useSkill);
ui.dash.addEventListener("click", dash);
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
  if (event.code === "Space" && [ui.sound, ui.continue, ui.leave].includes(document.activeElement)) return;
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
    advance(dt);
    draw();
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
