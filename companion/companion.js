// Kinfolk companion
// Watches the addon's SavedVariables file and posts each new dungeon run.
//   mode "discord": posts a formatted embed straight to a Discord webhook
//   mode "raw":     posts the run as JSON (point it at an n8n webhook)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import luaparse from 'luaparse';
import { createHash } from 'node:crypto';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = new Set(process.argv.slice(2));
const DRY = args.has('--dry-run');
const ONCE = args.has('--once');
const configPath = path.join(here, 'config.json');
if (!fs.existsSync(configPath)) {
  console.error('Missing config.json. Copy config.example.json to config.json and fill it in.');
  process.exit(1);
}
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const statePath = path.join(here, 'posted.json');
const posted = new Set(fs.existsSync(statePath) ? JSON.parse(fs.readFileSync(statePath, 'utf8')) : []);
const savePosted = () => fs.writeFileSync(statePath, JSON.stringify([...posted], null, 2));
const craftStatePath = path.join(here, 'crafting-state.json');
const craftState = fs.existsSync(craftStatePath) ? JSON.parse(fs.readFileSync(craftStatePath, 'utf8')) : {};
const saveCraftState = () => fs.writeFileSync(craftStatePath, JSON.stringify(craftState, null, 2));

// ---- Lua SavedVariables -> JavaScript -------------------------------------
function toJS(node) {
  switch (node.type) {
    // pseudo-latin1 gives one char per byte; re-decode as UTF-8 so names like Thrâll survive
    case 'StringLiteral': return Buffer.from(node.value ?? '', 'latin1').toString('utf8');
    case 'NumericLiteral': return node.value;
    case 'BooleanLiteral': return node.value;
    case 'NilLiteral': return null;
    case 'UnaryExpression':
      if (node.operator === '-') return -toJS(node.argument);
      return null;
    case 'TableConstructorExpression': {
      const obj = {}; const list = []; let isList = true;
      for (const f of node.fields) {
        if (f.type === 'TableValue') list.push(toJS(f.value));
        else {
          isList = false;
          const key = f.type === 'TableKeyString' ? f.key.name : toJS(f.key);
          obj[key] = toJS(f.value);
        }
      }
      if (isList) return list;
      // numeric keys 1..n (how WoW writes arrays) become a list
      const keys = Object.keys(obj);
      if (keys.length && keys.every((k, i) => String(i + 1) === k)) return keys.map(k => obj[k]);
      list.forEach((v, i) => { obj[i + 1] = v; });
      return obj;
    }
    default: return null;
  }
}
function readSavedVariables(file) {
  const src = fs.readFileSync(file, 'latin1');
  const ast = luaparse.parse(src, { encodingMode: 'pseudo-latin1', luaVersion: '5.1', comments: false });
  const out = {};
  for (const stmt of ast.body) {
    if (stmt.type === 'AssignmentStatement') {
      stmt.variables.forEach((v, i) => { out[v.name] = toJS(stmt.init[i]); });
    }
  }
  return out;
}

// ---- Formatting -------------------------------------------------------------
const ROLE_ICON = { TANK: '🛡️', HEALER: '💚', DAMAGER: '⚔️', NONE: '•' };
const fmtTime = s => `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, '0')}`;
const fmtNum = n => n >= 1e6 ? (n / 1e6).toFixed(1) + 'M' : n >= 1e3 ? (n / 1e3).toFixed(1) + 'k' : String(Math.round(n));

function top(stats, key, { limit = 5, perSecond = 0, unit = '', icon = null } = {}) {
  const rows = Object.entries(stats || {})
    .map(([name, s]) => [name, (s && s[key]) || 0])
    .filter(([, v]) => v > 0)
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit);
  if (!rows.length) return null;
  return rows.map(([name, v], i) => {
    const medal = icon || ['🥇', '🥈', '🥉'][i] || '▫️';
    const rate = perSecond ? ` (${fmtNum(v / perSecond)}/s)` : '';
    return `${medal} **${name}** ${fmtNum(v)}${unit}${rate}`;
  }).join('\n');
}

