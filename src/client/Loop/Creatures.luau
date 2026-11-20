--!strict
-- Creature looks (catchiness pass): each of the 15 species built from primitive parts with a distinct silhouette,
-- big shiny eyes and blush, plus rarity effects. No modeller yet: this is the best simple version (P-9 meshes
-- replace it). Model pivot = body centre, facing -Z; PrimaryPart "Body". Used by the pen, reveal and Book cards.

local Fx = require(script.Parent.Fx)

local Creatures = {}

type Spec = {
    color: Color3,
    accent: Color3,
    body: Vector3, -- body size as multiples of the radius
    head: number, -- head diameter as a multiple of the radius (0 = no separate head)
    headAt: Vector3, -- head centre in radii
    features: { string },
    particles: string?,
}

local rgb = Color3.fromRGB
local SPECS: { [string]: Spec } = {
    ["Meadow Bunny"] = {
        color = rgb(250, 246, 240),
        accent = rgb(255, 170, 190),
        body = Vector3.new(1.9, 1.7, 1.9),
        head = 1.4,
        headAt = Vector3.new(0, 0.95, -0.55),
        features = { "longEars", "puffTail", "nose" },
    },
    ["Moss Turtle"] = {
        color = rgb(150, 200, 110),
        accent = rgb(80, 135, 60),
        body = Vector3.new(1.8, 1.1, 2.0),
        head = 1.0,
        headAt = Vector3.new(0, 0.2, -1.15),
        features = { "shell", "stubLegs", "leafSprout" },
    },
    ["Clover Fawn"] = {
        color = rgb(215, 160, 100),
        accent = rgb(255, 250, 235),
        body = Vector3.new(1.4, 1.4, 2.0),
        head = 1.2,
        headAt = Vector3.new(0, 1.25, -0.95),
        features = { "longLegs", "spots", "antlers", "clover", "pointEars" },
    },
    ["Bog Frog"] = {
        color = rgb(120, 190, 70),
        accent = rgb(250, 230, 120),
        body = Vector3.new(2.1, 1.4, 1.8),
        head = 0,
        headAt = Vector3.new(0, 0.45, -0.6),
        features = { "frogEyes", "smile", "frogFeet" },
    },
    ["Slime Drake"] = {
        color = rgb(120, 235, 110),
        accent = rgb(60, 160, 60),
        body = Vector3.new(1.8, 1.6, 1.9),
        head = 1.2,
        headAt = Vector3.new(0, 1.0, -0.8),
        features = { "slime", "wings", "hornPair", "drakeTail" },
        particles = "drips",
    },
    ["Lily Croc"] = {
        color = rgb(70, 140, 95),
        accent = rgb(255, 150, 200),
        body = Vector3.new(1.5, 1.0, 2.6),
        head = 1.0,
        headAt = Vector3.new(0, 0.35, -1.45),
        features = { "snout", "lilyPad", "stubLegs", "backBumps", "drakeTail" },
    },
    ["Ember Hound"] = {
        color = rgb(235, 110, 50),
        accent = rgb(255, 210, 80),
        body = Vector3.new(1.5, 1.4, 2.1),
        head = 1.3,
        headAt = Vector3.new(0, 1.1, -1.0),
        features = { "pointEars", "longLegs", "flameTail", "nose" },
        particles = "embers",
    },
    ["Magma Newt"] = {
        color = rgb(60, 45, 45),
        accent = rgb(255, 120, 30),
        body = Vector3.new(1.3, 0.9, 2.8),
        head = 1.0,
        headAt = Vector3.new(0, 0.3, -1.6),
        features = { "glowStripes", "stubLegs", "drakeTail" },
        particles = "embers",
    },
    ["Ash Phoenix"] = {
        color = rgb(255, 170, 50),
        accent = rgb(255, 80, 40),
        body = Vector3.new(1.5, 1.6, 1.6),
        head = 1.1,
        headAt = Vector3.new(0, 1.15, -0.55),
        features = { "beak", "wings", "crest", "flameTail" },
        particles = "fire",
    },
    ["Bubble Seal"] = {
        color = rgb(170, 210, 240),
        accent = rgb(255, 255, 255),
        body = Vector3.new(1.6, 1.4, 2.3),
        head = 1.3,
        headAt = Vector3.new(0, 0.9, -1.0),
        features = { "flippers", "whiskers", "nose" },
        particles = "bubbles",
    },
    ["Coral Leviathan"] = {
        color = rgb(240, 115, 140),
        accent = rgb(255, 210, 120),
        body = Vector3.new(1.4, 1.3, 3.0),
        head = 1.3,
        headAt = Vector3.new(0, 0.7, -1.7),
        features = { "coral", "fins", "drakeTail", "hornPair" },
        particles = "bubbles",
    },
    ["Pearl Whale"] = {
        color = rgb(150, 180, 235),
        accent = rgb(250, 248, 255),
        body = Vector3.new(2.2, 1.7, 2.8),
        head = 0,
        headAt = Vector3.new(0, 0.3, -1.25),
        features = { "whaleTail", "pearl", "belly", "flippers" },
        particles = "sparkle",
    },
    ["Comet Fox"] = {
        color = rgb(255, 215, 110),
        accent = rgb(255, 255, 255),
        body = Vector3.new(1.4, 1.3, 2.0),
        head = 1.3,
        headAt = Vector3.new(0, 1.05, -0.95),
        features = { "pointEars", "longLegs", "foxTail", "nose" },
        particles = "stars",
    },
    ["Nebula Kirin"] = {
        color = rgb(175, 120, 245),
        accent = rgb(120, 240, 255),
        body = Vector3.new(1.4, 1.5, 2.1),
        head = 1.2,
        headAt = Vector3.new(0, 1.3, -1.0),
        features = { "longLegs", "unicorn", "mane", "pointEars" },
        particles = "stars",
    },
    ["Galaxy Titan"] = {
        color = rgb(60, 40, 120),
        accent = rgb(140, 220, 255),
        body = Vector3.new(2.3, 2.2, 1.8),
        head = 1.2,
        headAt = Vector3.new(0, 1.6, -0.3),
        features = { "titanArms", "stubLegs", "glowStripes", "crown" },
        particles = "stars",
    },
}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local RARITY_GLOW: { [string]: Color3 } = {
    Rare = rgb(59, 167, 255),
    Epic = rgb(182, 92, 255),
    Legendary = rgb(255, 200, 0),
    Mythic = rgb(255, 75, 110),
    Secret = rgb(255, 255, 255),
}

