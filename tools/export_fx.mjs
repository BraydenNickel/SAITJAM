#!/usr/bin/env node
// Regenerates every pixelfx sprite sheet in assets/fx/ (MUTANT LAB).
//
//   node tools/export_fx.mjs                 all sheets (run from the project root)
//   node tools/export_fx.mjs hit crit        only these out names
//   node tools/export_fx.mjs --tmp DIR       keep the raw renders (and contact.png previews) in DIR
//
// Each entry runs `node tools/pixelfx/tools/render.mjs <id> --sheet --opts <json>` into its own
// temp folder, then copies <name>.png/.json to assets/fx/<out>.png/.json and patches the json:
//   meta.image -> "<out>.png" (PixelFxSheet loads it relative to the json),
//   playback fps = render fps * speed, loop forced off for `once` entries.
//
// Entry fields:
//   out    file name in assets/fx (also the key used by src/data/fx_library.gd)
//   id     pixelfx effect id (tools/pixelfx/docs/CATALOG.md)
//   pal    name of a PAL ramp in tools/pixelfx/src/core/color.js, or an array of hex strings
//   opts   extra effect options (seed, text, radius ...)
//   fps    frames rendered per second of effect time (fewer = smaller sheet). Default 15.
//   speed  playback speed multiplier. Played length = effect duration / speed.
//   once   a pixelfx loop exported as a one-shot (one cycle, then PixelFxPlayer frees it)
//   cut    keep only the first `cut` seconds of effect time (drops the tail frames from the json)
//   body   true keeps the pixelfx stand-in character in the sheet. Default: a blank actor is passed, so
//          effects that wrap or tint "the character" (heal, burning, shields ...) export only their own
//          pixels and can sit on any monster.

import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, readFileSync, writeFileSync, statSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { pathToFileURL } from "node:url";

const ROOT = process.cwd();
const PIXELFX = join(ROOT, "tools", "pixelfx");
const RENDER = join(PIXELFX, "tools", "render.mjs");
const OUT_DIR = join(ROOT, "assets", "fx");
const MAX_KB = 300;

const { PAL } = await import(pathToFileURL(join(PIXELFX, "src", "core", "color.js")).href);

// Game palettes that are not stock pixelfx ramps (dark to bright).
const GAME = {
  toxic: ["#06140a", "#0c2a12", "#12501c", "#1c8228", "#35c23a", "#7cf05a", "#d2ff9a", "#ffffff"],
  ultra: ["#1a0516", "#40083a", "#7a1070", "#c01cb4", "#ff3df0", "#ff8cf6", "#ffd4fb", "#ffffff"],
  goo: ["#0e0c06", "#221e0a", "#3c3a10", "#5c6216", "#84921e", "#b4c83a", "#e0f07a", "#f8ffd0"],
  steel: ["#10141c", "#242c3c", "#3c4a60", "#5c6e88", "#8a9cb4", "#bccadc", "#e8f0f8", "#ffffff"],
  crystal: ["#0a1430", "#14306a", "#1c5cae", "#30a0e0", "#6ce0f4", "#b4fbff", "#e8ffff", "#ffffff"],
  blood: ["#14040a", "#3a0a14", "#6a101c", "#a01824", "#d42a30", "#ff5a50", "#ff9a8a", "#ffffff"],
};

// The stock pixelfx actor (24 x 38 px, feet at the origin) with nothing in it: same anchors, no pixels.
const BLANK_ACTOR = {
  mask: { w: 24, h: 38, data: new Array(24 * 38).fill(0) },
  pixels: new Array(24 * 38).fill(0),
  x: -12, y: -38, w: 24, h: 38, k: 2, head: [0, -38], chest: [0, -26], eyes: [[13, 3], [15, 3]],
};

