-- Module: GuildShare. Swaps recipe lists with guildmates who also run the
-- addon, over hidden guild addon messages. Whoever runs the companion app then
-- uploads the whole guild's crafts, so not everyone needs it.
--
-- Shared: profession names, skill, and which items/recipes you can craft.
-- Never shared: bags, bank, gold, or anything else.
--
-- crafting.guild[charKey] = { class, receivedAt, professions = { [name] = { skill, maxSkill, scannedAt, recipes = {...} } } }
--
-- Messages (prefix "Kinfolk", tab-separated, under 255 bytes each):
--   Q                                        "please share yours"
--   H <prof> <skill> <max> <count> <scannedAt> <class> <offer 1|0>   start of one profession
--   I <prof> <tokens>                        recipe chunk: "<itemID>" or "s<spellID>" (no item, e.g. enchants)

local _, ns = ...
local PREFIX = "Kinfolk"
local MAX = 240
local queue, sending = {}, false
local lastShare, lastAnswer = 0, 0

local function canSend() return ns.settings.share and ns.settings.welcomed and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage end

local function pump()
  local msg = table.remove(queue, 1)
  if not msg then sending = false; return end
  pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD")
  C_Timer.After(0.35, pump) -- stay well under the game's addon message throttle
end
local function send(msg)
  queue[#queue + 1] = msg
  if not sending then sending = true; C_Timer.After(0.1, pump) end
end

function ns.ShareProfessions(force)
  if not canSend() then return end
  if not force and GetTime() - lastShare < 60 then return end
  lastShare = GetTime()
  local me = ns.MyCrafting()
  if not me then return end
  for prof, p in pairs(me.professions or {}) do
    send(table.concat({ "H", prof, p.skill or 0, p.maxSkill or 0, #p.recipes, p.scannedAt or 0, me.class or "", me.offer and "1" or "0" }, "\t"))
    local head = "I\t" .. prof .. "\t"
    local chunk = {}
    local size = #head
    for _, r in ipairs(p.recipes) do
      local token = r.item and tostring(r.item) or (r.spell and ("s" .. r.spell))
      if token then
        if size + #token + 1 > MAX then send(head .. table.concat(chunk, " ")); chunk, size = {}, #head end
        chunk[#chunk + 1] = token; size = size + #token + 1
      end
    end
    if #chunk > 0 then send(head .. table.concat(chunk, " ")) end
  end
end

local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function onMessage(prefix, text, channel, sender)
  if prefix ~= PREFIX or channel ~= "GUILD" or ns.IsSecret(text) or ns.IsSecret(sender) then return end
  if not sender:find("-") then sender = sender .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or "") end
  if sender == ns.CharKey() then return end
  local c = ns.Crafting()
  if not c then return end
  local parts = { strsplit("\t", text) }
  local kind = parts[1]
  if kind == "Q" then
    -- answer after a random pause, at most every two minutes, so a whole guild doesn't reply at once
    if GetTime() - lastAnswer > 120 then
      lastAnswer = GetTime()
      C_Timer.After(5 + math.random() * 15, function() ns.ShareProfessions(true) end)
    end
  elseif kind == "H" and #parts >= 6 then
    local g = c.guild[sender] or { professions = {} }
    g.class = parts[7] ~= "" and parts[7] or g.class
    g.offer = parts[8] == "1"
    g.receivedAt = GetServerTime()
    g.professions[parts[2]] = { skill = tonumber(parts[3]), maxSkill = tonumber(parts[4]), expected = tonumber(parts[5]),
      scannedAt = tonumber(parts[6]), recipes = {} }
    c.guild[sender] = g
  elseif kind == "I" and #parts >= 3 then
    local g = c.guild[sender]
    local p = g and g.professions[parts[2]]
    if not p then return end
    for token in parts[3]:gmatch("%S+") do
      if token:sub(1, 1) == "s" then
        local spell = tonumber(token:sub(2))
        if spell then p.recipes[#p.recipes + 1] = { spell = spell, name = spellName(spell) } end
      else
        local item = tonumber(token)
        if item then p.recipes[#p.recipes + 1] = { item = item } end
      end
    end
  end
end

ns.RegisterModule({
  name = "GuildShare",
  OnLoad = function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
  end,
  events = {
    PLAYER_LOGIN = function()
      C_Timer.After(15, function()
        if canSend() then send("Q"); ns.ShareProfessions(true) end
      end)
    end,
    CHAT_MSG_ADDON = function(_, _, prefix, text, channel, sender) onMessage(prefix, text, channel, sender) end,
  },
})

table.insert(ns.statusLines, function()
  local c = ns.Crafting()
  if not c then return end
  local n = 0
  for _ in pairs(c.guild) do n = n + 1 end
  return string.format("Guild crafters heard from: %d. Sharing yours: %s.", n, ns.settings.share and "on" or "off")
end)