function discordPayload(run, site = {}) {
  const party = (run.party || []).map(m => `${ROLE_ICON[m.role] || '•'} ${m.name}${m.class ? ` · ${m.class[0] + m.class.slice(1).toLowerCase()}` : ''}`).join('\n') || 'Unknown';
  const bosses = run.bosses?.length ? run.bosses.map(b => `☠️ ${b.name} (${fmtTime(b.killedAt)})`).join('\n') : 'No bosses killed';
  const combat = run.combatSeconds || 0;
  const fields = [
    { name: 'Party', value: party, inline: true },
    { name: 'Bosses', value: bosses, inline: true },
  ];
  const add = (name, value) => { if (value) fields.push({ name, value, inline: false }); };
  add('Damage', top(run.stats, 'damage', { perSecond: combat }));
  add('Healing', top(run.stats, 'healing', { perSecond: combat }));
  // with the website, the post stays a summary and the page has the rest
  if (!site.url) {
    add('Interrupts', top(run.stats, 'interrupts', { limit: 3 }));
    add('Dispels', top(run.stats, 'dispels', { limit: 3 }));
    add('Avoidable damage taken', top(run.stats, 'avoidable', { limit: 3, icon: '🔥' }));
  }
  add('Deaths', top(run.stats, 'deaths', { limit: 5, icon: '💀' }));
  if (site.url) {
    const fights = run.segments?.length || 0;
    add('Full breakdown', `[Open this run](${site.url}): ${fights ? `${fights} fights, ` : ''}every stat, party and boss timeline`);
  }
  const wipes = run.wipes || 0;
  return {
    username: config.botName || 'Kinfolk',
    embeds: [{
      title: `🦊 ${run.dungeon}${run.difficulty ? ` · ${run.difficulty}` : ''}`,
      ...(site.url ? { url: site.url } : {}),
      ...(site.image ? { image: { url: site.image } } : {}),
      description: `**${fmtTime(run.duration || 0)}** total · ${fmtTime(combat)} in combat · ${run.bosses?.length || 0} ${run.bosses?.length === 1 ? "boss" : "bosses"} · ${wipes} ${wipes === 1 ? 'wipe' : 'wipes'}`,
      color: 0x7FE3C4,
      fields,
      footer: { text: `Logged by ${run.loggedBy || 'unknown'} · ${config.guildName || 'your guild'}` },
      timestamp: new Date((run.endTime || run.startTime) * 1000).toISOString(),
    }],
  };
}

