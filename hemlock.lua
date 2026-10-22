local HttpService = game:GetService("HttpService")

local KEYS_URL   = "https://raw.githubusercontent.com/torturedskinnn/hemlock/main/keys.json"
local SCRIPT_URL = "https://raw.githubusercontent.com/torturedskinnn/hemlock/main/hemlock_main.lua"
local VERSION    = "1.0.0"

local key = (shared.Hemlock and shared.Hemlock['General'] and shared.Hemlock['General']['Key']) or ""

local success, result = pcall(function()
    return HttpService:JSONDecode(game:HttpGet(KEYS_URL))
end)

if not success then
    error("[Hemlock] Failed to reach key server.")
    return
end

local valid = false
for _, v in ipairs(result) do
    if v == key then
        valid = true
        break
    end
end

if not valid then
    error("[Hemlock] Invalid key.")
    return
end

print("[Hemlock] v" .. VERSION .. " — Key accepted. Loading...")

local ok, err = pcall(function()
    loadstring(game:HttpGet(SCRIPT_URL))()
end)

if not ok then
    error("[Hemlock] Load failed: " .. tostring(err))
end
