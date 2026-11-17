local SoundHelper = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")

function SoundHelper.Play(soundName, parent)
    pcall(function()
        local template = Sounds:FindFirstChild(soundName)
        if template then
            local clone = template:Clone()
            clone.Parent = parent or SoundService
            clone:Play()
            clone.Ended:Connect(function()
                clone:Destroy()
            end)
            task.delay(3, function()
                if clone and clone.Parent then
                    clone:Destroy()
                end
            end)
        end
    end)
end

return SoundHelper