local function add(model: Model, name: string, size: Vector3, color: Color3, cf: CFrame, shape: Enum.PartType?): Part
    local p = Fx.part(name, size, color, shape or Enum.PartType.Ball)
    p.CFrame = cf
    p.Parent = model
    return p
end

local function wedge(model: Model, size: Vector3, color: Color3, cf: CFrame): WedgePart
    local w = Instance.new("WedgePart")
    w.Name = "Wedge"
    w.Size = size
    w.Color = color
    w.Material = Enum.Material.SmoothPlastic
    w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false, false
    w.CFrame = cf
    w.Parent = model
    return w
end

local function emitter(parent: Instance, kind: string, color: Color3)
    local e = Instance.new("ParticleEmitter")
    e.Name = "Fx_" .. kind
    e.LightEmission = 0.6
    e.Rate = 4
    e.Lifetime = NumberRange.new(0.8, 1.4)
    e.Speed = NumberRange.new(0.5, 1.5)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Size = NumberSequence.new(0.18, 0)
    e.Color = ColorSequence.new(color)
    if kind == "bubbles" then
        e.Color = ColorSequence.new(rgb(220, 245, 255))
        e.Size = NumberSequence.new(0.15, 0.3)
        e.Transparency = NumberSequence.new(0.3, 1)
        e.Acceleration = Vector3.new(0, 2, 0)
    elseif kind == "embers" or kind == "fire" then
        e.Color = ColorSequence.new(rgb(255, 200, 60), rgb(255, 70, 20))
        e.Acceleration = Vector3.new(0, 3, 0)
        e.Rate = if kind == "fire" then 10 else 5
    elseif kind == "drips" then
        e.Color = ColorSequence.new(color)
        e.Acceleration = Vector3.new(0, -6, 0)
        e.Rate = 2
    elseif kind == "stars" or kind == "sparkle" then
        e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        e.Size = NumberSequence.new(0.35, 0)
        e.Rate = 5
    end
    e.Parent = parent