// ---- Sending ----------------------------------------------------------------
const sleep = ms => new Promise(r => setTimeout(r, ms));
// Upload to the website (if configured). Returns { url, image }, {} when no
// site is set up, or null when the upload failed and should be retried.
async function uploadToSite(run) {
  if (!config.siteUrl || !config.siteKey) return {};
  if (DRY) return { url: `${config.siteUrl}/runs/DRY-RUN`, image: `${config.siteUrl}/runs/DRY-RUN/card.png` };
  try {
    const res = await fetch(`${config.siteUrl.replace(/\/$/, '')}/api/runs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${config.siteKey}` },
      body: JSON.stringify({ run }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { console.error(`Website upload failed (${res.status}): ${data.error || 'no details'}`); return null; }
    return { url: data.url, image: data.image };
  } catch (err) {
    console.error(`Website unreachable (${err.message}); will retry on the next change.`);
    return null;
  }
}

async function send(run, attempt = 0, site) {
  if (site === undefined) { site = await uploadToSite(run); if (site === null) return false; }
  const body = config.mode === 'raw' ? { run, ...site } : discordPayload(run, site);
  if (DRY) { console.log(JSON.stringify(body, null, 2)); return true; }
  let res;
  try {
    res = await fetch(config.webhookUrl, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
  } catch (err) {
    console.error(`Webhook unreachable (${err.message}); will retry on the next change.`);
    return false;
  }
  if (res.status === 429 && attempt < 3) {
    const wait = Number(res.headers.get('retry-after')) || 2;
    await sleep(wait * 1000 + 250);
    return send(run, attempt + 1, site);
  }
  if (!res.ok) { console.error(`Webhook failed (${res.status}): ${await res.text()}`); return false; }
  return true;
}

// Professions, inventory and guild crafters -> website. Only when something changed.
async function uploadCrafting(crafting) {
  if (!crafting || !config.siteUrl || !config.siteKey) return;
  const body = { uploader: Object.keys(crafting.chars || {})[0], characters: crafting.chars || {}, guild: crafting.guild || {} };
  const hash = createHash('sha256').update(JSON.stringify(body)).digest('hex');
  if (hash === craftState.hash) return;
  if (DRY) { console.log(`Would upload crafting: ${Object.keys(body.characters).length} of your characters, ${Object.keys(body.guild).length} guild crafters`); return; }
  try {
    const res = await fetch(`${config.siteUrl.replace(/\/$/, '')}/api/crafting`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${config.siteKey}` },
      body: JSON.stringify(body),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { console.error(`Crafting upload failed (${res.status}): ${data.error || 'no details'}`); return; }
    craftState.hash = hash;
    const fresh = Object.entries(data.stockPages || {}).filter(([k, url]) => craftState.pages?.[k] !== url);
    craftState.pages = { ...(craftState.pages || {}), ...(data.stockPages || {}) };
    saveCraftState();
    console.log(`Uploaded crafting: ${data.characters} of your characters, ${data.guild} guild crafters.`);
    for (const [k, url] of fresh) console.log(`  Private stock page for ${k} (don't share): ${url}`);
  } catch (err) {
    console.error(`Website unreachable for crafting upload (${err.message}); will retry on the next change.`);
  }
}

// The game's Encounter Journal as read by the addon -> website Journal pages.
async function uploadJournal(journal) {
  if (!journal || !journal.dungeons || !config.siteUrl || !config.siteKey || DRY) return;
  const hash = createHash('sha256').update(JSON.stringify(journal.dungeons)).digest('hex');
  if (hash === craftState.journalHash) return;
  try {
    const res = await fetch(`${config.siteUrl.replace(/\/$/, '')}/api/journal`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${config.siteKey}` },
      body: JSON.stringify({ journal }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { console.error(`Journal upload failed (${res.status}): ${data.error || 'no details'}`); return; }
    craftState.journalHash = hash; saveCraftState();
    console.log(`Uploaded the dungeon journal: ${data.dungeons} dungeons, ${data.bosses} bosses.`);
  } catch (err) {
    console.error(`Website unreachable for the journal upload (${err.message}).`);
  }
}

// The guild roster (name, rank, level, class, zone, online) -> members-only website page.
async function uploadRoster(roster, locations) {
  if (!roster || !roster.members || !config.siteUrl || !config.siteKey || DRY) return;
  const hash = createHash('sha256').update(JSON.stringify([roster, locations || {}])).digest('hex');
  if (hash === craftState.rosterHash) return;
  try {
    const res = await fetch(`${config.siteUrl.replace(/\/$/, '')}/api/roster`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${config.siteKey}` },
      body: JSON.stringify({ roster, locations: locations || {}, reportedBy: Object.keys(craftState.pages || {})[0] || null }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { console.error(`Roster upload failed (${res.status}): ${data.error || 'no details'}`); return; }
    craftState.rosterHash = hash; saveCraftState();
    console.log(`Uploaded the guild roster: ${data.members} members, ${data.online} online.`);
  } catch (err) {
    console.error(`Website unreachable for the roster upload (${err.message}).`);
  }
}

// ---- Site data for the addon ----------------------------------------------
// Shop, costs and orders aren't in the game, so the companion writes them into
// the addon folder as Lua; the addon reads it on the next /reload.
function toLua(v) {
  if (v === null || v === undefined) return 'nil';
  if (typeof v === 'number') return Number.isFinite(v) ? String(v) : 'nil';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'string') return '"' + v.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '') + '"';
  if (Array.isArray(v)) return '{' + v.map(toLua).join(',') + '}';
  return '{' + Object.entries(v).map(([k, x]) => `[${toLua(k)}]=${toLua(x)}`).join(',') + '}';
}
function siteDataPath() {
  const root = config.savedVariablesFile.split(/[\\/]WTF[\\/]/)[0];
  const dir = path.join(root, 'Interface', 'AddOns', 'Kinfolk', 'Data');
  return fs.existsSync(dir) ? path.join(dir, 'SiteData.lua') : null;
}
async function writeSiteData(crafting) {
  if (!config.siteUrl || !config.siteKey || DRY) return;
  const file = siteDataPath();
  if (!file) return;
  const chars = Object.keys((crafting && crafting.chars) || {});
  try {
    const res = await fetch(`${config.siteUrl.replace(/\/$/, '')}/api/export?chars=${encodeURIComponent(chars.join(','))}`,
      { headers: { Authorization: `Bearer ${config.siteKey}` } });
    if (!res.ok) { console.error(`Couldn't fetch site data for the addon (${res.status})`); return; }
    const data = await res.json();
    data.links = {};
    for (const [k, url] of Object.entries(craftState.pages || {})) data.links[k] = { stock: url, orders: url.replace('/stock?', '/orders?') };
    const { at, ...rest } = data; // "at" changes every call; compare the rest
    const hash = createHash('sha256').update(JSON.stringify(rest)).digest('hex');
    if (hash === craftState.exportHash && fs.existsSync(file)) return;
    fs.writeFileSync(file, `-- Written by the Kinfolk companion. Don't edit: it's replaced after each sync.\nKinfolkSiteData = ${toLua(data)}\n`);
    craftState.exportHash = hash; saveCraftState();
    console.log(`Updated the addon's shop, costs and orders (${data.shop.length} on offer, ${data.orders.length} open orders). /reload in game to see them.`);
  } catch (err) {
    console.error(`Couldn't update the addon's site data (${err.message}).`);
  }
}

let busy = false;
async function check() {
  if (busy) return; busy = true;
  try {
    if (!fs.existsSync(config.savedVariablesFile)) { console.log('Waiting for SavedVariables file…'); return; }
    let db;
    try { const sv = readSavedVariables(config.savedVariablesFile); db = sv.KinfolkDB || sv.NinthTailDB || sv.NinthTailLogDB; }
    catch (err) { console.error('Could not read saved data yet:', err.message); return; }
    const runs = (db && db.runs) || [];
    for (const run of runs) {
      if (!run || !run.id || posted.has(run.id)) continue;
      const ok = await send(run);
      if (ok) {
        if (!DRY) { posted.add(run.id); savePosted(); }
        console.log(`Posted run: ${run.dungeon} (${run.id})`);
        if (!DRY) await sleep(1000); // stay under Discord's webhook rate limit on a backlog
      } else break; // keep order; try the rest next time
    }
    await uploadCrafting(db && db.crafting);
    await uploadJournal(db && db.journal);
    await uploadRoster(db && db.roster, db && db.locations);
    await writeSiteData(db && db.crafting);
  } catch (err) {
    console.error('Unexpected error:', err);
  } finally { busy = false; }
}

await check();
if (!ONCE) {
  console.log(`Watching ${config.savedVariablesFile}`);
  fs.watchFile(config.savedVariablesFile, { interval: 3000 }, () => check());
}
