--i don't think this even counts as a module
local RunService = game:GetService("RunService")

if not RunService:IsClient() then error("MS: i think a mouse module needs to run on the client") end

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Ignore = {}
local OnReportCallbackFunctions = {}

local RaycastParams = RaycastParams.new()
RaycastParams.IgnoreWater = true
RaycastParams.RespectCanCollide = false

function GetCurrentCamera()
    return workspace.CurrentCamera
end

function GetMouseInfo()
	local MouseLocationOnScreen = UserInputService:GetMouseLocation()
	local CurrentCamera = GetCurrentCamera()
	local MouseRay = CurrentCamera:ViewportPointToRay(MouseLocationOnScreen.X, MouseLocationOnScreen.Y)
	local CurrentCameraCFrame = CurrentCamera.CFrame

    local NewIgnore = {}

    for i,v in pairs( {table.unpack(Ignore)}) do
        table.insert(NewIgnore, v)
    end

	RaycastParams.FilterDescendantsInstances = {NewIgnore, owner.Character}

	local RaycastResult = workspace:Raycast(MouseRay.Origin, (MouseRay.Direction.Unit) * 2048, RaycastParams) or {}
	local RaycastPos = RaycastResult.Position or (MouseRay.Origin + MouseRay.Direction.Unit * 2048)

    local Offset

    if RaycastResult.Instance ~= nil then
        Offset = RaycastResult.Instance.CFrame:Inverse() * CFrame.new(RaycastPos)

        if RaycastResult.Instance.AssemblyLinearVelocity.Magnitude > 100 then
            Offset = CFrame.new(0, 0, 0)
        end
    end

    return {
        CameraCFrame = CurrentCameraCFrame,

        RayCameraOrigin = MouseRay.Origin,
        RayMouseDirection = MouseRay.Direction,

        Position = RaycastPos,
        TargetOffset = Offset,
        Target = RaycastResult.Instance,
        Normal = RaycastResult.Normal or Vector3.new(0, 1, 0)
    }
end

local LastTimeSent = tick()

function ReportToServer(InputObject, GameProcessed)
    local ReportTable = {}

    if InputObject ~= nil then
        ReportTable.KeyCode = InputObject.KeyCode.Name
        ReportTable.UserInputState = InputObject.UserInputState.Name
        ReportTable.UserInputType = InputObject.UserInputType.Name
        ReportTable.GameProcessed = GameProcessed
    end

    ReportTable.MouseInfo = GetMouseInfo()

    ;(script:FindFirstChild("InputEvent") or {FireServer = function() warn("No RemoteEvent named InputEvent inside script!") end}):FireServer(ReportTable)

    for Name, Value in pairs(OnReportCallbackFunctions) do
		local w, e = pcall(Value, ReportTable)
        if w == false then
            warn("A function (" .. Name .. ") has failed to run, with error: '" .. e .. "'")
        end
    end

    LastTimeSent = tick()
end

local Connections = {}

table.insert(Connections, UserInputService.InputBegan:Connect(ReportToServer))
table.insert(Connections, UserInputService.InputEnded:Connect(ReportToServer))

task.delay(1, function()
	while task.wait(0.05) and (#Connections > 0) do
	    if tick() - LastTimeSent > 0.04 then
	        ReportToServer()
	    end
	end
end)

return Ignore, OnReportCallbackFunctions