const FX = [
  // ---- abilities (contract section 2) -------------------------------------------------
  { out: "ab_venom", id: "melee/claw-swipe", pal: "poison", fps: 24, speed: 1.4 },
  { out: "ab_dodge", id: "impacts/ricochet", pal: "cyber", fps: 24, speed: 1.7 },
  { out: "ab_double_strike", id: "melee/double-slash", pal: GAME.steel, fps: 24, speed: 1.3 },
  { out: "ab_lifesteal", id: "pickups/heart-pickup", pal: GAME.blood, fps: 20, speed: 1.8, once: true },
  { out: "ab_reflect", id: "impacts/parry", pal: "cyber", fps: 24, speed: 1.6 },
  { out: "ab_spore_pulse", id: "nature/spore-burst", fps: 12, speed: 3.2 },
  { out: "ab_regen", id: "nature/healing-bloom", pal: "heal", fps: 12, speed: 3.5 },
  { out: "ab_mend", id: "pickups/heart-pickup", pal: "heal", fps: 20, speed: 1.8, once: true },
  { out: "ab_thorns", id: "nature/thorns", fps: 15, speed: 3.2 },
  { out: "ab_shield", id: "impacts/shield-block", pal: GAME.crystal, fps: 20, speed: 1.2 },
  { out: "ab_execute", id: "melee/scythe-reap", pal: GAME.blood, fps: 15, speed: 2.8 },
  { out: "ab_cleave", id: "melee/spear-sweep", pal: "volt", fps: 20, speed: 2.2 },
  { out: "ab_stun", id: "status/stunned", fps: 15, speed: 2.2, once: true },
  { out: "ab_rage", id: "status/rage", fps: 20, speed: 1.8, once: true },
  { out: "ab_berserk", id: "melee/dagger-flurry", pal: GAME.blood, fps: 24, speed: 1.4 },
  { out: "ab_war_cry", id: "ui/exclamation", pal: "volt", fps: 20, speed: 1.6 },
  { out: "ab_vengeance", id: "shadow/curse", pal: GAME.blood, fps: 12, speed: 3.2 },
  { out: "ab_snipe", id: "projectiles/muzzle-pistol", fps: 20, speed: 2.6 },
  { out: "ab_chill", id: "ice/snowflake-burst", fps: 12, speed: 3.6 },
  { out: "ab_corrode", id: "nature/acid-splash", fps: 12, speed: 3.4 },
  { out: "ab_second_wind", id: "holy/resurrection", pal: "gold", fps: 5, speed: 3 },
  { out: "ab_ambush", id: "melee/thrust", pal: "arcane", fps: 24, speed: 1.3 },
  { out: "ab_chain", id: "lightning/zap-hit", pal: "electric", fps: 24, speed: 1.5 },
  { out: "ab_momentum", id: "arcane/spell-charge", pal: "volt", fps: 15, speed: 2.3, once: true },
  { out: "ab_burn", id: "impacts/blunt-hit", pal: "fire", opts: { warm: "#ff8a2a", dust: "#cc3a1a", clod: "#4a1118" }, fps: 24, speed: 1.4 },
  { out: "ab_titan", id: "impacts/heavy-landing", fps: 15, speed: 2.2 },
  { out: "ab_phase", id: "scifi/emp-blast", pal: GAME.ultra, fps: 12, speed: 4 },
  { out: "ab_swarm", id: "critters/bat", pal: GAME.toxic, fps: 15, speed: 2.4, once: true },

  // ---- events ------------------------------------------------------------------------
  { out: "hit", id: "impacts/hit-spark", fps: 30, speed: 1 },
  { out: "crit", id: "impacts/crit-hit", fps: 24, speed: 1.4 },
  { out: "death", id: "spawn/poof", pal: GAME.toxic, fps: 20, speed: 2.2 },
  { out: "heal", id: "holy/heal", pal: "heal", fps: 15, speed: 2.6 },
  { out: "dodge", id: "ui/damage-number", pal: GAME.steel, opts: { text: "MISS" }, fps: 20, speed: 1.6 },
  { out: "frenzy", id: "lightning/thunderclap", pal: GAME.blood, fps: 15, speed: 1.6 },
  { out: "win_small", id: "spawn/coin-drop", fps: 15, speed: 2 },
  { out: "win_medium", id: "ui/confetti", fps: 12, speed: 1.7 },
  { out: "win_big", id: "explosions/firework-burst", fps: 6, speed: 2 },
  { out: "coin", id: "pickups/coin-spin", fps: 15, speed: 2.4, once: true },
  { out: "purchase", id: "pickups/collect-burst", pal: "gold", fps: 20, speed: 1.8 },
  { out: "mutate_success", id: "arcane/mana-burst", pal: GAME.toxic, fps: 15, speed: 1.6 },
  { out: "mush", id: "water/splash", pal: GAME.goo, fps: 15, speed: 2.4 },
  { out: "ultra_reveal", id: "arcane/magic-circle-cast", pal: GAME.ultra, fps: 6.5, speed: 2 },

  // ---- looping auras, one per ultra body style -----------------------------------------
  { out: "aura_crystal", id: "holy/divine-shield", pal: GAME.crystal, fps: 15 },
  { out: "aura_shadow", id: "shadow/shadow-flames", fps: 15 },
  { out: "aura_molten", id: "fire/spirit-flame", pal: "lava", fps: 10 },
  { out: "aura_slime", id: "nature/toxic-puddle", fps: 10 },
  { out: "aura_gold", id: "holy/sunburst", pal: "gold", fps: 7.5 },
  { out: "aura_skeletal", id: "shadow/necro-skulls", fps: 15 },
  { out: "aura_void", id: "shadow/void-orb", fps: 6.25 },
  { out: "aura_angelic", id: "holy/blessing", pal: "holy", fps: 15 },
];

