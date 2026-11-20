--!strict
-- Lanes.luau: Client module for Runway Lanes (phase0 Step 2, docs/tasks/gemini_runway_lanes.md)
-- Owns:
-- 1. Highlighting local player's assigned lane (PlotId -> LaneId) in Chunky Nest yolk glow.
-- 2. Displaying "★ YOUR LANE ★" + Player Name on the lane start pad.
-- 3. Showing a non-intrusive directional hint when standing on the ledge outside your own lane.
-- 4. Exposing lane center X for Throw / ThrowCinematic to align flight cosmetic paths.
-- 5. Respects FLReduceMotion (no pulsing glow).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ctx = require(script.Parent.Ctx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))

local player = Players.LocalPlayer

local Lanes = {}

local activeHintGui: ScreenGui? = nil
local activeBreatheTween: Tween? = nil
local initialized = false
local cachedMyLaneId: number? = nil

-- Standard lane X centers:
local LANE_CENTERS: { [number]: number } = {
    [1] = -47.5,
    [2] = -50.5,
    [3] = -53.5,
    [4] = -56.5,
    [5] = -59.5,
    [6] = -62.5,
}

local function findLanesFolder(): Folder?
    local map = Workspace:FindFirstChild("EggSanctuaryMap")
    local ls = map and map:FindFirstChild("LaunchStation")
    local rf = ls and ls:FindFirstChild("RunwayLanes")
    return if rf and rf:IsA("Folder") then rf else nil
end

function Lanes.myLaneId(): number?
    if cachedMyLaneId then
        return cachedMyLaneId
    end
    local plotId = player:GetAttribute("PlotId")
    if type(plotId) == "number" and plotId >= 1 and plotId <= 6 then
        cachedMyLaneId = plotId
        return plotId
    end
    if Ctx.plot then
        local pId = Ctx.plot:GetAttribute("PlotId")
        if type(pId) == "number" and pId >= 1 and pId <= 6 then
            cachedMyLaneId = pId
            return pId
        end
    end
    return nil
end

function Lanes.padFor(laneId: number): BasePart?
    local folder = findLanesFolder()
    if not folder then
        return nil
    end
    local pad = folder:FindFirstChild("Lane_" .. laneId)
    return if pad and pad:IsA("BasePart") then pad else nil
end

function Lanes.myLanePad(): BasePart?
    local id = Lanes.myLaneId()
    return if id then Lanes.padFor(id) else nil
end

function Lanes.myLaneX(): number
    local id = Lanes.myLaneId()
    if id and LANE_CENTERS[id] then
        return LANE_CENTERS[id]
    end
    local pad = Lanes.myLanePad()
    if pad then
        return pad.Position.X
    end
    return -55 -- fallback to center of launch pad
end

function Lanes.isInMyLane(): boolean
    local id = Lanes.myLaneId()
    if not id then
        return false
    end
    local pad = Lanes.padFor(id)
    local root = Ctx.root()
    if not pad or not root then
        return false
    end
    local p = pad.CFrame:PointToObjectSpace(root.Position)
    return math.abs(p.X) <= pad.Size.X / 2 + 0.5
        and math.abs(p.Z) <= pad.Size.Z / 2 + 0.5
        and p.Y >= -0.2
        and p.Y <= 6
end

--------------------------------------------------------------------------------
-- Visual Styling & Glow
--------------------------------------------------------------------------------

