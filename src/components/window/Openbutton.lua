local OpenButton = {}

--[[
	KazeUI OpenButton module.

	This is KazeUI's own open button (the round/square icon button with the
	neon border that shows while the window is minimized), lifted out of
	UI-Test into a standalone module with the same shape as a typical
	OpenButton.New(Window) module.

	KazeUI keeps its helpers as file-local functions, so instead of requiring
	a Creator module this takes them through `Window.Deps`:

	Window = {
		Parent      = ScreenGui the button lives in (KazeUI_OpenButton gui),
		Icon        = icon name / rbxassetid / url,
		Size        = UDim2 (default 48x48),
		Shape       = "Circle" | "Square" (default "Circle"),
		Hidable     = true  -> only visible while the window is minimized
		              false -> always visible (default true),
		Position    = UDim2 (default 24, 85),
		OnClick     = function() called on a click (not a drag) end,
		Deps = {
			KazeUI, TweenService, UserInputService,
			FormatImage, ScheduleImageSwap, StartNeonLoop, StopNeonLoop,
			TWEEN_SPRING,
			GetScale = function() return current UI scale end,
		},
	}
]]

local DRAG_THRESHOLD = 8 -- pixels of movement before a press counts as a drag

function OpenButton.New(Window)
	local Deps = Window.Deps
	local KazeUI = Deps.KazeUI
	local TweenService = Deps.TweenService
	local UserInputService = Deps.UserInputService
	local FormatImage = Deps.FormatImage
	local ScheduleImageSwap = Deps.ScheduleImageSwap
	local StartNeonLoop = Deps.StartNeonLoop
	local StopNeonLoop = Deps.StopNeonLoop
	local TWEEN_SPRING = Deps.TWEEN_SPRING
	local GetScale = Deps.GetScale or function() return 1 end

	local OpenButtonMain = {
		Button = nil,
	}

	local ButtonSize = Window.Size or UDim2.fromOffset(48, 48)
	local Hidable = Window.Hidable ~= false
	local Shape = "Circle"
	local Draggable = true
	local Enabled = true
	local IconSpec = Window.Icon or "house"

	local Button = Instance.new("TextButton")
	Button.Name = "OpenButton"
	Button.Size = ButtonSize
	Button.Position = Window.Position or UDim2.new(0, 24, 0, 85)
	Button.BackgroundTransparency = 1
	Button.Text = ""
	Button.AutoButtonColor = false
	Button.Visible = not Hidable
	Button.ZIndex = 999
	Button.Parent = Window.Parent

	local ButtonCorner = Instance.new("UICorner", Button)

	local ButtonScale = Instance.new("UIScale")
	ButtonScale.Scale = 1
	ButtonScale.Parent = Button

	local Icon = Instance.new("ImageLabel")
	Icon.Name = "Icon"
	Icon.Size = UDim2.fromScale(1, 1)
	Icon.Position = UDim2.fromScale(0.5, 0.5)
	Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	Icon.BackgroundTransparency = 0
	Icon.ScaleType = Enum.ScaleType.Fit
	Icon.ZIndex = 1000
	Icon.Parent = Button

	local IconCorner = Instance.new("UICorner", Icon)
	KazeUI:AddPanel(Icon, 0.02)
	KazeUI:OnThemeChanged(Icon, function(t) Icon.ImageColor3 = t.Text end)

	local Stroke = Instance.new("UIStroke")
	Stroke.Name = "Stroke"
	Stroke.Thickness = 1.5
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Parent = Icon
	KazeUI:RegisterBorder(Stroke)
	StartNeonLoop(Stroke)

	OpenButtonMain.Button = Button

	local function ApplyShape(shape)
		shape = tostring(shape or "Circle"):lower()
		if shape == "square" then
			Shape = "Square"
			local side = math.min(ButtonSize.X.Offset, ButtonSize.Y.Offset)
			if side <= 0 then side = 48 end
			local radius = UDim.new(0, math.max(8, math.floor(side * 0.22)))
			ButtonCorner.CornerRadius = radius
			IconCorner.CornerRadius = radius
		else
			Shape = "Circle"
			ButtonCorner.CornerRadius = UDim.new(1, 0)
			IconCorner.CornerRadius = UDim.new(1, 0)
		end
	end
	ApplyShape(Window.Shape)

	function OpenButtonMain:SetIcon(newIcon)
		if not newIcon or newIcon == "" then return end
		IconSpec = newIcon
		Icon.Image = FormatImage(newIcon)
		ScheduleImageSwap(Icon, "Image", newIcon)
	end
	OpenButtonMain:SetIcon(IconSpec)

	function OpenButtonMain:SetShape(shape)
		ApplyShape(shape)
	end

	function OpenButtonMain:GetShape()
		return Shape
	end

	function OpenButtonMain:SetScale(scale)
		ButtonScale.Scale = scale or 1
	end

	function OpenButtonMain:SetPosition(position)
		if position then Button.Position = position end
	end

	-- Shows/hides the button. Showing pops it in with the same spring the
	-- window minimize uses; hiding is instant.
	function OpenButtonMain:Visible(v)
		if v then
			if Button.Visible then return end
			Button.Visible = true
			Button.Size = UDim2.fromOffset(0, 0)
			TweenService:Create(Button, TWEEN_SPRING, {Size = ButtonSize}):Play()
		else
			Button.Visible = false
		end
	end

	-- Called by the window when it minimizes/restores. When Hidable is false
	-- the button is always on screen and this is a no-op.
	function OpenButtonMain:SetMinimized(minimized)
		if not Hidable or not Enabled then return end
		OpenButtonMain:Visible(minimized)
	end

	-- Drag / click: a press that moves less than DRAG_THRESHOLD is a click and
	-- fires Window.OnClick; anything further drags the button. Only the one
	-- active input is processed, and everything stops on release.
	local dragInput, dragStart, startPos, dragMoved

	local beganConn = Button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
			dragStart = input.Position
			startPos = Button.Position
			dragMoved = false
		end
	end)

	local changedConn = UserInputService.InputChanged:Connect(function(input)
		if not dragInput or input ~= dragInput or not dragStart then return end
		local delta = input.Position - dragStart
		if dragMoved or delta.Magnitude > DRAG_THRESHOLD then
			if not Draggable then return end
			dragMoved = true
			local scale = GetScale() * ButtonScale.Scale
			Button.Position = UDim2.new(
				0, startPos.X.Offset + (delta.X / scale),
				0, startPos.Y.Offset + (delta.Y / scale)
			)
		end
	end)

	local endedConn = UserInputService.InputEnded:Connect(function(input)
		if not dragInput or input ~= dragInput then return end
		if not dragMoved and Window.OnClick then
			Window.OnClick()
		end
		dragInput, dragStart, startPos, dragMoved = nil, nil, nil, false
	end)

	Button.Destroying:Connect(function()
		beganConn:Disconnect()
		changedConn:Disconnect()
		endedConn:Disconnect()
		StopNeonLoop(Stroke)
	end)

	function OpenButtonMain:Edit(OpenButtonConfig)
		OpenButtonConfig = OpenButtonConfig or {}
		local OpenButtonModule = {
			Icon = OpenButtonConfig.Icon,
			Enabled = OpenButtonConfig.Enabled,
			Position = OpenButtonConfig.Position,
			Size = OpenButtonConfig.Size,
			Shape = OpenButtonConfig.Shape,
			Draggable = OpenButtonConfig.Draggable,
			Hidable = OpenButtonConfig.Hidable,
			Scale = OpenButtonConfig.Scale,
		}

		if OpenButtonModule.Enabled ~= nil then
			Enabled = OpenButtonModule.Enabled and true or false
			if not Enabled then
				Button.Visible = false
			elseif not Hidable then
				Button.Visible = true
			end
		end

		if OpenButtonModule.Draggable ~= nil then
			Draggable = OpenButtonModule.Draggable and true or false
		end

		if OpenButtonModule.Hidable ~= nil then
			Hidable = OpenButtonModule.Hidable and true or false
			if Enabled then
				Button.Visible = not Hidable
			end
		end

		if OpenButtonModule.Size then
			ButtonSize = OpenButtonModule.Size
			Button.Size = ButtonSize
		end

		if OpenButtonModule.Shape then
			ApplyShape(OpenButtonModule.Shape)
		elseif OpenButtonModule.Size then
			-- Square corner radius depends on the size, so refresh it
			ApplyShape(Shape)
		end

		if OpenButtonModule.Position then
			OpenButtonMain:SetPosition(OpenButtonModule.Position)
		end

		if OpenButtonModule.Icon then
			OpenButtonMain:SetIcon(OpenButtonModule.Icon)
		end

		if OpenButtonModule.Scale then
			OpenButtonMain:SetScale(OpenButtonModule.Scale)
		end
	end

	function OpenButtonMain:Destroy()
		Button:Destroy()
	end

	return OpenButtonMain
end

return OpenButton
