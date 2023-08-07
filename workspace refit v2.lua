--this refit has a few problems, for one: it only supports baseparts with the parent being workspace (for now)
--you are encouraged to either use RootOfAllThings and FindOtherTableWithName or StaticReferenceTable and StaticReferenceTable.Change("property", value, saveValueToRefit) 
--because merely referencing a soon-to-be replaced basepart is useless

local function ChangeToOriginalState(StaticReferenceTable, RefitStorageTable, Property)
	StaticReferenceTable.self[Property] = (StaticReferenceTable.Metadata[Property] or RefitStorageTable[1][Property])
end
local function ChangeThisPropertyToThat(Property, Value)
	return function(StaticReferenceTable)
		StaticReferenceTable.self[Property] = Value
	end
end

local DetectableProperties = {
	--if it is a string, then just regenerate it
	"CFrame",
	"Position",
	"Rotation",
	{"Transparency", ChangeToOriginalState},
	{"Color", ChangeToOriginalState},
	{"Reflectance", ChangeToOriginalState},
	{"Parent", ChangeThisPropertyToThat("Parent", workspace)}, --we could parent it back to workspace but they could spam-parent it (we maybe could detect this and regenerate if it happens too often)
	{"Anchored", ChangeToOriginalState},
	{"CanCollide", ChangeToOriginalState},
	{"Material", ChangeToOriginalState},
	{"Size", ChangeToOriginalState},
	table.unpack(
		(function()
			local Extra = {}
			for _,v in pairs({"Back", "Front", "Top", "Bottom", "Left", "Right"}) do
				table.insert(Extra, {v .. "Surface", ChangeToOriginalState})
			end
			return Extra
		end)()
	)
}

local FindOtherTableWithValueEqualTo
local FindOtherTableWithName
local GetRelativeFullNameOf
local InsertThisObjectPathToRoot
local AddToRefit
local ForceRegenerate
local ExtendedAddToRefit

local RootOfAllThings = setmetatable({
	self = nil,
	Children = {}
}, {
	__index = function(self, Index)
		return FindOtherTableWithName(self.Children, Index)
	end
})

local RefitStorage = {}

FindOtherTableWithValueEqualTo = function(Table : table, ValueName : string, Value : any)
	for Index, OtherTable in pairs(Table) do
		if OtherTable[ValueName] == Value then
			return OtherTable
		end
	end
		
	return nil
end

FindOtherTableWithName = function(...)
	local t = {...}
	
	return FindOtherTableWithValueEqualTo(t[1], "Name", t[2])
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
				Metadata = {},
				Parent = CurrentDirectory
			}, {
				__index = function(self, Index)
					return FindOtherTableWithName(self.Children, Index)
				end
			})
			table.insert(CurrentDirectory.Children, NextTable)
		end
		CurrentDirectory = NextTable
		CurrentObject = NextObject
	end

	local ThisTable = setmetatable({
		Name = Object.Name,
		self = Object,
		Children = {},
		Metadata = {}, --this is used for the refit (consider changing name to RefitMetadata)
		Parent = CurrentDirectory
	}, {
		__index = function(self, Index)
			return FindOtherTableWithName(self.Children, Index)
		end
	})
		
	table.insert(CurrentDirectory, ThisTable)
		
	return ThisTable
end

AddToRefit = function(Part, StaticReferenceTable, OptionalParent)
	local RefitIndex = #RefitStorage + 1
	OptionalParent = OptionalParent or workspace
	local StaleRefitConnections = {}
	local SecurePropertiesTable = {}

	local Regenerate
	local ConnectFunctions
		
	local Status = {
		Regenerating = false,
		Altering = 0
	}

	Regenerate = function(Alterable)
		if Status.Regenerating or (Alterable and Status.Altering > 0) then return end
		Status.Regenerating = true
		local OldPart = Part

		local ThisPartRefitTable = RefitStorage[RefitIndex]
			
		local NewPart = ThisPartRefitTable.Part:Clone()
			
		pcall(function()
			pcall(function()
				for Property, Value in pairs(SecurePropertiesTable) do
					NewPart[Property] = Value
				end
				for _, v in pairs(StaleRefitConnections) do
					if v.Connected then
					v:Disconnect()
					end
				end
				table.clear(StaleRefitConnections)
			end)
				
			OldPart:Destroy()
		end)
			
		NewPart.Name = math.random()

		Part = NewPart
			
		StaticReferenceTable.self = NewPart

		ConnectFunctions()

		Status.Regenerating = false

		Status.Altering = true
		NewPart.Parent = OptionalParent
		Status.Altering = false
	end

	local function GetAlterableRegen()
		return function(Property)
			local IndeedRegenerate = false
			
			for _,TableOrProperty in pairs(DetectableProperties) do
				if type(TableOrProperty) == "string" then
					if Property == TableOrProperty then
						IndeedRegenerate = true
						break
					end
				else -- table
					if TableOrProperty[1] == Property then
						local RefitTable = RefitStorage[RefitIndex]
						
						Status.Altering += 1
						pcall(TableOrProperty[2], StaticReferenceTable, RefitTable, Property)
						Status.Altering -= 1
					end
				end
			end
			
			if IndeedRegenerate then
				Regenerate(true)
			end
		end
	end

	local function Change(Property, Value, SaveChanges)
		if SaveChanges then
			SecurePropertiesTable[Property] = Value
		end

		Status.Altering += 1
		pcall(function()
			Part[Property] = Value
		end)
		Status.Altering -= 1
	end

	ConnectFunctions = function()
		Part.Destroying:Connect(Regenerate)
		Part.AncestryChanged:Connect(GetAlterableRegen())
		Part.DescendantRemoving:Connect(Regenerate)
		Part.DescendantAdded:Connect(Regenerate)
		Part.Changed:Connect(GetAlterableRegen())
		--This stuff gets :Destroy()ed anyway, don't worry.
		
		-- table.insert(StaleRefitConnections, workspace.DescendantRemoving:Connect(function(RemovedPart)
			-- if RemovedPart == Part then
				-- Regenerate()
			-- end
		-- end))
	end
	
	StaticReferenceTable.Metadata.Properties = SecurePropertiesTable
		
	StaticReferenceTable.Change = Change
		
	table.insert(RefitStorage, RefitIndex, {Part = Part:Clone(), Status = {Status, Regenerate}, ReferenceTable = StaticReferenceTable})

	ConnectFunctions()
end

ForceRegenerate = function()
	for _,RefitTable in pairs(RefitStorage) do
		local RegenerationTable = RefitTable.Status
		
		RegenerationTable[1].Regenerating = false
		RegenerationTable[1].Altering = 0
		RegenerationTable[2]()
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
	AddToRefit = AddToRefit,
	GetRelativeFullNameOf = GetRelativeFullNameOf,
	InsertThisObjectPathToRoot = InsertThisObjectPathToRoot,
	ForceRegenerate = ForceRegenerate,
	ExtendedAddToRefit = ExtendedAddToRefit
}
