-- Foxden: one queue for every hidden addon message we send.
-- The game allows a short burst of addon messages per prefix and then about one
-- a second; anything faster is dropped. Everything goes through ns.Send so all
-- modules share that budget, and a message the game refuses is retried.
--
--   ns.Send(text, channel, target, urgent)   channel "GUILD" or "WHISPER" (target = "Name-Realm")
--   urgent = true puts it at the front (small, time-sensitive messages like positions)

local _, ns = ...
ns.PREFIX = "Foxden"

local BURST, REGEN = 8, 1.1 -- messages, seconds per message after the burst
local queue, tokens, last, running = {}, BURST, 0, false

local function refill()
  local now = GetTime()
  tokens = math.min(BURST, tokens + (now - last) / REGEN)
  last = now
end

-- C_ChatInfo.SendAddonMessage returns true/nil on older clients and a result code
-- (0 = sent) on newer ones. Anything else means "not now".
local function sent(ok, res)
  if not ok then return true end -- a hard error won't succeed on retry; drop it
  return res == nil or res == true or res == 0
end

local pump
pump = function()
  refill()
  local item = queue[1]
  if not item then running = false; return end
  if tokens < 1 then C_Timer.After(REGEN, pump); return end
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then wipe(queue); running = false; return end
  if sent(pcall(C_ChatInfo.SendAddonMessage, ns.PREFIX, item.text, item.channel, item.target)) then
    table.remove(queue, 1)
    tokens = tokens - 1
    if item.done then pcall(item.done) end
    C_Timer.After(0.05, pump)
  else
    tokens = 0
    C_Timer.After(2, pump) -- throttled: back off, then try the same message again
  end
end

function ns.Send(text, channel, target, urgent, done)
  local item = { text = text, channel = channel or "GUILD", target = target, done = done }
  if urgent then table.insert(queue, 1, item) else queue[#queue + 1] = item end
  if not running then running = true; last = last == 0 and GetTime() or last; C_Timer.After(0, pump) end
end

-- How many messages are still waiting (the relay waits for its own to drain).
function ns.SendQueueLength() return #queue end
