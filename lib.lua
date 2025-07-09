local DripESP = {}
local connections = {}
local all_settings = {}
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local rootPart = char:WaitForChild("HumanoidRootPart")
local runService = game:GetService("RunService")

local objectCache = {}
local frameConnections = {}
local espFolder = nil

local function initializeESPFolder()
	if not espFolder then
		local screenGui = player.PlayerGui:FindFirstChild("ScreenGui")
		if not screenGui then
			screenGui = Instance.new("ScreenGui")
			screenGui.Name = "ScreenGui"
			screenGui.Parent = player.PlayerGui
		end

		espFolder = screenGui:FindFirstChild("EspWuSan")
		if not espFolder then
			espFolder = Instance.new("Folder")
			espFolder.Name = "EspWuSan"
			espFolder.Parent = screenGui
		end
	end
	return espFolder
end

local LinePositions = {
	Top = "Top",
	Middle = "Middle",
	Bottom = "Bottom",
}

function DripESP.SetOptions(ESP_ID, opts)
	all_settings[ESP_ID] = {
		TargetName = opts.TargetName or opts.ModelName or "Model",
		CustomText = opts.CustomText or "目标",
		TextColor = opts.TextColor or Color3.fromRGB(0, 255, 255),
		OutlineColor = opts.OutlineColor or Color3.fromRGB(255, 0, 0),
		TextSize = opts.TextSize or 15,
		HighlightName = "ESP_Highlight_" .. ESP_ID,
		BillboardName = "ESP_Billboard_" .. ESP_ID,
		LineName = "ESP_Line_" .. ESP_ID,
		FolderName = "ESP_Folder_" .. ESP_ID,
		CheckForHumanoid = opts.CheckForHumanoid or false,
		TargetType = opts.TargetType or "Both",
		LinePosition = opts.LinePosition or LinePositions.Middle,

		LineColor = opts.LineColor or opts.OutlineColor or Color3.fromRGB(255, 0, 0),
		EnableLine = opts.EnableLine ~= false,
	}
	objectCache[ESP_ID] = {}
end

local function getESPSubFolder(ESP_ID)
	local mainFolder = initializeESPFolder()
	local settings = all_settings[ESP_ID]
	if not settings then
		return mainFolder
	end

	local subFolder = mainFolder:FindFirstChild(settings.FolderName)
	if not subFolder then
		subFolder = Instance.new("Folder")
		subFolder.Name = settings.FolderName
		subFolder.Parent = mainFolder
	end
	return subFolder
end

local function createLine(target, ESP_ID, settings)
	if not settings.EnableLine then
		return
	end

	local subFolder = getESPSubFolder(ESP_ID)
	if subFolder:FindFirstChild(settings.LineName .. "_" .. target.Name) then
		return
	end

	local targetPart = getTargetPart(target)
	if not targetPart then
		return
	end

	local line = Instance.new("Frame")
	line.Name = settings.LineName .. "_" .. target.Name
	line.Parent = subFolder
	line.BackgroundColor3 = settings.LineColor
	line.BorderSizePixel = 0
	line.Size = UDim2.new(0, 2, 0, 0)
	line.Position = UDim2.new(0.5, 0, 0.5, 0)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.ZIndex = 1000
	line.Visible = false

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, settings.LineColor),
		ColorSequenceKeypoint.new(
			1,
			Color3.new(settings.LineColor.R * 0.7, settings.LineColor.G * 0.7, settings.LineColor.B * 0.7)
		),
	})
	gradient.Parent = line

	if not objectCache[ESP_ID][target] then
		objectCache[ESP_ID][target] = {}
	end
	objectCache[ESP_ID][target].line = line
	objectCache[ESP_ID][target].targetPart = targetPart
	objectCache[ESP_ID][target].gradient = gradient
end

function getTargetPart(target)
	if target:IsA("Model") then
		return target:FindFirstChild("HumanoidRootPart")
			or target:FindFirstChild("Torso")
			or target:FindFirstChild("Head")
			or target:FindFirstChildWhichIsA("BasePart")
	else
		return target
	end
end

local function updateLine(target, ESP_ID, settings)
	local cache = objectCache[ESP_ID] and objectCache[ESP_ID][target]
	if not cache or not cache.line or not cache.targetPart then
		return
	end

	local line = cache.line
	local targetPart = cache.targetPart

	if not targetPart.Parent or not target.Parent then
		line:Destroy()
		objectCache[ESP_ID][target] = nil
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local targetPos = targetPart.Position
	local screenPoint, onScreen = camera:WorldToScreenPoint(targetPos)

	if not onScreen then
		line.Visible = false
		return
	end

	line.Visible = true

	local screenSize = camera.ViewportSize
	local targetScreenPos = Vector2.new(screenPoint.X, screenPoint.Y)

	local startPos
	if settings.LinePosition == LinePositions.Top then
		startPos = Vector2.new(screenSize.X / 2, 0)
	elseif settings.LinePosition == LinePositions.Bottom then
		startPos = Vector2.new(screenSize.X / 2, screenSize.Y)
	else
		startPos = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
	end

	local direction = (targetScreenPos - startPos)
	local distance = direction.Magnitude
	local angle = math.atan2(direction.Y, direction.X)

	local lastDistance = cache.lastDistance or 0
	local lastAngle = cache.lastAngle or 0

	if math.abs(distance - lastDistance) > 1 or math.abs(angle - lastAngle) > 0.01 then
		line.Size = UDim2.new(0, distance, 0, 2)
		line.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
		line.Rotation = math.deg(angle)
		line.AnchorPoint = Vector2.new(0, 0.5)

		if cache.gradient then
			cache.gradient.Rotation = math.deg(angle)
		end

		cache.lastDistance = distance
		cache.lastAngle = angle
	end
