--!strict
-- Sounds for the loop (design-v3 section 8). Creator Store audio, checked to load in Studio: see
-- docs/ai/client-v3-notes.md. Client-made sounds play only for this player. 3D sounds stop at 60 studs.

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Sfx = {}

Sfx.ids = {
    charge = "rbxassetid://123796710194563", -- Whoosh Swinging Sound (pitch follows the needle)
    throw = "rbxassetid://138890894929151", -- Whoosh2
    ding = "rbxassetid://4612374495", -- bling_diamond_pickup_3 (SWEET)
    nom = "rbxassetid://137096768206416", -- eat_crunchybread
    cluck = "rbxassetid://77584650945481", -- chicken cluck
    thunk = "rbxassetid://9119319842", -- Soccer Ball Bounces Hits On Grass 4 (ProSoundEffects)
    hiss = "rbxassetid://9126200774", -- Water Spray Hose (ProSoundEffects), looped
    splat = "rbxassetid://12222152", -- splat.wav (Roblox)
    chime = "rbxassetid://4612374036", -- bling_big_diamond_pickup (wash done)
    squeak = "rbxassetid://9114617189", -- Glass Squeak 2 (ProSoundEffects): squeaky clean
    clank = "rbxassetid://9117851788", -- Pot Clank Put Down Metal Lid (ProSoundEffects): barbell plates
    grunt = "rbxassetid://117404652750890", -- Terra effort grunt 2 (Creator Store): perfect lift
    crack = "rbxassetid://9113959343", -- Crack Egg Crunchy 11 (ProSoundEffects)
    tick = "rbxasset://sounds/clickfast.wav", -- built into the client
    bonk = "rbxasset://sounds/button.wav", -- built into the client
    fanfare1 = "rbxassetid://1844016113", -- White Sands sting (APM): Common, Uncommon
    fanfare2 = "rbxassetid://1839881844", -- Spinning Around (APM): Rare, Epic
    fanfare3 = "rbxassetid://1840076509", -- Through the Roof sting (APM): Legendary and up
}

local VOLUME = 0.6

local function make(name: string, pitch: number?, volume: number?): Sound
    local s = Instance.new("Sound")
    s.Name = "FL_" .. name
    s.SoundId = Sfx.ids[name] or ""
    s.Volume = (volume or 1) * VOLUME
    s.PlaybackSpeed = pitch or 1
    s.RollOffMaxDistance = 60
    s.RollOffMinDistance = 8
    return s
end

-- One-shot. With `at` the sound is 3D at that point, otherwise a UI sound.
function Sfx.play(name: string, pitch: number?, volume: number?, at: Vector3?): Sound
    local s = make(name, pitch, volume)
    if at then
        local a = Instance.new("Attachment")
        a.WorldPosition = at
        a.Parent = Workspace.Terrain
        s.Parent = a
        s.Ended:Once(function()
            a:Destroy()
        end)
        task.delay(10, function()
            a:Destroy()
        end)
    else
        s.Parent = SoundService
        s.Ended:Once(function()
            s:Destroy()
        end)
        task.delay(10, function()
            s:Destroy()
        end)
    end
    s:Play()
    return s
end

-- Looped UI sound; the caller stops and destroys it
function Sfx.loop(name: string, volume: number?): Sound
    local s = make(name, 1, volume)
    s.Looped = true
    s.Parent = SoundService
    s:Play()
    return s
end

return Sfx