// ---- run --------------------------------------------------------------------------------

const argv = process.argv.slice(2);
let tmp = join(tmpdir(), "mutantlab-fx"), keepTmp = false;
const only = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === "--tmp") (tmp = resolve(argv[++i])), (keepTmp = true);
  else only.push(argv[i]);
}

const names = new Set();
for (const e of FX) {
  if (names.has(e.out)) throw new Error(`duplicate out name: ${e.out}`);
  names.add(e.out);
}

mkdirSync(OUT_DIR, { recursive: true });
let failed = 0, total = 0;
for (const e of FX) {
  if (only.length && !only.includes(e.out)) continue;
  const opts = { ...(e.body ? {} : { actor: BLANK_ACTOR }), ...(e.opts ?? {}) };
  if (e.pal) {
    opts.palette = Array.isArray(e.pal) ? e.pal : PAL[e.pal];
    if (!opts.palette) throw new Error(`${e.out}: unknown palette ${e.pal}`);
  }
  const fps = e.fps ?? 15, speed = e.speed ?? 1;
  const dir = join(tmp, e.out);
  const args = [RENDER, e.id, "--sheet", "--fps", String(fps), "--out", dir];
  args.push("--opts", JSON.stringify(opts));
  const res = spawnSync(process.execPath, args, { cwd: PIXELFX, encoding: "utf8" });
  if (res.status !== 0) {
    failed++;
    console.error(`${e.out}  FAILED (${e.id}): ${res.stderr || res.stdout}`);
    continue;
  }
  // render.mjs names the sheet after the effect, whatever the options: <out dir>/<id>/<name>.png
  const name = e.id.split("/")[1], src = join(dir, e.id);
  const json = JSON.parse(readFileSync(join(src, `${name}.json`), "utf8"));
  const info = json.meta.pixelfx;
  if (e.cut) json.frames = json.frames.slice(0, Math.max(1, Math.round(e.cut * fps)));
  const playFps = fps * speed, ms = Math.round(1000 / playFps);
  for (const f of json.frames) f.duration = ms;
  json.meta.image = `${e.out}.png`;
  json.meta.frameTags = [{ name: e.out, from: 0, to: json.frames.length - 1, direction: "forward" }];
  info.fps = playFps;
  info.frames = json.frames.length;
  if (e.once) info.loop = false;
  info.export = { out: e.out, renderFps: fps, speed, seconds: +(json.frames.length / playFps).toFixed(2) };
  copyFileSync(join(src, `${name}.png`), join(OUT_DIR, `${e.out}.png`));
  writeFileSync(join(OUT_DIR, `${e.out}.json`), JSON.stringify(json, null, 1));
  const kb = statSync(join(OUT_DIR, `${e.out}.png`)).size / 1024;
  total += kb;
  console.log(
    `${e.out.padEnd(18)} ${e.id.padEnd(28)} ${String(info.frameSize).padEnd(8)} ${String(info.frames).padStart(3)}f ` +
      `${info.export.seconds}s ${info.loop ? "loop" : "once"} ${kb.toFixed(0)} KB${kb > MAX_KB ? "  <-- OVER " + MAX_KB + " KB" : ""}`,
  );
}
if (!keepTmp) rmSync(tmp, { recursive: true, force: true });
console.log(`${total.toFixed(0)} KB of PNG in assets/fx${failed ? `, ${failed} FAILED` : ""}`);
process.exit(failed ? 1 : 0);
