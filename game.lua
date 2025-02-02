local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

---------------------------------------------------------------------
local replicated_storage = game:GetService("ReplicatedStorage")
local server_storage = game:GetService("ServerStorage")

-- incoming from client
local tier_change = replicated_storage.TierChangeEvent
local tile_event = replicated_storage.TileEvent

-- incoming from server
local expand_event = server_storage.Events.ExpandEvent
---------------------------------------------------------------------

local tile = server_storage.Templates:WaitForChild("tile")
local land = server_storage.Templates:WaitForChild("land")
local expansion = server_storage.Templates:WaitForChild("expand")

function create_tier_grid(x_min, x_max, y_min, y_max, size, odds, tile_type, tile_color, cost)
	for i = x_min, x_max, 1 do
		for j = y_min, y_max, 1 do
			local new_tile = tile:clone()
			new_tile.Name = tile_type .. "_" .. i .. "x" .. j
			local tile_group_string = string.upper(string.sub(tile_type, 1, 1))..string.sub(tile_type, 2, -1)
			
			new_tile.Size = Vector3.new(size, 1, size)new_tile.CFrame = CFrame.new(-i*size, 1, -j*size) * CFrame.Angles(0, math.rad(-90), 0)
			
			--new_tile.SurfaceGui.Frame.TextLabel.Text = cost
			new_tile:SetAttribute("cost", cost)
			
			--if tile_type == "empty" then
			--	new_tile.SurfaceGui.Frame.Visible = false
			--end
			
			new_tile.border:PivotTo(CFrame.new(-i*size, 1, -j*size) * CFrame.Angles(0, math.rad(-90), 0))
			
			-- color adaption
			new_tile.SelectionBox.Color3 = Color3.fromRGB(table.unpack(tile_color))
			for _, part in ipairs(new_tile.border:GetChildren()) do
				part.Color = Color3.fromRGB(table.unpack(tile_color))
			end
			
			new_tile:SetAttribute("revealed", false)
			new_tile:SetAttribute("size", size)
			new_tile:SetAttribute("harvester", false)
			new_tile:SetAttribute("revealed_bombs", 0)
			
			new_tile.Parent = workspace:FindFirstChild(tile_group_string .. "s")
			
			-- tile is bomb
			if odds == 0 then
				new_tile:SetAttribute("bomb", false)
				continue
			end
			
			if math.random(1,odds) == odds then
				new_tile:SetAttribute("bomb", true)
				new_tile:SetAttribute("harvested", "")
				
				if tile_type == "empty" then
					continue
				end
				
				-- loop through neighbors. want to update all already revealed tiles if expanding
				for a = i - 1, i + 1, 1 do
					for b = j - 1, j + 1, 1 do
						local adjacent_tile = new_tile.Parent:FindFirstChild(tile_type .. "_" .. a .. "x" .. b)
						
						if adjacent_tile and adjacent_tile:GetAttribute("revealed") and not adjacent_tile:GetAttribute("bomb") then
							adjacent_tile:SetAttribute("adjacent_bombs", adjacent_tile:GetAttribute("adjacent_bombs") + 1)
						end
					end
				end
				
			else
				new_tile:SetAttribute("bomb", false)
			end
		end
	end
end

function create_basic_land(x_min, x_max, y_min, y_max, size)
	for i = x_min, x_max, 1 do
		for j = y_min, y_max, 1 do
			local new_land = land:clone()
			new_land.Name = "land_" .. i .. "x" .. j
			new_land.CFrame = CFrame.new(-i*size, .99, -j*size) * CFrame.Angles(0, math.rad(-90), 0)
			new_land.Size = Vector3.new(size, 1, size)
			new_land.Parent = workspace.Lands
		end
	end
end

local tier_list = {"Emptys", "Farms", "Lumbers"}
local tier_tile_type = {"empty", "farm", "lumber"}
local tier_building = {"Empty", "Farm", "Sawmill"}
local tier_cost = {"Free", "$1", "$10"}
local tier_color = {{138, 138, 138}, {0, 255, 0}, {0, 0, 255}}
local tier_odds = {0,5,6}
local tier_size = {4,4,4,8}
local tier_models = {}
local add_list = {}

function create_tier_models()
	for _, tier_name in ipairs(tier_list) do
		
		local tier = Instance.new("Model")
		--local tier = workspace.Tiles:Clone()
		tier.Name = tier_name
		
		tier.Parent = workspace
		
		-- handling one tier at a time
		table.insert(tier_models, tier)
		add_list[tier_name] = {}
	end
end

function toggle_visible_build_gui(tier_number, toggle_value)
	for _, player in ipairs(Players:GetChildren()) do
		if player and player.PlayerGui and player.PlayerGui:WaitForChild("ScreenGui") then
			local build_buttons = player.PlayerGui.ScreenGui.Actions.Build
			
			local capital = build_buttons:FindFirstChild("4.Capital")
			local house = build_buttons:FindFirstChild("5.House")
			local building = build_buttons:FindFirstChild(tier_number+4 .. "." .. tier_building[tier_number])
			
			if toggle_value then
				local cap_visible = tier_models[tier_number]:GetAttribute("capital")
				capital.Visible = not cap_visible
				house.Visible = cap_visible
				if building then
					building.Visible = cap_visible
				end
			else
				house.Visible = false
				capital.Visible = false
				
				if building then
					building.Visible = false
				end
			end
		end
	end	