end

-- Builds the model. r = body radius in studs (bigger for rarer creatures).
function Creatures.build(species: string, r: number, mutation: string, rarity: string): Model
    local spec = SPECS[species] or SPECS["Meadow Bunny"]
    local color, accent = spec.color, spec.accent
    if mutation == "Shiny" then
        color = color:Lerp(rgb(150, 220, 255), 0.45)
    elseif mutation == "Golden" then
        color = rgb(255, 200, 40)
    end
    local model = Instance.new("Model")
    model.Name = species
    local body = add(model, "Body", spec.body * r, color, CFrame.new())
    if mutation == "Golden" then
        body.Material = Enum.Material.Metal
    end
    model.PrimaryPart = body
    local headCF = CFrame.new(spec.headAt * r)
    local headR = spec.head * r / 2
    if spec.head > 0 then
        add(model, "Head", Vector3.one * spec.head * r, color, headCF)
    else
        headR = math.min(spec.body.X, spec.body.Y) * r / 2 -- face on the body itself
    end
    local face = headCF * CFrame.new(0, 0, -headR * 0.82)

    -- big cute eyes with a highlight, and blush (frogs have their own eyes)
    if not table.find(spec.features, "frogEyes") then
        for _, x in { -1, 1 } do
            local eye = add(
                model,
                "Eye",
                Vector3.one * headR * 0.42,
                rgb(25, 20, 35),
                face * CFrame.new(x * headR * 0.38, headR * 0.15, 0)
            )
            add(
                model,
                "Shine",
                Vector3.one * headR * 0.15,
                rgb(255, 255, 255),
                eye.CFrame * CFrame.new(-0.05 * r, 0.06 * r, -0.12 * headR)
            )
            add(
                model,
                "Blush",
                Vector3.new(headR * 0.32, headR * 0.16, headR * 0.1),
                rgb(255, 150, 170),
                face * CFrame.new(x * headR * 0.55, -headR * 0.2, headR * 0.12)
            )
        end
    end

    local back = spec.body.Z * r / 2
    local top = spec.body.Y * r / 2
    local side = spec.body.X * r / 2
    for _, f in spec.features do
        if f == "longEars" then
            for _, x in { -1, 1 } do
                add(
                    model,
                    "Ear",
                    Vector3.new(0.35, 1.3, 0.25) * r,
                    color,
                    headCF * CFrame.new(x * headR * 0.45, headR * 1.15, 0.05 * r) * CFrame.Angles(0, 0, -x * 0.15)
                )
                add(
                    model,
                    "EarIn",
                    Vector3.new(0.2, 0.95, 0.12) * r,
                    accent,
                    headCF * CFrame.new(x * headR * 0.45, headR * 1.1, -0.08 * r) * CFrame.Angles(0, 0, -x * 0.15)
                )
            end
        elseif f == "pointEars" then
            for _, x in { -1, 1 } do
                wedge(
                    model,
                    Vector3.new(0.15, 0.55, 0.4) * r,
                    color,
                    headCF * CFrame.new(x * headR * 0.55, headR * 0.95, 0) * CFrame.Angles(0, math.rad(90 * x), 0)
                )
            end
        elseif f == "puffTail" then
            add(model, "Tail", Vector3.one * 0.6 * r, accent:Lerp(color, 0.7), CFrame.new(0, 0, back))
        elseif f == "nose" then
            add(model, "Nose", Vector3.one * headR * 0.22, accent, face * CFrame.new(0, -headR * 0.08, -headR * 0.1))
        elseif f == "shell" then
            local shell = add(
                model,
                "Shell",
                Vector3.new(spec.body.X * 1.1, spec.body.Y * 1.1, spec.body.Z * 0.95) * r,
                accent,
                CFrame.new(0, top * 0.45, 0.1 * r)
            )
            shell.Material = Enum.Material.Slate
            for i = 0, 4 do
                local a = i / 5 * math.pi * 2
                add(
                    model,
                    "Plate",
                    Vector3.new(0.5, 0.15, 0.5) * r,
                    accent:Lerp(rgb(255, 255, 200), 0.3),
                    CFrame.new(math.cos(a) * side * 0.5, top * 1.05, math.sin(a) * back * 0.45 + 0.1 * r),
                    Enum.PartType.Cylinder
                )
            end
        elseif f == "stubLegs" or f == "longLegs" or f == "frogFeet" then
            local h = if f == "longLegs" then 1.0 * r else 0.45 * r
            for _, x in { -1, 1 } do
                for _, z in { -1, 1 } do
                    local leg = add(
                        model,
                        "Leg",
                        Vector3.new(0.35 * r, h, 0.35 * r),
                        color:Lerp(rgb(0, 0, 0), 0.12),
                        CFrame.new(x * side * 0.6, -top * 0.75 - h * 0.3, z * back * 0.55),
                        Enum.PartType.Block
                    )
                    if f == "frogFeet" then
                        leg.Size = Vector3.new(0.7, 0.2, 0.6) * r
                    end
                end
            end
        elseif f == "spots" then
            for i = 1, 5 do
                local a = i * 2.3
                add(
                    model,
                    "Spot",
                    Vector3.one * 0.28 * r,
                    accent,
                    CFrame.new(
                        math.cos(a) * side * 0.85,
                        top * (0.2 + 0.1 * math.sin(i)),
                        math.sin(a) * back * 0.6 + 0.2 * r
                    )
                )
            end
        elseif f == "antlers" then
            for _, x in { -1, 1 } do
                add(
                    model,
                    "Antler",
                    Vector3.new(0.9, 0.12, 0.12) * r,
                    rgb(240, 225, 190),
                    headCF * CFrame.new(x * headR * 0.4, headR * 1.2, 0) * CFrame.Angles(0, 0, math.rad(90 - 25 * x)),
                    Enum.PartType.Cylinder
                )
                add(
                    model,
                    "Tine",
                    Vector3.new(0.4, 0.1, 0.1) * r,
                    rgb(240, 225, 190),
                    headCF * CFrame.new(x * headR * 0.65, headR * 1.4, 0) * CFrame.Angles(0, 0, math.rad(40 * x)),
                    Enum.PartType.Cylinder
                )
            end
        elseif f == "clover" then
            for i = 0, 2 do
                local a = i / 3 * math.pi * 2
                add(
                    model,
                    "Leaf",
                    Vector3.new(0.3, 0.08, 0.3) * r,
                    rgb(70, 190, 70),
                    headCF * CFrame.new(math.cos(a) * 0.15 * r, headR * 1.02, math.sin(a) * 0.15 * r)
                )
            end
        elseif f == "leafSprout" then
            add(
                model,
                "Sprout",
                Vector3.new(0.5, 0.08, 0.3) * r,
                rgb(90, 200, 70),
                CFrame.new(0, top * 1.25, 0.1 * r) * CFrame.Angles(0, 0, 0.5)
            )
        elseif f == "frogEyes" then
            for _, x in { -1, 1 } do
                local bump = add(
                    model,
                    "EyeBump",
                    Vector3.one * 0.75 * r,
                    color,
                    CFrame.new(x * side * 0.45, top * 0.85, -back * 0.35)
                )
                local eye = add(
                    model,
                    "Eye",
                    Vector3.one * 0.45 * r,
                    rgb(25, 20, 35),
                    bump.CFrame * CFrame.new(0, 0.05 * r, -0.2 * r)
                )
                add(
                    model,
                    "Shine",
                    Vector3.one * 0.15 * r,
                    rgb(255, 255, 255),
                    eye.CFrame * CFrame.new(-0.07 * r, 0.08 * r, -0.15 * r)
                )
            end
            add(
                model,
                "Blush",
                Vector3.new(0.3, 0.15, 0.1) * r,
                rgb(255, 150, 170),
                CFrame.new(-side * 0.6, 0, -back * 0.85)
            )
            add(
                model,
                "Blush",
                Vector3.new(0.3, 0.15, 0.1) * r,
                rgb(255, 150, 170),
                CFrame.new(side * 0.6, 0, -back * 0.85)
            )
        elseif f == "smile" then
            add(
                model,
                "Mouth",
                Vector3.new(1.0, 0.08, 0.1) * r,
                rgb(60, 40, 40),
                CFrame.new(0, -0.05 * r, -back * 0.97),
                Enum.PartType.Block
            )
            add(model, "Belly", Vector3.new(1.5, 0.9, 0.3) * r, accent, CFrame.new(0, -0.25 * r, -back * 0.8))
        elseif f == "slime" then
            body.Material = Enum.Material.Glass
            body.Transparency = 0.15
        elseif f == "wings" then
            for _, x in { -1, 1 } do
                add(
                    model,
                    "Wing",
                    Vector3.new(1.4, 0.15, 0.8) * r,
                    accent,
                    CFrame.new(x * side * 1.1, top * 0.6, 0.2 * r) * CFrame.Angles(0, 0, math.rad(25 * x))
                )
            end
        elseif f == "hornPair" then
            for _, x in { -1, 1 } do
                wedge(
                    model,
                    Vector3.new(0.12, 0.5, 0.3) * r,
                    rgb(255, 245, 220),
                    headCF * CFrame.new(x * headR * 0.4, headR * 0.95, 0.05 * r)
                )
            end
        elseif f == "drakeTail" then
            add(model, "Tail", Vector3.new(0.4, 0.4, 1.2) * r, color, CFrame.new(0, -top * 0.2, back + 0.4 * r))
            add(model, "TailTip", Vector3.new(0.25, 0.25, 0.6) * r, accent, CFrame.new(0, -top * 0.25, back + 1.0 * r))
        elseif f == "snout" then
            add(
                model,
                "Snout",
                Vector3.new(0.8, 0.5, 1.2) * r,
                color,
                headCF * CFrame.new(0, -0.1 * r, -headR - 0.35 * r)
            )
            for _, x in { -1, 1 } do
                add(
                    model,
                    "Tooth",
                    Vector3.new(0.12, 0.15, 0.12) * r,
                    rgb(255, 255, 255),
                    headCF * CFrame.new(x * 0.25 * r, -0.35 * r, -headR - 0.6 * r),
                    Enum.PartType.Block
                )
            end
        elseif f == "lilyPad" then
            add(
                model,
                "Pad",
                Vector3.new(0.12, 1.3, 1.3) * r,
                rgb(80, 180, 90),
                headCF * CFrame.new(0, headR * 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)),
                Enum.PartType.Cylinder
            )
            add(model, "Flower", Vector3.one * 0.45 * r, accent, headCF * CFrame.new(0.15 * r, headR * 1.15, 0))
        elseif f == "backBumps" then
            for i = -1, 1 do
                add(
                    model,
                    "Bump",
                    Vector3.new(0.3, 0.3, 0.35) * r,
                    accent:Lerp(color, 0.6),
                    CFrame.new(0, top * 0.95, i * back * 0.4),
                    Enum.PartType.Block
                )
            end
        elseif f == "flameTail" then
            local tail = add(
                model,
                "Tail",
                Vector3.new(0.35, 0.35, 0.9) * r,
                accent,
                CFrame.new(0, top * 0.4, back + 0.3 * r) * CFrame.Angles(math.rad(35), 0, 0)
            )
            tail.Material = Enum.Material.Neon
            local fire = Instance.new("Fire")
            fire.Size = 2 * r
            fire.Heat = 4
            fire.Parent = tail
        elseif f == "glowStripes" then
            for i = -1, 1 do
                local s = add(
                    model,
                    "Glow",
                    Vector3.new(spec.body.X * 1.02, 0.12, 0.2) * r,
                    accent,
                    CFrame.new(0, top * 0.3, i * back * 0.45),
                    Enum.PartType.Block
                )
                s.Material = Enum.Material.Neon
            end
        elseif f == "beak" then
            wedge(
                model,
                Vector3.new(0.3, 0.3, 0.6) * r,
                rgb(255, 200, 60),
                face * CFrame.new(0, -0.1 * r, -0.2 * r) * CFrame.Angles(0, math.rad(180), 0)
            )
        elseif f == "crest" then
            for i = -1, 1 do
                local c = add(
                    model,
                    "Crest",
                    Vector3.new(0.15, 0.6, 0.25) * r,
                    accent,
                    headCF * CFrame.new(0, headR * 1.1, i * 0.2 * r) * CFrame.Angles(math.rad(-20 * i), 0, 0)
                )
                c.Material = Enum.Material.Neon
            end
        elseif f == "flippers" then
            for _, x in { -1, 1 } do
                add(
                    model,
                    "Flipper",
                    Vector3.new(0.9, 0.15, 0.5) * r,
                    color:Lerp(rgb(0, 0, 0), 0.15),
                    CFrame.new(x * side * 1.0, -top * 0.5, -back * 0.2) * CFrame.Angles(0, 0, math.rad(-20 * x))
                )
            end
        elseif f == "whiskers" then
            for _, x in { -1, 1 } do
                add(
                    model,
                    "Whisker",
                    Vector3.new(0.6, 0.04, 0.04) * r,
                    rgb(255, 255, 255),
                    face * CFrame.new(x * headR * 0.6, -headR * 0.15, -0.05 * r),
                    Enum.PartType.Block
                )
            end
        elseif f == "coral" then
            for i = 1, 5 do
                local c = add(
                    model,
                    "Coral",
                    Vector3.new(0.7, 0.18, 0.18) * r,
                    accent,
                    CFrame.new((i % 2 - 0.5) * 0.4 * r, top * 1.1, (i - 3) * back * 0.3)
                        * CFrame.Angles(0, 0, math.rad(90 + (i % 3 - 1) * 25)),
                    Enum.PartType.Cylinder
                )
                c.Material = Enum.Material.Neon
            end
        elseif f == "fins" then
            wedge(model, Vector3.new(0.15, 0.8, 1.0) * r, accent, CFrame.new(0, top * 1.0, 0))
        elseif f == "whaleTail" then
            add(
                model,
                "Fluke",
                Vector3.new(1.8, 0.2, 0.7) * r,
                color,
                CFrame.new(0, top * 0.3, back + 0.3 * r) * CFrame.Angles(math.rad(-20), 0, 0)
            )
        elseif f == "pearl" then
            local pearl = add(model, "Pearl", Vector3.one * 0.6 * r, accent, CFrame.new(0, top * 1.05, -back * 0.2))
            pearl.Material = Enum.Material.Glass
            pearl.Reflectance = 0.4
        elseif f == "belly" then
            add(
                model,
                "Belly",
                Vector3.new(spec.body.X * 0.8, spec.body.Y * 0.55, spec.body.Z * 0.85) * r,
                accent,
                CFrame.new(0, -top * 0.35, -0.1 * r)
            )
        elseif f == "foxTail" then
            local tail = add(
                model,
                "Tail",
                Vector3.new(0.6, 0.6, 1.5) * r,
                color,
                CFrame.new(0, top * 0.5, back + 0.5 * r) * CFrame.Angles(math.rad(40), 0, 0)
            )
            add(model, "TailTip", Vector3.one * 0.55 * r, accent, tail.CFrame * CFrame.new(0, 0, 0.65 * r))
        elseif f == "unicorn" then
            local horn = add(
                model,
                "Horn",
                Vector3.new(0.9, 0.16, 0.16) * r,
                accent,
                headCF * CFrame.new(0, headR * 1.15, -headR * 0.3) * CFrame.Angles(0, 0, math.rad(80)),
                Enum.PartType.Cylinder
            )
            horn.Material = Enum.Material.Neon
        elseif f == "mane" then
            for i = 0, 3 do
                local m = add(
                    model,
                    "Mane",
                    Vector3.new(0.3, 0.45, 0.3) * r,
                    accent,
                    headCF * CFrame.new(0, headR * 0.6 - i * 0.3 * r, headR * 0.7 + i * 0.2 * r)
                )
                m.Material = Enum.Material.Neon
            end
        elseif f == "titanArms" then
            for _, x in { -1, 1 } do
                add(
                    model,
                    "Arm",
                    Vector3.new(0.8, 1.6, 0.8) * r,
                    color:Lerp(accent, 0.15),
                    CFrame.new(x * (side + 0.45 * r), -0.1 * r, 0)
                )
            end
        elseif f == "crown" then
            for i = -1, 1 do
                local c = wedge(
                    model,
                    Vector3.new(0.15, 0.45, 0.3) * r,
                    accent,
                    headCF * CFrame.new(i * 0.3 * r, headR * 1.05, 0)
                )
                c.Material = Enum.Material.Neon
            end
        end
    end

    if spec.particles then
        emitter(body, spec.particles, accent)
    end
    -- rarity effects: Rare+ sparkle in the rarity colour, Epic+ glow, Legendary+ a halo ring under the feet
    local rank = table.find(RARITY_ORDER, rarity) or 1
    local glow = RARITY_GLOW[rarity]
    if glow then
        local s = Instance.new("Sparkles")
        s.SparkleColor = glow
        s.Parent = body
    end
    if glow and rank >= 4 then
        local light = Instance.new("PointLight")
        light.Color = glow
        light.Range = 4 + rank
        light.Brightness = 0.7
        light.Parent = body
    end
    if glow and rank >= 5 then
        local ring = add(
            model,
            "Halo",
            Vector3.new(0.1, spec.body.X * 1.6 * r, spec.body.X * 1.6 * r),
            glow,
            CFrame.new(0, -top - 0.35 * r, 0) * CFrame.Angles(0, 0, math.rad(90)),
            Enum.PartType.Cylinder
        )
        ring.Material = Enum.Material.Neon
        ring.Transparency = 0.4
    end
    if mutation == "Shiny" or mutation == "Rainbow" then
        local s = Instance.new("Sparkles")
        s.SparkleColor = rgb(170, 230, 255)
        s.Parent = body
    end
    return model
end

-- Ground clearance below the body centre (legs and halos hang below the body)
function Creatures.footDrop(species: string, r: number): number
    local spec = SPECS[species] or SPECS["Meadow Bunny"]
    local top = spec.body.Y * r / 2
    for _, f in spec.features do
        if f == "longLegs" then
            return top * 0.75 + r * 0.8
        elseif f == "stubLegs" or f == "frogFeet" then
            return top * 0.75 + r * 0.38
        end
    end
    return top
end

return Creatures
