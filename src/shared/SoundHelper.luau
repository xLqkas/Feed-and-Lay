local SoundHelper = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local Sounds = ReplicatedStorage:FindFirstChild("Sounds")
if not Sounds then
    Sounds = Instance.new("Folder")
    Sounds.Name = "Sounds"
    Sounds.Parent = ReplicatedStorage
end

function SoundHelper.Play(soundName, parent)
    pcall(function()
        local template = Sounds:FindFirstChild(soundName)
        if not template then return end

        -- Positional check: server should never play non-positional sounds in SoundService
        if RunService:IsServer() and not parent then
            return
        end

        local clone = template:Clone()
        clone.Parent = parent or SoundService
        clone:Play()

        local conn
        conn = clone.Ended:Connect(function()
            if conn then conn:Disconnect() end
            clone:Destroy()
        end)

        -- Generous safety cleanup (20s) so longer clips/fanfares are not cut off
        task.delay(20, function()
            if clone and clone.Parent then
                if conn then conn:Disconnect() end
                clone:Destroy()
            end
        end)
    end)
end

return SoundHelper