end

function toggle_visible_tier(tier_number)
	-- timer fixes issue with weird script duplication on tiles
	--task.wait(0.01)
	
	--print("start")
	
	if typeof(tier_number) == "string" then
		tier_number = tonumber(tier_number)
	end
	
	--if true then
		if tier_models[tier_number].WorldPivot.Position.Y == 1 then
			tier_models[tier_number]:PivotTo(CFrame.new(tier_models[tier_number].WorldPivot.Position.X, 300, tier_models[tier_number].WorldPivot.Position.Z), tier_models[tier_number].WorldPivot.Rotation)
			
			toggle_visible_build_gui(tier_number, false)

			return
		end
		
		for tier_num, tier in ipairs(tier_models) do
			if tier.WorldPivot.Position.Y == 1 then
				tier:PivotTo(CFrame.new(tier.WorldPivot.Position.X, 300, tier.WorldPivot.Position.Z), tier.WorldPivot.Rotation)

				toggle_visible_build_gui(tier_num, false)

				-- only one couldve been active!
				break
			end
		end
		
		tier_models[tier_number]:PivotTo(CFrame.new(tier_models[tier_number].WorldPivot.Position.X, 1, tier_models[tier_number].WorldPivot.Position.Z), tier_models[tier_number].WorldPivot.Rotation)
	
	
