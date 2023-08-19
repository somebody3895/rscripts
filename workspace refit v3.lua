--this refit has a few problems, for one: it only supports baseparts with the parent being workspace (for now)
--you are encouraged to either use RootOfAllThings and FindOtherTableWithName or StaticReferenceTable and StaticReferenceTable.Change("property", value, saveValueToRefit) 
--because merely referencing a soon-to-be replaced basepart is useless



--This version of it is absolutely busted! Mesh degrading, fake degradation, you name it! It either dies, or makes way too many copies of itself! (I'm looking at you, Fake Degradation.)
--The worst part, is that I can't figure out *why*. I've looked through everything, nothing works.

--Original file name: TRUE Workspace Refit v2 (SCREWED UP! SPARE MY SOUL!)

local gameDestroy = game.Destroy --this was taken directly from darkceius's isa box as you can tell :troll:

local function ChangeToOriginalState(StaticReferenceTable, RefitStorageTable, Property)
	local ChosenProperty = (StaticReferenceTable.RefitMetadata.Properties[Property] or RefitStorageTable.Part[Property])
	StaticReferenceTable.self[Property] = ChosenProperty
end

local function ChangeThisPropertyToThat(Property, Value)
	return function(StaticReferenceTable)
		StaticReferenceTable.self[Property] = Value
	end
end

local DetectableProperties = {
	--if it is a string, then just regenerate it
	CFrame = ChangeToOriginalState,
	Transparency = ChangeToOriginalState,
	Color = ChangeToOriginalState,
	Reflectance = ChangeToOriginalState,
	--"Parent", --we could parent it back to workspace but they could spam-parent it (we maybe could detect this and regenerate if it happens too often)
	--AncestryChanged already takes care of this
	Shape = ChangeToOriginalState,
	Parent = ChangeThisPropertyToThat("Parent", workspace),
	Anchored = ChangeToOriginalState,
	CanCollide = ChangeToOriginalState,
	Material = ChangeToOriginalState,
	Size = ChangeToOriginalState,
	
	BackSurface = ChangeToOriginalState,
	FrontSurface = ChangeToOriginalState,
	LeftSurface = ChangeToOriginalState,
	RightSurface = ChangeToOriginalState,
	TopSurface = ChangeToOriginalState,
	BottomSurface = ChangeToOriginalState
}

local FindOtherTableWithValueEqualTo
local FindOtherTableWithName
local GetRelativeFullNameOf
local InsertThisObjectPathToRoot
local AddToRefit
local ForceRegenerate
local RegenerateIfAbnormal
local ExtendedAddToRefit

local QuasiObjectMetatable = {
	__index = function(self, Index)
		return FindOtherTableWithName(self.Children, Index)
	end
}

local RootOfAllThings = setmetatable({
	self = nil,
	Children = {},
	Metadata = {}
}, QuasiObjectMetatable)

local RefitStorage = {}

FindOtherTableWithValueEqualTo = function(Table : table, ValueName : string, Value : any)
	for Index, OtherTable in pairs(Table) do
		if OtherTable[ValueName] == Value then
			return OtherTable, Index
		end
	end
	
	return nil
end

FindOtherTableWithName = function(Table, Name)
	return FindOtherTableWithValueEqualTo(Table, "Name", Name)
end

GetRelativeFullNameOf = function(Object, RelativeObject)
	local Path = {}
	
	local Here = Object.Parent
	
	for i = 1, 15 do
		if Here == (RelativeObject or workspace) then
			break
		end
		table.insert(Path, {Here, Here.Name})
		Here = Here.Parent
	end
		
	return Path
end

InsertThisObjectPathToRoot = function(Object, Path, PathRelativeObject)
	local CurrentObject = PathRelativeObject or workspace
	local CurrentDirectory = RootOfAllThings

	for i = #Path, 1, -1 do
		local NextPathInfo = Path[i]
		local NextObject = CurrentObject[NextPathInfo[2]]
			
		local NextTable = FindOtherTableWithValueEqualTo(CurrentDirectory.Children, "self", NextPathInfo[1])
		
		if NextTable == nil then
			NextTable = setmetatable({
				Name = NextPathInfo[2],
				self = NextPathInfo[1],
				Children = {},
				Metadata = {}, --custom script data
				RefitMetadata = {},
				Parent = CurrentDirectory
			}, QuasiObjectMetatable)
			table.insert(CurrentDirectory.Children, NextTable)
		end
		CurrentDirectory = NextTable
		CurrentObject = NextObject
	end

	local ThisTable = setmetatable({
		Name = Object.Name,
		self = Object,
		Children = {},
		Metadata = {},
		RefitMetadata = {},
		Parent = CurrentDirectory
	}, QuasiObjectMetatable)
		
	table.insert(CurrentDirectory, ThisTable)
		
	return ThisTable
end

AddToRefit = function(Part, StaticReferenceTable, OptionalParent)
	OptionalParent = OptionalParent or workspace

	local RegenerateCallbackFunctions = {}
	local SecurePropertiesTable = setmetatable({}, {
		__newindex = function(self, Index, Value)
			local lIndex = Index:lower()
			if lIndex == "position" or lIndex == "p" then
				self.CFrame = CFrame.new(Value)
			elseif lIndex == "rotation" or lIndex == "rot" then
				self.CFrame = CFrame.new(self.CFrame.Position) * CFrame.Angles((Value / 180) * math.pi)
			else
				self[Index] = Value
			end
		end
	})
	
	local OriginalPartChildNum = #Part:GetChildren()
	
	local PreviousPart = Part
	local CurrentPart = Part
	
	local RefitTable = {Part = CurrentPart:Clone(), Status = {}, ReferenceTable = StaticReferenceTable}

	local Regenerate
	local ConnectFunctions
		
	local Status = {
		Regenerating = false,
		AlteringProperties = false,
		AddingDescendants = false
	}

	local DescendantRemovingIgnore = {}
	
	local Last = os.clock()
	
	Regenerate = function(Alterable)
		if Status.Regenerating or (Alterable == true and Status.AlteringProperties) then return end
		Status.Regenerating = true
		Status.AlteringProperties = true
		
		local New = os.clock()
		
		--if 1 / (New - Last) >= 3333 then print("Buffering!") task.wait(1) end --times per second?????
		--unreliable
		
		table.clear(DescendantRemovingIgnore)
		
		local OldPart = CurrentPart
		local OlderPart = PreviousPart
		
		task.defer(pcall, gameDestroy, OldPart)
		task.defer(pcall, gameDestroy, OlderPart)
		pcall(gameDestroy, OldPart)
		pcall(gameDestroy, OlderPart)
			
		local NewPart = RefitTable.Part:Clone()
		NewPart.Name = math.random()
		
		for Property, Value in pairs(SecurePropertiesTable) do
			if not pcall(function() NewPart[Property] = Value end) then
				SecurePropertiesTable[Property] = nil
				print("Removed " .. Property .. " because it is not a valid property for this part")
			end
		end

		StaticReferenceTable.self = NewPart
		CurrentPart = NewPart
		PreviousPart = OldPart

		ConnectFunctions(NewPart)

		Last = New

		for Name, Function in pairs(RegenerateCallbackFunctions) do
			if not pcall(Function, NewPart) then
				error("Function " .. Name .. " failed to run!")
			end
		end

		Status.Regenerating = false
		
		NewPart.Parent = OptionalParent
		
		Status.AlteringProperties = false
		Status.AddingDescendants = false
	end
	local function IsThisPartAbnormal(ThisPart)
		if OriginalPartChildNum ~= #ThisPart:GetChildren() then
			return true
		end
		return false
	end
	
	local AlterCooldown = false
	local LastAlter = os.clock()
	
	local function AlteringRegen(Property)
		if Status.Regenerating or Status.AlteringProperties or AlterCooldown then return end
		
		local NewAlter = os.clock()
		
		if IsThisPartAbnormal(CurrentPart) then
			print("Part is abnormal!")
			Regenerate()
			return
		end
		
		local CallbackFunction = DetectableProperties[Property]
		if CallbackFunction then
			pcall(CallbackFunction, StaticReferenceTable, RefitTable, Property)
			task.defer(pcall, CallbackFunction, StaticReferenceTable, RefitTable, Property)
		end
		
		--[[
		if 1 / (NewAlter - LastAlter) > 3333 then --times per second?????
			AlterCooldown = true
			print(".changed Buffering! Turning off .Changed connections for a while.")
			task.wait(1)
			print(".changed Buffer end")
			AlterCooldown = false
		end --unreliable]]
		
		LastAlter = NewAlter
	end
	
	local function AlterableRegen(Child)
		if Status.AlteringProperties or Status.Regenerating or table.find(DescendantRemovingIgnore, Child) then return end
		Regenerate(true)
	end

	local function Change(Property, Value, SaveChanges)
		if SaveChanges then
			SecurePropertiesTable[Property] = Value
		end

		Status.AlteringProperties = true
		pcall(function()
			CurrentPart[Property] = Value
		end)
		Status.AlteringProperties = false
	end

	local function AddChild(Child)
		Status.AddingDescendants = true
		Child.Parent = CurrentPart
		Status.AddingDescendants = false
	end
	
	local function GetFunctionThatDestroysThisChild(ThisPart)
		return function(Child)
			if Status.AddingDescendants then return end
			table.insert(DescendantRemovingIgnore, Child)
			
			--ThisPart.DescendantAdded:Once(gameDestroy) --trying to combat fake mesh degradation, to no avail (does it use hypernull?)

			task.defer(pcall, gameDestroy, Child)
			
			task.delay(0.5, function()
				if IsThisPartAbnormal(CurrentPart) then
					print("Part is abnormal!")
					Regenerate() --trying to combat fake mesh degradation
				end
			end)
			
			--do NOT trigger DescendantRemoving
		end
	end
		
	local function SetThisPartToWorkspace(ThisPart)
		ThisPart.Parent = workspace
	end
	
	local function ReturnFunctionThatSetsThisPartToWorkspace(ThisPart)
		return function(_, NewParent)
			if Status.AlteringProperties or ThisPart == nil then return end
			Status.AlteringProperties = true
			task.defer(pcall, SetThisPartToWorkspace, ThisPart)
			local w = pcall(SetThisPartToWorkspace, ThisPart)
			
			-- local args = {pcall, SetThisPartToWorkspace, ThisPart}
			-- for i = 1, 2 do
				-- task.defer(table.unpack(args))
				-- table.insert(args, 1, task.defer)
			-- end

			if not w or NewParent and NewParent:IsA("ViewportFrame") then
				--i LOVE fake degradation
				Regenerate()
			end
			Status.AlteringProperties = false
		end
	end

	ConnectFunctions = function(NewPart)
		NewPart.Destroying:Once(Regenerate)
		NewPart.AncestryChanged:Connect(ReturnFunctionThatSetsThisPartToWorkspace(NewPart))--AlterableRegen)
		NewPart.DescendantRemoving:Connect(AlterableRegen)
		NewPart.DescendantAdded:Connect(GetFunctionThatDestroysThisChild(NewPart))
		NewPart.Changed:Connect(AlteringRegen)

		-- table.insert(StaleRefitConnections, workspace.DescendantRemoving:Connect(function(RemovedPart)
			-- if RemovedPart == Part then
				-- Regenerate()
			-- end
		-- end))
	end
	
	local EmptyFunction = function() end

	local Disconnect = function()
		ConnectFunctions = EmptyFunction
		Regenerate = EmptyFunction
		GetFunctionThatDestroysThisChild = EmptyFunction
		AlterableRegen = EmptyFunction
		Change = EmptyFunction
		AlteringRegen = EmptyFunction

		StaticReferenceTable.AddChild = EmptyFunction
		StaticReferenceTable.Change = EmptyFunction
		StaticReferenceTable.RegenerateCallbackFunctions = nil

		StaticReferenceTable.self = nil
		StaticReferenceTable.RefitMetadata = nil

		table.remove(RefitStorage, table.find(RefitStorage, RefitTable))

		RefitTable = nil

		pcall(gameDestroy, PreviousPart)
		pcall(gameDestroy, CurrentPart)
	end

	StaticReferenceTable.RefitMetadata.Properties = SecurePropertiesTable

	StaticReferenceTable.AddChild = AddChild
	StaticReferenceTable.Change = Change
	StaticReferenceTable.RegenerateCallbackFunctions = RegenerateCallbackFunctions
	StaticReferenceTable.Disconnect = Disconnect

	RefitTable.Status[1] = Status
	RefitTable.Status[2] = Regenerate

	table.insert(RefitStorage, RefitTable)

	ConnectFunctions(CurrentPart)
