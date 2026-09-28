local OpenButton = {}

local Creator = require("../../modules/Creator")
local New = Creator.New
local Tween = Creator.Tween

-- KazeUI-style open button: round, icon-only by default, gradient neon stroke,
-- no drag handle or divider. Same module API as the original
-- (New / SetIcon / Visible / SetScale / Edit), so Window code needs no changes.

local DEFAULT_COLOR = ColorSequence.new(Color3.fromHex("aeff5c"), Color3.fromHex("30ff6a"))

function OpenButton.New(Window)
    local OpenButtonMain = {
        Button = nil,
    }

    local Icon

    local Title = New("TextLabel", {
        Text = Window.Title,
        TextSize = 15,
        FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
        BackgroundTransparency = 1,
        AutomaticSize = "XY",
        Visible = false,
    })

    -- kept as hidden frames so Edit() can still reference them
    local Drag = New("Frame", {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Name = "Drag",
        Visible = false,
    })
    local Divider = New("Frame", {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Visible = false,
    })

    local Container = New("Frame", {
        Size = UDim2.new(0, 48, 0, 48),
        Position = UDim2.new(0, 48, 0, 109),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Parent = Window.Parent,
        BackgroundTransparency = 1,
        Active = true,
        Visible = false,
    })

    local UIScale = New("UIScale", {
        Scale = 1,
    })

    local Button = New("Frame", {
        Size = UDim2.new(0, 48, 0, 48),
        Parent = Container,
        Active = false,
        BackgroundTransparency = 0.05,
        ZIndex = 99,
        BackgroundColor3 = Color3.fromRGB(14, 14, 16),
    }, {
        UIScale,
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
        }),
        New("UIStroke", {
            Thickness = 2,
            ApplyStrokeMode = "Border",
            Color = Color3.new(1, 1, 1),
            Transparency = 0,
        }, {
            New("UIGradient", {
                Color = DEFAULT_COLOR,
            }),
        }),
        Drag,
        Divider,

        -- Window connects to Button.TextButton.MouseButton1Click, so this
        -- stays named TextButton and fills the whole circle.
        New("TextButton", {
            AutomaticSize = "None",
            Active = true,
            BackgroundTransparency = 1,
            Text = "",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
        }, {
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
            }),
            Icon,
            New("UIListLayout", {
                Padding = UDim.new(0, 0),
                FillDirection = "Horizontal",
                HorizontalAlignment = "Center",
                VerticalAlignment = "Center",
            }),
            Title,
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 0),
                PaddingRight = UDim.new(0, 0),
            }),
        }),
    })

    OpenButtonMain.Button = Button

    function OpenButtonMain:SetIcon(newIcon)
        if Icon then
            Icon:Destroy()
        end
        if newIcon then
            Icon = Creator.Image(
                newIcon,
                Window.Title,
                0,
                Window.Folder,
                "OpenButton",
                true,
                Window.IconThemed
            )
            Icon.Size = UDim2.new(0, 24, 0, 24)
            Icon.LayoutOrder = -1
            Icon.Parent = OpenButtonMain.Button.TextButton
        end
    end

    if Window.Icon then
        OpenButtonMain:SetIcon(Window.Icon)
    end

    -- keep the draggable container the same size as the button (matters when
    -- a title makes it grow into a pill)
    Creator.AddSignal(Button:GetPropertyChangedSignal("AbsoluteSize"), function()
        Container.Size = UDim2.new(0, Button.AbsoluteSize.X, 0, Button.AbsoluteSize.Y)
    end)

    Creator.AddSignal(Button.TextButton.MouseEnter, function()
        Tween(Button.TextButton, 0.1, { BackgroundTransparency = 0.9 }):Play()
    end)
    Creator.AddSignal(Button.TextButton.MouseLeave, function()
        Tween(Button.TextButton, 0.1, { BackgroundTransparency = 1 }):Play()
    end)

    local DragModule = Creator.Drag(Container)

    function OpenButtonMain:Visible(v)
        Container.Visible = v
    end

    function OpenButtonMain:SetScale(scale)
        UIScale.Scale = scale
    end

    function OpenButtonMain:Edit(OpenButtonConfig)
        local OpenButtonModule = {
            Title = OpenButtonConfig.Title,
            Icon = OpenButtonConfig.Icon,
            Enabled = OpenButtonConfig.Enabled,
            Position = OpenButtonConfig.Position,
            OnlyIcon = OpenButtonConfig.OnlyIcon ~= false, -- icon-only unless false
            Draggable = OpenButtonConfig.Draggable,
            OnlyMobile = OpenButtonConfig.OnlyMobile,
            CornerRadius = OpenButtonConfig.CornerRadius or UDim.new(1, 0),
            StrokeThickness = OpenButtonConfig.StrokeThickness or 2,
            Scale = OpenButtonConfig.Scale or 1,
            Size = OpenButtonConfig.Size,
            Color = OpenButtonConfig.Color or DEFAULT_COLOR,
        }

        if OpenButtonModule.Enabled == false then
            Window.IsOpenButtonEnabled = false
        end

        -- OnlyMobile defaults to true: the button is hidden on PC unless you
        -- pass OnlyMobile = false
        if OpenButtonModule.OnlyMobile ~= false then
            OpenButtonModule.OnlyMobile = true
        else
            Window.IsPC = false
        end

        if OpenButtonModule.Draggable == false and DragModule then
            DragModule:Set(false)
        end

        if OpenButtonModule.Position then
            Container.Position = OpenButtonModule.Position
        end

        local side = OpenButtonModule.Size or 48
        if typeof(side) == "UDim2" then
            side = side.X.Offset
        end

        if OpenButtonModule.OnlyIcon then
            Title.Visible = false
            Button.AutomaticSize = Enum.AutomaticSize.None
            Button.Size = UDim2.new(0, side, 0, side)
            Container.Size = UDim2.new(0, side, 0, side)
            Button.TextButton.UIPadding.PaddingLeft = UDim.new(0, 0)
            Button.TextButton.UIPadding.PaddingRight = UDim.new(0, 0)
        else
            Title.Visible = true
            Button.AutomaticSize = Enum.AutomaticSize.X
            Button.Size = UDim2.new(0, 0, 0, side)
            Button.TextButton.UIPadding.PaddingLeft = UDim.new(0, 10)
            Button.TextButton.UIPadding.PaddingRight = UDim.new(0, 14)
            Button.TextButton.UIListLayout.Padding = UDim.new(0, 6)
        end

        if OpenButtonModule.Title then
            Title.Text = OpenButtonModule.Title
            Creator:ChangeTranslationKey(Title, OpenButtonModule.Title)
        end

        if OpenButtonModule.Icon then
            OpenButtonMain:SetIcon(OpenButtonModule.Icon)
        end

        Button.UIStroke.UIGradient.Color = OpenButtonModule.Color
        Button.UICorner.CornerRadius = OpenButtonModule.CornerRadius
        Button.TextButton.UICorner.CornerRadius = OpenButtonModule.CornerRadius
        Button.UIStroke.Thickness = OpenButtonModule.StrokeThickness

        OpenButtonMain:SetScale(OpenButtonModule.Scale)
    end

    return OpenButtonMain
end

return OpenButton