-- slower solution :(
	--else	
	--	-- if player is deselecting tier, show none
	--	if tier_models[tier_number].Parent == workspace then
	--		tier_models[tier_number].Parent = nil

	--		local make_invisible = false
	--		toggle_visible_build_gui(tier_number, make_invisible)

	--		return
	--	end

	--	-- else a different tier was visible, so now disable it
	--	for tier_num, tier in ipairs(tier_models) do
	--		if tier.Parent == workspace then
	--			tier.Parent = nil

	--			local make_invisible = false
	--			toggle_visible_build_gui(tier_num, make_invisible)

	--			-- only one couldve been active!
	--			break
	--		end
	--	end
		
	--	-- now enable the new selected tier
	--	tier_models[tier_number].Parent = workspace
	
	--end
	
	toggle_visible_build_gui(tier_number, true)
	
	-- wait so tiles can load
	task.wait()
	
	-- only add tiles when we first select each tier since an addition
	while #add_list[tier_list[tier_number]] > 0 do
		local n = tier_number
		
		local x_min, x_max, y_min, y_max = table.unpack(table.remove(add_list[tier_list[n]]))

		create_tier_grid(x_min, x_max, y_min, y_max, tier_size[n], tier_odds[n], tier_tile_type[n], tier_color[n], tier_cost[n])
	end

	--print("end: ", #tier_models[tier_number]:GetChildren())
end

function start_game()
	local x_min, y_min = 1, 1
	
	local x_max, y_max = 6, 6
	
	create_tier_models()

	for i, tier in ipairs(tier_models) do
		table.insert(add_list[tier.Name], {x_min, x_max, y_min, y_max})
		
		tier:GetAttributeChangedSignal("capital"):Connect(function()
			if tier_models[i].WorldPivot.Position.Y == 1 then
				toggle_visible_build_gui(i, true)
			end
		end)
	end
	
	create_basic_land(x_min, x_max, y_min, y_max, tier_size[1])
	
	toggle_visible_tier(1)
	
	-- create expansions around center
	add_expansions(0,0)
	
	initialize_building_count()
end

function expand(x_min, x_max, y_min, y_max)
	-- determine if a current tier is selected
	local cur_tier
	for i, tier in ipairs(tier_models) do
		--if tier.Parent == workspace then --> part of faster fix
		if tier.WorldPivot.Position.Y == 1 then
			cur_tier = tier
			break
		end
	end
	
	-- create new land for expansion
	create_basic_land(x_min, x_max, y_min, y_max, tier_size[1])
	
	-- only add tiles for current tier. save other tiers for when we open them again
	if cur_tier then
		local tier_num = table.find(tier_list, cur_tier.Name)
		
		if tier_num then
			create_tier_grid(x_min, x_max, y_min, y_max, tier_size[tier_num], tier_odds[tier_num], tier_tile_type[tier_num], tier_color[tier_num], tier_cost[tier_num])
		end
	end

	for _, tier in ipairs(tier_models) do
		if tier == cur_tier then
			continue
		end
		table.insert(add_list[tier.Name], {x_min, x_max, y_min, y_max})
	end
end

local expand_cost = 50
local expand_addition = expand_cost

function create_expansion(x, y)
	local new_expansion = expansion:Clone()
	
	new_expansion.Name = "expand_" .. x .. "x" .. y
	new_expansion.SurfaceGui.Frame.TextLabel.Text = "Expand\n$" .. expand_cost

	local expansion_size = 24

	new_expansion.CFrame = CFrame.new(-1 * x * expansion_size - 14, 1, -1 * y * expansion_size - 14) * CFrame.Angles(0, math.rad(-90), 0)
	new_expansion.border:PivotTo(CFrame.new(-1 * x * expansion_size - 14, 1, -1 * y * expansion_size - 14) * CFrame.Angles(0, math.rad(-90), 0))
	
	new_expansion.Parent = workspace:WaitForChild("Expands")
end

function add_expansions(x, y)
	-- next, add expasions to the 4 adjacent zones, checking if they have already existed
	local directions = {{1,0}, {0,1}, {-1,0}, {0,-1}}
	for _, coordinate_pair in pairs(directions) do
		local a, b = x + coordinate_pair[1], y + coordinate_pair[2]
		
		-- skip center square that we aren't tracking
		if a == 0 and b == 0 then
			continue
		end
		
		local expansion_name = "expand_" .. a .. "x" .. b
		
		-- check if expansion already exists or previously used
		if workspace.Expands:FindFirstChild(expansion_name) or server_storage.Expands:FindFirstChild(expansion_name) then
			continue
		end
		
		create_expansion(a,b)
	end
end

local money = server_storage.Resources["1.Money"].Count

expand_event.Event:Connect(function(incoming_expansion)
	-- check money
	if expand_cost > tonumber(money.Text) then
		return -- broke
	end
	money.Text = tonumber(money.Text) - expand_cost
	expand_cost = expand_cost + expand_addition
	
	-- update other tiles costs
	for _, expo in ipairs(workspace.Expands:GetChildren()) do
		expo.SurfaceGui.Frame.TextLabel.Text = "Expand\n$" .. expand_cost
	end
	
	local expand_group_string = "expand"
	
	local coordinates = string.gsub(incoming_expansion.Name, expand_group_string .. "_", "", 1)
	-- i.e. "1x4"
	local x_string, y_string = table.unpack(string.split(coordinates, "x"))
	-- i.e. "1", "4"
	local x, y = tonumber(x_string), tonumber(y_string)
	-- i.e. 1, 4
	
	-- keep track of previous expansions!
	incoming_expansion.Parent = server_storage.Expands
	
	-- min(x) = 6x + 1
	-- max(x) = 6x + 6
	local x_min, y_min = 6 * x + 1, 6 * y + 1
	local x_max, y_max = 6 * x + 6, 6 * y + 6
	-- i.e. expand_0x0 -> [1,6],[1,6]
	
	expand(x_min, x_max, y_min, y_max)
	
	add_expansions(x, y)
end)

tier_change.OnServerEvent:Connect(function(player, tier_number)
	toggle_visible_tier(tier_number)
end)

local tier_level = 1
local tier_resources = {"", "", "", "Wheat", "Wood"}
local tier_cost = {10, 25, 50}

function attempt_upgrade()
	if tonumber(money.Text) < tier_cost[tier_level] then
		return -- broke
	end
	money.Text = tonumber(money.Text) - tier_cost[tier_level]
	
	tier_level += 1
	
	local color = StarterGui.ScreenGui.Tile:FindFirstChild(tier_level + 1).BackgroundColor3
	local upgrade_text = "Upgrade Tier $" .. tier_cost[tier_level]
	
	for _, player in ipairs(Players:GetChildren()) do
		if player and player.PlayerGui and player.PlayerGui:WaitForChild("ScreenGui") then
			
			player.PlayerGui.ScreenGui.Tile:FindFirstChild(tier_level).Visible = true
			
			player.PlayerGui.ScreenGui.Resources:FindFirstChild(tier_level+2 .. "." .. tier_resources[tier_level+2]).Visible = true
			
			local upgrade = player.PlayerGui.ScreenGui.Actions.Actions["5.Upgrade"]
			upgrade.BackgroundColor3 = color
			upgrade.Text = upgrade_text
			
			toggle_visible_tier(tier_level)
		end
	end	
end

--local tile_event_list = {"Prospect", "Flag", "Sell", "Capital", "House", "Farm", "Sawmill"}
-- set player action to their server attribute
tile_event.OnServerEvent:Connect(function(player, event_name)
	if event_name == "Upgrade" then
		attempt_upgrade()
		return
	end
	
	player:SetAttribute("build", event_name)
end)




Players.PlayerAdded:Connect(function(player)
	
	
end)

Players.PlayerRemoving:Connect(function(player)
	
end)

function initialize_building_count()
	for _, building in ipairs(server_storage.Special_Tiles.Buildings:GetChildren()) do
		building:SetAttribute("count", 0)
	end
	for _, capital in ipairs(server_storage.Special_Tiles.Capitals:GetChildren()) do
		capital:SetAttribute("count", 0)
	end
end

start_game()