end

ForceRegenerate = function()
	for _,RefitTable in pairs(RefitStorage) do
		local RegenerationTable = RefitTable.Status
		
		RegenerationTable[1].Regenerating = false
		RegenerationTable[1].AlteringProperties = false
		RegenerationTable[1].AddingDescendants = false
		RegenerationTable[2]()
	end
end

RegenerateIfAbnormal = function()
	for _,RefitTable in pairs(RefitStorage) do
		if #RefitTable.Part:GetChildren() ~= #RefitTable.ReferenceTable.self:GetChildren() then

			local RegenerationTable = RefitTable.Status
		
			RegenerationTable[1].Regenerating = false
			RegenerationTable[1].AlteringProperties = false
			RegenerationTable[1].AddingDescendants = false
			RegenerationTable[2]()
		end
	end
end

ExtendedAddToRefit = function(Table, RootModel)
	local Path = GetRelativeFullNameOf(Table.self, RootModel)
	local StaticReferenceTable = InsertThisObjectPathToRoot(Table.self, Path, RootModel)
	AddToRefit(Table.self, StaticReferenceTable, workspace)

	return StaticReferenceTable
end

return {
	RootOfAllThings = RootOfAllThings,
	FindOtherTableWithName = FindOtherTableWithName,
	FindOtherTableWithValueEqualTo = FindOtherTableWithValueEqualTo,
	ExtendedAddToRefit = ExtendedAddToRefit,
	ForceRegenerate = ForceRegenerate,
	RegenerateIfAbnormal = RegenerateIfAbnormal
}
