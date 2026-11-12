-- Foxden: compact JSON for runs that leave the game (the copy box and the relay).
-- Only encodes: the website and the companion parse it. "|" is escaped because
-- the game treats it as a formatting code in text boxes and chat.

local _, ns = ...

local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["|"] = "\\u007c" }
local function str(s)
  return '"' .. s:gsub('[%c"\\|]', function(c) return ESC[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end

local function isArray(t)
  local n = #t
  if n == 0 then return next(t) == nil end
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then return false end
  end
  return true
end

local encode
encode = function(v, out, depth)
  local tv = type(v)
  if depth > 20 then out[#out + 1] = "null"; return end
  if tv == "string" then out[#out + 1] = str(v)
  elseif tv == "number" then
    if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = "null"
    elseif v % 1 == 0 and math.abs(v) < 1e15 then out[#out + 1] = string.format("%d", v)
    else out[#out + 1] = string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", "") end
  elseif tv == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif tv == "table" then
    if isArray(v) then
      out[#out + 1] = "["
      for i = 1, #v do
        if i > 1 then out[#out + 1] = "," end
        encode(v[i], out, depth + 1)
      end
      out[#out + 1] = "]"
    else
      out[#out + 1] = "{"
      local first = true
      for k, val in pairs(v) do
        local tk = type(k)
        if (tk == "string" or tk == "number") and type(val) ~= "function" and type(val) ~= "userdata" then
          if not first then out[#out + 1] = "," end
          first = false
          out[#out + 1] = str(tostring(k)); out[#out + 1] = ":"
          encode(val, out, depth + 1)
        end
      end
      out[#out + 1] = "}"
    end
  else out[#out + 1] = "null" end
end

function ns.ToJSON(v)
  local out = {}
  encode(v, out, 0)
  return table.concat(out)
end

-- A finished run as text that can travel: the walking path is thinned so the
-- whole thing stays small (the boss kills, floors and pins are kept in full).
local MAX_PATH = 400
function ns.RunForTransfer(run)
  local copy = {}
  for k, v in pairs(run) do copy[k] = v end
  local route = run.route
  if type(route) == "table" and type(route.path) == "table" and #route.path > MAX_PATH then
    local r = {}
    for k, v in pairs(route) do r[k] = v end
    local step, path = #route.path / MAX_PATH, {}
    for i = 1, MAX_PATH do path[i] = route.path[math.floor((i - 1) * step) + 1] end
    path[#path] = route.path[#route.path]
    r.path = path
    copy.route = r
  end
  copy.loggedByRealm = copy.loggedByRealm or ((GetNormalizedRealmName and GetNormalizedRealmName()) or nil)
  return ns.ToJSON(copy)
end

-- The paste code: "FOXDEN1:" + the run. The website checks the prefix.
function ns.RunCode(run) return "FOXDEN1:" .. ns.RunForTransfer(run) end