local function updateLaneVisuals()
    local myId = Lanes.myLaneId()
    local folder = findLanesFolder()
    if not folder then
        return
    end

    for i = 1, 6 do
        local pad = folder:FindFirstChild("Lane_" .. i)
        if pad and pad:IsA("BasePart") then
            local isMine = (myId == i)
            local gui = pad:FindFirstChild("LaneGui")
            local bg = gui and gui:FindFirstChild("Bg")
            local stroke = bg and bg:FindFirstChild("Stroke") :: UIStroke?
            local numPill = bg and bg:FindFirstChild("NumberPill") :: TextLabel?
            local statusLbl = bg and bg:FindFirstChild("StatusLabel") :: TextLabel?
            local arrow = bg and bg:FindFirstChild("Arrow") :: TextLabel?

            if isMine then
                -- Chunky Nest Yolk Glow
                pad.Material = Enum.Material.Neon
                pad.Color = Color3.fromHex("FFC800")

                if stroke then
                    stroke.Color = Color3.fromHex("FFD700")
                    stroke.Thickness = 8
                end
                if numPill then
                    numPill.BackgroundColor3 = Color3.fromHex("FFC800")
                    numPill.TextColor3 = Color3.fromHex("1E293B")
                end
                if statusLbl then
                    statusLbl.BackgroundColor3 = Color3.fromHex("2C3A4A")
                    statusLbl.TextColor3 = Color3.fromHex("FFD700")
                    statusLbl.Text = "★ YOUR LANE ★"
                end
                if arrow then
                    arrow.TextColor3 = Color3.fromHex("FFD700")
                end

                -- Soft pulse breathe (if reduced motion is false)
                if not Ctx.reducedMotion() and not activeBreatheTween then
                    local info = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
                    activeBreatheTween = TweenService:Create(pad, info, { Color = Color3.fromHex("FFA000") })
                    activeBreatheTween:Play()
                elseif Ctx.reducedMotion() and activeBreatheTween then
                    activeBreatheTween:Cancel()
                    activeBreatheTween = nil
                    pad.Color = Color3.fromHex("FFC800")
                end
            else
                -- Neutral Slate
                pad.Material = Enum.Material.SmoothPlastic
                pad.Color = Color3.fromHex("2C3A4A")

                if stroke then
                    stroke.Color = Color3.fromHex("334155")
                    stroke.Thickness = 6
                end
                if numPill then
                    numPill.BackgroundColor3 = Color3.fromHex("0F172A")
                    numPill.TextColor3 = Color3.fromHex("F8FAFC")
                end
                if statusLbl then
                    statusLbl.BackgroundColor3 = Color3.fromHex("0F172A")
                    statusLbl.TextColor3 = Color3.fromHex("94A3B8")
                    statusLbl.Text = "PLOT " .. i
                end
                if arrow then
                    arrow.TextColor3 = Color3.fromHex("475569")
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Ledge Guidance Hint
--------------------------------------------------------------------------------

local function buildHintGui(): ScreenGui
    local pGui = player:FindFirstChildOfClass("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name = "FLLaneHintGui"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 14

    local frame = Instance.new("Frame")
    frame.Name = "HintCard"
    frame.Size = UDim2.fromOffset(260, 44)
    frame.Position = UDim2.new(0.5, 0, 0.78, 0) -- Cleanly above throw meter / bottom controls
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromHex("1E293B")
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("FFC800")
    stroke.Thickness = 3
    stroke.Parent = frame

    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 32, 1, 0)
    icon.Position = UDim2.new(0, 8, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "👉"
    icon.TextSize = 20
    icon.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Size = UDim2.new(1, -44, 1, 0)
    label.Position = UDim2.new(0, 40, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromHex("F8FAFC")
    label.FontFace = Theme.Fonts.title
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = "Head to your lane!"
    label.Parent = frame

    if pGui then
        sg.Parent = pGui
    end
    return sg
end

local function setHintVisible(visible: boolean, targetLane: number?)
    if visible and targetLane then
        if not activeHintGui then
            activeHintGui = buildHintGui()
        end
        activeHintGui.Enabled = true
        local card = activeHintGui:FindFirstChild("HintCard")
        local lbl = card and card:FindFirstChild("Text") :: TextLabel?
        local icon = card and card:FindFirstChild("Icon") :: TextLabel?
        if lbl and icon then
            local myX = Lanes.myLaneX()
            local root = Ctx.root()
            local isLeft = root and root.Position.X > myX
            icon.Text = if isLeft then "👈" else "👉"
            lbl.Text = string.format("Head to Lane %d (Your Lane)!", targetLane)
        end
    else
        if activeHintGui then
            activeHintGui.Enabled = false
        end
    end
end

--------------------------------------------------------------------------------
-- Initialization & Event Loop
--------------------------------------------------------------------------------

function Lanes.init()
    if initialized then
        return
    end
    initialized = true

    -- Listen to PlotId attribute changes
    player:GetAttributeChangedSignal("PlotId"):Connect(function()
        cachedMyLaneId = nil
        updateLaneVisuals()
    end)

    task.spawn(function()
        -- Wait for plot ID / assignment
        local waited = 0
        while not Lanes.myLaneId() and waited < 10 do
            waited += task.wait(0.2)
        end
        updateLaneVisuals()
    end)

    -- Step check: if player is on the launch ledge, but not in their lane, show hint
    RunService.Heartbeat:Connect(function()
        local myId = Lanes.myLaneId()
        if not myId then
            setHintVisible(false)
            return
        end

        local onLedge = Ctx.onLaunchPad()
        if onLedge then
            local inLane = Lanes.isInMyLane()
            if not inLane then
                setHintVisible(true, myId)
            else
                setHintVisible(false)
            end
        else
            setHintVisible(false)
        end
    end)
end

return Lanes