end

local function applyESP(target, ESP_ID, settings)
	local isValidType = (settings.TargetType == "Both")
		or (settings.TargetType == "Model" and target:IsA("Model"))
		or (settings.TargetType == "Part" and target:IsA("BasePart"))

	if not isValidType or target.Name ~= settings.TargetName then
		return
	end

	if target:IsA("Model") and settings.CheckForHumanoid and not target:FindFirstChild("Humanoid") then
		return
	end

	local targetPart = getTargetPart(target)
	if not targetPart then
		return
	end

	local billboard = target:FindFirstChild(settings.BillboardName)
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = settings.BillboardName
		billboard.Parent = target
		billboard.Adornee = targetPart
		billboard.Size = UDim2.new(0, 100, 0, 40)
		billboard.StudsOffset = Vector3.new(0, 0, 0)
		billboard.AlwaysOnTop = true

		local label = Instance.new("TextLabel")
		label.Name = "ESP_Text"
		label.Parent = billboard
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = settings.TextColor
		label.TextStrokeColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.TextSize = settings.TextSize
		label.Font = Enum.Font.SourceSansBold
		label.TextWrapped = true
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Text = settings.CustomText

		local textTween = game:GetService("TweenService"):Create(
			label,
			TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ TextTransparency = 0.3 }
		)
		textTween:Play()
	end

	local highlight = target:FindFirstChild(settings.HighlightName)
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = settings.HighlightName
		highlight.Parent = target
		highlight.OutlineColor = settings.OutlineColor
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end

	createLine(target, ESP_ID, settings)
end

local function batchProcess(items, ESP_ID, settings, batchSize)
	batchSize = batchSize or 5
	local index = 1

	local function processBatch()
		local processed = 0
		local startTime = tick()

		while index <= #items and processed < batchSize do
			if tick() - startTime > 0.016 then
				task.wait()
				startTime = tick()
			end

			local item = items[index]
			if item and item.Parent then
				applyESP(item, ESP_ID, settings)
			end
			index = index + 1
			processed = processed + 1
		end

		if index <= #items then
			task.wait()
			processBatch()
		end
	end

	task.spawn(processBatch)
end

function DripESP.Enable(ESP_ID)
	local settings = all_settings[ESP_ID]
	if not settings then
		return
	end

	getESPSubFolder(ESP_ID)

	local existingItems = {}
	local descendants = workspace:GetDescendants()

	for i = 1, #descendants do
		local item = descendants[i]
		if (item:IsA("Model") or item:IsA("BasePart")) and item.Name == settings.TargetName then
			table.insert(existingItems, item)
		end
	end

	batchProcess(existingItems, ESP_ID, settings)

	connections[ESP_ID] = workspace.DescendantAdded:Connect(function(v)
		if (v:IsA("Model") or v:IsA("BasePart")) and v.Name == settings.TargetName then
			task.wait(0.05)
			applyESP(v, ESP_ID, settings)
		end
	end)

	frameConnections[ESP_ID] = runService.Heartbeat:Connect(function()
		if objectCache[ESP_ID] then
			for target, cache in pairs(objectCache[ESP_ID]) do
				if target and target.Parent then
					updateLine(target, ESP_ID, settings)
				else
					if cache.line then
						cache.line:Destroy()
					end
					objectCache[ESP_ID][target] = nil
				end
			end
		end
	end)
end

function DripESP.Disable(ESP_ID)
	local settings = all_settings[ESP_ID]
	if not settings then
		return
	end

	if connections[ESP_ID] then
		connections[ESP_ID]:Disconnect()
		connections[ESP_ID] = nil
	end

	if frameConnections[ESP_ID] then
		frameConnections[ESP_ID]:Disconnect()
		frameConnections[ESP_ID] = nil
	end

	for _, item in ipairs(workspace:GetDescendants()) do
		if (item:IsA("Model") or item:IsA("BasePart")) and item.Name == settings.TargetName then
			local gui = item:FindFirstChild(settings.BillboardName)
			if gui then
				gui:Destroy()
			end

			local hl = item:FindFirstChild(settings.HighlightName)
			if hl then
				hl:Destroy()
			end
		end
	end

	local mainFolder = initializeESPFolder()
	local subFolder = mainFolder:FindFirstChild(settings.FolderName)
	if subFolder then
		subFolder:Destroy()
	end

	objectCache[ESP_ID] = nil
	all_settings[ESP_ID] = nil
end

function DripESP.UpdateLineColor(ESP_ID, newColor)
	local settings = all_settings[ESP_ID]
	if not settings then
		return
	end

	settings.LineColor = newColor

	if objectCache[ESP_ID] then
		for target, cache in pairs(objectCache[ESP_ID]) do
			if cache.line then
				cache.line.BackgroundColor3 = newColor
				if cache.gradient then
					cache.gradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, newColor),
						ColorSequenceKeypoint.new(1, Color3.new(newColor.R * 0.7, newColor.G * 0.7, newColor.B * 0.7)),
					})
				end
			end
		end
	end
end

function DripESP.SetLinePosition(ESP_ID, position)
	if all_settings[ESP_ID] then
		all_settings[ESP_ID].LinePosition = position
	end
end

function DripESP.GetStats()
	local stats = {}
	for ESP_ID, cache in pairs(objectCache) do
		local count = 0
		for _ in pairs(cache) do
			count = count + 1
		end
		stats[ESP_ID] = count
	end
	return stats
end

function DripESP.ClearAll()
	for ESP_ID in pairs(all_settings) do
		DripESP.Disable(ESP_ID)
	end

	if espFolder then
		espFolder:Destroy()
		espFolder = nil
	end
end

DripESP.LinePositions = LinePositions

return DripESP
