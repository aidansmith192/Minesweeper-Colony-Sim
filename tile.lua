local this_tile = script.Parent
local tile_group = this_tile.Parent
local tile_group_string = tile_group.Name
-- i.e. "Farms"
local tile_type_string = string.lower(string.sub(tile_group_string, 1, string.len(tile_group_string) - 1))
-- i.e. "farm"
local coordinates = string.gsub(this_tile.Name, tile_type_string .. "_", "", 1)
-- i.e. "1x4"
local x_string, y_string = table.unpack(string.split(coordinates, "x"))
-- i.e. "1", "4"
local x, y = tonumber(x_string), tonumber(y_string)
-- i.e. 1, 4

local text_label = this_tile.SurfaceGui.Frame.TextLabel
local click_detector = this_tile.ClickDetector

local tile_event_list = {"Prospect", "Flag", "Sell", "Capital", "BiggerCapital", "House", "Farm", "Sawmill"}

---------------------------------------------------------------------
local ServerStorage = game:GetService("ServerStorage")
-- outgoing to server
local update_capital_list = ServerStorage.Events.UpdateCapitalList
--local update_harvester_list = ServerStorage.Events.UpdateHarvesterList
---------------------------------------------------------------------

local money = ServerStorage.Resources["1.Money"].Count

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																				-- Helpers ---
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function get_coordinates(tile)
	-- i.e. "farm"
	local coordinates = string.gsub(tile.Name, tile_type_string .. "_", "", 1)
	-- i.e. "1x4"
	local a_string, b_string = table.unpack(string.split(coordinates, "x"))
	-- i.e. "1", "4"
	return tonumber(a_string), tonumber(b_string)
end

function get_neighbor_list(tile)
	local a, b = x, y
	
	-- if the input tile isnt this script's tile, then we gotta calculate the other tiles coordinates
	if tile ~= this_tile then
		a, b = get_coordinates(tile)
	end
	
	local neighbors = {}
	
	for i = a - 1, a + 1, 1 do
		for j = b - 1, b + 1, 1 do
			-- skip center (main) tile as we it cant be its own neighbor
			if i == a and j == b then
				continue
			end

			local adjacent_tile = tile_group:FindFirstChild(tile_type_string .. "_" .. i .. "x" .. j)

			if adjacent_tile then
				table.insert(neighbors, adjacent_tile)
			end
		end
	end
	
	return neighbors
end

-- returns the lands occupied by the given tile. 1 if 4x4 and 4 if 8x8
function get_lands(tile)
	if tile:GetAttribute("size") == 4 then
		local land_name = string.gsub(tile.Name, tile_type_string, "land", 1)
		local land = workspace.Lands:FindFirstChild(land_name)
		if land then
			return {land}
		else
			return {}
		end
	end
	
	-- else building is 8x8
	local tile_lands = {}
	
	-- functions, same for y. for translating 8x8 into 4x4 land tiles it includes
	-- up(x) = 2x
	-- low(x) = 2x - 1
	--print()
	local up_x, up_y = 2 * x, 2 * y
	local low_x, low_y = (2 * x) - 1, (2 * y) - 1
	local x_values, y_values = {up_x, low_x}, {up_y, low_y}
	
	for _, a in pairs(x_values) do
		for _, b in pairs(y_values) do
			local land = workspace.Lands:FindFirstChild("lands_" .. a .. "x" .. b)
			if land then
				table.insert(tile_lands, land)
			end
		end
	end
	return tile_lands
end

local lands = get_lands(this_tile)

function has_building(tile_lands)
	for _, land in ipairs(tile_lands) do
		if #land.Buildings:GetChildren() > 0 then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																					-- Prospecting ---
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- reveal tile and determine its value based on neighbors
function dynamic_reveal_tile(tile)
	local adjacent_bombs = 0
	local revealed_adjacent_bombs = 0

	--loop through neighbors to determine which ones are bombs. then assign count to the tile
	local neighbor_list = get_neighbor_list(tile)

	for _, adjacent_tile in ipairs(neighbor_list) do
		if adjacent_tile:GetAttribute("bomb") then
			adjacent_bombs += 1

			-- find land part using adjacent_tile, then check if has building
			local adjacent_tile_lands = get_lands(adjacent_tile)

			-- revealed tiles must not be blocked by building
			if adjacent_tile:GetAttribute("revealed") and adjacent_tile:GetAttribute("harvested") == "" and not has_building(adjacent_tile_lands) then
				revealed_adjacent_bombs += 1
			end
		end
	end

	tile:SetAttribute("adjacent_bombs", adjacent_bombs)
	tile:SetAttribute("revealed_bombs", revealed_adjacent_bombs)
end

-- handles revealing bomb if not flagged
function destroy_bomb()
	-- loop through neighbors
	local neighbor_list = get_neighbor_list(this_tile)
	
	-- remove adjacent bomb count since bomb destroyed
	for _, adjacent_tile in ipairs(neighbor_list) do
		if not this_tile:GetAttribute("bomb") and not adjacent_tile:GetAttribute("bomb") and adjacent_tile:GetAttribute("revealed") then
			adjacent_tile:SetAttribute("adjacent_bombs", adjacent_tile:GetAttribute("adjacent_bombs") - 1)
		end
	end
end

-- removed building from on top of bomb OR revealed bomb
function free_bomb(bomb_tile)
	-- loop through neighbors
	local neighbor_list = get_neighbor_list(bomb_tile)

	-- if harvester nearby then add it to it and return
	for _, adjacent_tile in ipairs(neighbor_list) do
		if adjacent_tile:GetAttribute("harvester") then
			local coor_a, coor_b = get_coordinates(adjacent_tile)
			bomb_tile:SetAttribute("harvested", coor_a .. "x" .. coor_b)
			adjacent_tile:SetAttribute("revealed_bombs", adjacent_tile:GetAttribute("revealed_bombs") + 1)

			return
		end
	end

	-- else, add 1 to nearby non-bombs
	for _, adjacent_tile in ipairs(neighbor_list) do
		if adjacent_tile:GetAttribute("revealed") and not adjacent_tile:GetAttribute("bomb") then
			adjacent_tile:SetAttribute("revealed_bombs", adjacent_tile:GetAttribute("revealed_bombs") + 1)
		end
	end
end

local nature_storage = ServerStorage.Special_Tiles.Nature

function update_nature()
	local nature_addition
	local is_destroyed = not this_tile:GetAttribute("bomb")

	if tile_type_string == "farm" then
		if is_destroyed then
			nature_addition = nature_storage.DeadGrass:Clone()
		else
			nature_addition = nature_storage.Wheat:Clone()
		end

	elseif tile_type_string == "lumber" then
		if is_destroyed then
			nature_addition = nature_storage.DeadForest:Clone()
		else
			nature_addition = nature_storage.Forest:Clone()
		end

	elseif tile_type_string == "oil" then
		
		if is_destroyed then
			-- show empty oil
			for _, land in ipairs(lands) do
				-- place pieces in each square, top left, top right, bottom left, bottom right
				--local forest = workspace.Special_Tiles.Nature.Forest:Clone()
				--forest.Parent = lands[1]
				--forest:PivotTo(lands[1].CFrame * CFrame.Angles(0 ,math.rad(180),0))
			end
			
		else
			-- show oil full
			for _, land in ipairs(lands) do
				-- place pieces in each square, top left, top right, bottom left, bottom right
				--local forest = workspace.Special_Tiles.Nature.Forest:Clone()
				--forest.Parent = lands[1]
				--forest:PivotTo(lands[1].CFrame * CFrame.Angles(0 ,math.rad(180),0))
			end
		end
	end

	if nature_addition then
		nature_addition.Parent = lands[1].Nature
		nature_addition:PivotTo(lands[1].CFrame * CFrame.Angles(0 ,math.rad(180),0))
	end
end

function prospect_flagged()
	if this_tile:GetAttribute("bomb") then
		update_text()
		
		-- blocked bomb same as hidden bomb
		if has_building(lands) then
			update_color()
		
		-- update neighboring tiles from revealing this bomb
		else
			free_bomb(this_tile)
		end

		-- update the nature for the tile after resource found
		update_nature()
			
	-- normal tile
	else
		-- we marked a tile, then bought it, and it was normal
		-- there needs to be some type of punishment, otherwise right clicking before buying will always be optimal with no consequence
		-- best ideas:
		-- all resources in the area are destroyed
		-- only one resource is the area is destroyed if there is one
		-- cost extra money? -> least destructive of environment
		-->>> every marked prospect costs more!<<<*********************************************************
	end
end

function prospect_not_flagged()
	-- if tile not marked and bought, lose resource
	if this_tile:GetAttribute("bomb") then
		this_tile:SetAttribute("bomb", false)
		
		-- update neighboring tiles from destroying this bomb tile
		destroy_bomb()
		
		-- update the nature for the tile after it has been destroyed
		update_nature()

		-- bomb tile not marked so return it to a regular tile
		dynamic_reveal_tile(this_tile)
	end
	-- else buying normal tile
end

function prospect()
	-- cannot prospect a tile that is revealed so exit
	if this_tile:GetAttribute("revealed") then
		return
	end

	-- if tile marked and then bought
	local flag = false

	for _, land in ipairs(lands) do
		if land.Color == Color3.fromRGB(255, 0, 4) then
			--print("flag true")
			flag = true
		end
	end
	
	-- check if enough money to prospect flagged
	local cost = this_tile:GetAttribute("cost")
	if flag and cost ~= "Free" then
		cost = string.gsub(cost, "%$", "")
		--print(cost)
		if tonumber(cost) > tonumber(money.Text) then
			return -- broke
		end
		money.Text = tonumber(money.Text) - cost
	end
	
	-- triggers land color and material to update
	this_tile:SetAttribute("revealed", true)
	
	--for _, land in ipairs(lands) do
	--	land.Material = "Grass"
	--	land.Color = Color3.fromRGB(0, 107, 0)
	--end
	
	-- handle tile types
	-- free tile (tier 0)
	--if tile_type_string == "empty" then
	--	text_label.Text = "0"
		--return

	-- dynamic value determination since tile isnt a bomb or free
	if not this_tile:GetAttribute("bomb") then
		dynamic_reveal_tile(this_tile)
	end
	-- else -> is a bomb

	-- now prospect
	if flag then
		prospect_flagged()
	else
		prospect_not_flagged()
	end
	
	-- reveal all tiles around empty tiles
	if not this_tile:GetAttribute("bomb") and this_tile:GetAttribute("adjacent_bombs") == 0 then
		reveal_zeroes(this_tile)
	end
end

function reveal_zeroes(tile)
	local neighbor_list = get_neighbor_list(tile)
	local do_list = {}

	-- loop through neighbors and reveal if not already
	for _, neighbor_tile in ipairs(neighbor_list) do
		if not neighbor_tile:GetAttribute("revealed") then
			-- reveal
			dynamic_reveal_tile(neighbor_tile)
			neighbor_tile:SetAttribute("revealed", true)

			-- if revealed tile has 0 adjacent bombs then repeat
			if not neighbor_tile:GetAttribute("bomb") and neighbor_tile:GetAttribute("adjacent_bombs") == 0 then
				table.insert(do_list, neighbor_tile)
			end
		end
	end
	
	for _, neighbor_tile in ipairs(do_list) do
		reveal_zeroes(neighbor_tile)
	end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																				-- Building ---
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function block_bomb(bomb_tile)
	if bomb_tile:GetAttribute("harvested") ~= "" then
		remove_harvested(bomb_tile:GetAttribute("harvested"))
		
		local harvesting_tile = tile_group:FindFirstChild(tile_type_string .. "_" .. bomb_tile:GetAttribute("harvested"))
		harvesting_tile:SetAttribute("revealed_bombs", harvesting_tile:GetAttribute("revealed_bombs") - 1)
		
		bomb_tile:SetAttribute("harvested", "")
		return
	end
	
	local neighbor_list = get_neighbor_list(bomb_tile)
	
	-- else, remove 1 from nearby non-bombs
	for _, neighbor_tile in ipairs(neighbor_list) do
		if neighbor_tile:GetAttribute("revealed") and not neighbor_tile:GetAttribute("bomb") then
			neighbor_tile:SetAttribute("revealed_bombs", neighbor_tile:GetAttribute("revealed_bombs") - 1)
		end
	end
end

function build_harvester()
	-- TODO update this when 8x8
	-- add harvester to server list
	--update_harvester_list:Fire(x, y, true)
	
	local harvested_count = 0

	if this_tile:GetAttribute("bomb") and this_tile:GetAttribute("harvested") == "" then
		block_bomb(this_tile)

		harvested_count = harvested_count + 1
		this_tile:SetAttribute("harvested", x .. "x" .. y)
	end

	-- check for harvested tiles. update all neighbors^2 because we will harvest those resources if they are free
	local neighbor_list = get_neighbor_list(this_tile)

	for _, neighbor_tile in ipairs(neighbor_list) do
		if neighbor_tile:GetAttribute("bomb") and neighbor_tile:GetAttribute("revealed") and not has_building(get_lands(neighbor_tile)) and neighbor_tile:GetAttribute("harvested") == "" then
			block_bomb(neighbor_tile)

			harvested_count = harvested_count + 1
			neighbor_tile:SetAttribute("harvested", x .. "x" .. y)
		end
	end

	this_tile:SetAttribute("harvester", true)

	if harvested_count > 0 then
		this_tile:SetAttribute("revealed_bombs", harvested_count)

		-- reset gui so it at least shows (0)
	elseif this_tile:GetAttribute("bomb") then
		update_text()
	end
end

local resource_building_list = {
	farm = "Farm",
	lumber = "Sawmill"
}
local capital_list_adjustment = 1

local building_costs = {
	House = 5,
	Farm = 10,
	Sawmill = 20,
	Emptys = 0,
	Farms = 5,
	Lumbers = 10,
}

local building_list = ServerStorage.Special_Tiles.Buildings
local capital_list = ServerStorage.Special_Tiles.Capitals

-- always matches current grid, only show options available for grid
function build(building_name)
	-- if has buildings or not revealed then cant build
	if has_building(lands) or not this_tile:GetAttribute("revealed") then
		return
	end
	
	local building_part
	
	local capital = false
	-- capital
	if building_name == tile_event_list[4] then
		if tile_group:GetAttribute("capital") then
			return
		end
		
		capital = true
		
		-- determine player tile tier
		local tile_tier = 0
		-- local tile_tier = tonumber(workspace:GetAttribute("tier"))
		
		--building_name = capital_list[tile_tier + capital_list_adjustment]
		building_name = tile_group_string
		
		-- update capital locations so that they can be used to calculate distance for income
		-- 8x8 capital...
		if tile_tier > 2 then
			for i = 2*x - 1, 2*x, 1 do
				for j = 2*y - 1, 2*y, 1 do
					update_capital_list:Fire(i, j, true)
				end
			end
			
		-- capital is just 4x4 not 8x8
		else
			update_capital_list:Fire(x, y, true)
		end
		
		tile_group:SetAttribute("capital", true)
		
		building_part = capital_list:FindFirstChild(building_name)
		
	-- regular building
	else
		building_part = building_list:FindFirstChild(building_name)
	end
	
	if building_part then
		local count = building_part:GetAttribute("count")
		local cost = math.max(building_costs[building_part.Name], 0) + count
		if cost > tonumber(money.Text) then
			return -- broke
		end
		money.Text = tonumber(money.Text) - cost
		building_part:SetAttribute("count", count + 1)
		
		if #lands == 1 then
			local building = building_part:Clone()
			building.Parent = lands[1].Buildings
			building:PivotTo(lands[1].CFrame * CFrame.Angles(0 ,math.rad(180),0))
			
			-- capital
			if capital then
				building:SetAttribute("group", tile_group_string)
			end
			
		elseif #lands > 1 then
			--8x8
		end
	end
	
	-- remove this land from harvesting land list!
		-- ex: this tile is a bomb in another type, placing building here now blocks!
	remove_harvested_from_neighboring_land()
		
	
	-- if building type doesnt match tile type!
	if resource_building_list[tile_type_string] ~= building_name then
		-- update neighbor tile counts if bomb
		if this_tile:GetAttribute("bomb") then
			block_bomb(this_tile)
			update_color()
		end
		return
	end
	
	-- else building is harvester
	build_harvester()
end

		
-- player can only build resource specific building or other generic ones
--function build_4x4(building_type)
		
--	-- if no other buildings. otherwise must sell!
--	local land_open = true
--	if #lands[1].Buildings:GetChildren() > 0 then
--		land_open = false
--	end
	
--	-- land must be open
--	if not land_open then
--		return
--	end
	
--	local building_list = workspace.Special_Tiles.Buildings
--	local building_name = building_type
	

	
--	-- capital
--	if building_type == tile_event_list[4] then
--		--if 
--		building_name = "VillageCenter"
--	end
	
--	local building = building_list:FindFirstChild(building_name):Clone()
--	building.Parent = lands[1].Buildings
--	building:PivotTo(lands[1].CFrame * CFrame.Angles(0 ,math.rad(180),0))
	
		
	
		
--	--	--if not land:FindFirstChild("Farm") then

--	--		local farm = workspace.Special_Tiles.Buildings.Farm:Clone()
--	--		farm.Parent = lands[1].Buildings
--	--		farm:PivotTo(lands[1].CFrame * CFrame.Angles(0 ,math.rad(180),0))
			
--	--	--end

--	--elseif building_type == "lumber" then
		
--	--	--if not land:FindFirstChild("Sawmill") then

--	--		local sawmill = workspace.Special_Tiles.Buildings.Sawmill:Clone()
--	--		sawmill.Parent = lands[1].Buildings
--	--		sawmill:PivotTo(lands[1].CFrame * CFrame.Angles(0 ,math.rad(180),0))

--	--	--end
	
--	--elseif building_type == "oil" then
--	--	for _, land in ipairs(lands) do
--	--		-- place pieces in each square, top left, top right, bottom left, bottom right
--	--		--local forest = workspace.Special_Tiles.Nature.Forest:Clone()
--	--		--forest.Parent = lands[1]
--	--		--forest:PivotTo(lands[1].CFrame * CFrame.Angles(0 ,math.rad(180),0))
--	--	end
--	--end
--end

--function build_8x8()
--	-- if no other buildings. otherwise must sell!
--	local land_open = true
--	for _, land in ipairs(lands) do
--		if #land.Buildings:GetChildren() > 0 then
--			land_open = false
--			break
--		end
--	end
--end

--local block_repeated_calls = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																	-- Selling ---
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function sell_harvester()
	-- TODO update this when 8x8
	
	-- not yet needed
		-- remove harvester from income list
		--update_harvester_list:Fire(x, y, false)
		
	this_tile:SetAttribute("harvester", false)

	if this_tile:GetAttribute("bomb") then
		this_tile:SetAttribute("revealed_bombs", 0)

		if this_tile:GetAttribute("harvested") == x .. "x" .. y then
			this_tile:SetAttribute("harvested", "")
		end
	end

	-- check for harvested tiles. update all neighbors^2 because we will harvest those resources if they are free
	local neighbor_list = get_neighbor_list(this_tile)

	-- loop through and see what tiles are harvested by this_tile:
	for _, neighbor_tile in ipairs(neighbor_list) do
		-- if this_tile is a bomb and a neighbor is a harvester, then add this_tile back!
		if this_tile:GetAttribute("bomb") and this_tile:GetAttribute("harvested") == "" and neighbor_tile:GetAttribute("harvester") then
			local coor_a, coor_b = get_coordinates(neighbor_tile)
			this_tile:SetAttribute("harvested", coor_a .. "x" .. coor_b)

			neighbor_tile:SetAttribute("revealed_bombs", neighbor_tile:GetAttribute("revealed_bombs") + 1)
		end

		-- check all neighbors that were harvested by this_tile
		if neighbor_tile:GetAttribute("bomb") and neighbor_tile:GetAttribute("harvested") ==  x .. "x" .. y then
			neighbor_tile:SetAttribute("harvested", "")

			-- check if any neighbors are harvesting
			local adjacent_neighbor_list = get_neighbor_list(neighbor_tile)
			for _, adjacent_sqrd_tile in ipairs(adjacent_neighbor_list) do
				if adjacent_sqrd_tile:GetAttribute("harvester") and neighbor_tile:GetAttribute("harvested") == "" then
					local coor_a, coor_b = get_coordinates(adjacent_sqrd_tile)
					neighbor_tile:SetAttribute("harvested", coor_a .. "x" .. coor_b)

					this_tile:SetAttribute("revealed_bombs", this_tile:GetAttribute("revealed_bombs") - 1)
					adjacent_sqrd_tile:SetAttribute("revealed_bombs", adjacent_sqrd_tile:GetAttribute("revealed_bombs") + 1)
					break
				end
			end

			-- finally check if itself is harvesting
			if neighbor_tile:GetAttribute("harvester") and neighbor_tile:GetAttribute("harvested") == "" then
				local coor_a, coor_b = get_coordinates(neighbor_tile)
				neighbor_tile:SetAttribute("harvested", coor_a .. "x" .. coor_b)

				this_tile:SetAttribute("revealed_bombs", this_tile:GetAttribute("revealed_bombs") - 1)
				neighbor_tile:SetAttribute("revealed_bombs", neighbor_tile:GetAttribute("revealed_bombs") + 1)
			end

			-- if we are not being harvested by a new harvester, then we need to add 1 to all nearby regular tiles
			if neighbor_tile:GetAttribute("harvested") ~= "" then
				continue
			end
			for _, adjacent_sqrd_tile in ipairs(adjacent_neighbor_list) do
				if not adjacent_sqrd_tile:GetAttribute("bomb") and adjacent_sqrd_tile:GetAttribute("revealed") and adjacent_sqrd_tile ~= this_tile then
					adjacent_sqrd_tile:SetAttribute("revealed_bombs", adjacent_sqrd_tile:GetAttribute("revealed_bombs") + 1)
				end
			end
		end
	end

	-- check at the end if it didnt end up finding a new harvester
	if this_tile:GetAttribute("bomb") and this_tile:GetAttribute("harvested") == "" then
		free_bomb(this_tile)
	end
end

function sell()
	local sell = false
	
	for _, land in ipairs(lands) do
		if #land.Buildings:GetChildren() > 0 then
			local building = land.Buildings:GetChildren()[1]
			
			local building_template
			
			-- if capital
			if building:GetAttribute("group") then
				local coordinates = string.gsub(land.Name, "land" .. "_", "", 1)
				local i, j = table.unpack(string.split(coordinates, "x"))
				
				update_capital_list:Fire(i, j, false)
				
				if building:GetAttribute("group") == tile_group_string then
					tile_group:SetAttribute("capital", false)
				else
					local other_tile_group = workspace:FindFirstChild(building:GetAttribute("group"))
					other_tile_group:SetAttribute("capital", false)
				end
				
				building_template = capital_list:FindFirstChild(building.Name)
			
			-- if regular building
			else
				building_template = building_list:FindFirstChild(building.Name)
			end
			
			building_template:SetAttribute("count", building_template:GetAttribute("count") - 1)
			
			-- TODO:
			--local cost = building:GetAttribute("cost")
			
			--local refund = cost / 2
			
			--local resource_gui = ServerStorage.Resources
			--local money = resource_gui:FindFirstChild("1.Money").Count.Text
			
			--local resource_gui:FindFirstChild("1.Money").Count.Text = money + refund
			
			building:Destroy()

			sell = true
		end
	end
	
	if not sell then
		return
	end
	
	-- TODO: impossible to re-add this tile to harvesting count if different type
	
	-- in case this building was harvesting in another type
	reset_harvested_count()
	
	-- sold regular building
	if not this_tile:GetAttribute("harvester") then
		-- TODO: check if building sold is of harvesting type. then need to update harvester list
		-- update_harvester_list:Fire(x, y, false)
		
		if this_tile:GetAttribute("bomb") and this_tile:GetAttribute("revealed") then
			free_bomb(this_tile)
			update_color()
		end		
		return
	end
	
	-- building was harvesting
	sell_harvester()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																			-- Dynamic Updating ---
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function update_land()
	for _, land in ipairs(lands) do
		land.Material = "Grass"
		--if land.Color ~= Color3.fromRGB(255, 0, 4) then
			land.Color = Color3.fromRGB(0, 107, 0)
		--end
	end
end
this_tile:GetAttributeChangedSignal("revealed"):Connect(update_land)

-- updates the text for all tiles
function update_text()
	local revealed_bombs = this_tile:GetAttribute("revealed_bombs")
	
	if this_tile:GetAttribute("bomb") then
		if this_tile:GetAttribute("harvester") then
			text_label.Text = "x(" .. revealed_bombs .. ")"
		else
			text_label.Text = "x"
		end
		return
	end
	
	local adjacent_bombs = this_tile:GetAttribute("adjacent_bombs")

	if revealed_bombs == adjacent_bombs then
		text_label.Text = adjacent_bombs
	else
		text_label.Text = adjacent_bombs .. "(" .. revealed_bombs .. ")"
	end
end
this_tile:GetAttributeChangedSignal("adjacent_bombs"):Connect(update_text)
this_tile:GetAttributeChangedSignal("revealed_bombs"):Connect(update_text)

-- updates the color for all tiles
function update_color()
	if this_tile:GetAttribute("harvester") or (this_tile:GetAttribute("bomb") and this_tile:GetAttribute("harvested") ~= "") then
		text_label.TextColor3 = Color3.fromRGB(0, 255, 8)
		
	elseif this_tile:GetAttribute("bomb") and has_building(lands) then
		text_label.TextColor3 = Color3.fromRGB(255, 0, 4)
		
	else
		text_label.TextColor3 = Color3.fromRGB(0,0,0)
	end	
end
this_tile:GetAttributeChangedSignal("harvested"):Connect(function()
	update_color()
	add_harvested()
end)
this_tile:GetAttributeChangedSignal("harvester"):Connect(update_color)


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
															-- Updating land for harvesting changes ---
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function add_harvested_count(harvesting_lands)
	if not harvesting_lands[1]:GetAttribute("harvesting") or harvesting_lands[1]:GetAttribute("harvesting") == "" then
		harvesting_lands[1]:SetAttribute("harvesting", x .. "x" .. y)
	else
		harvesting_lands[1]:SetAttribute("harvesting", harvesting_lands[1]:GetAttribute("harvesting") .. "," .. x .. "x" .. y)
	end
end

-- update land tiles for tracking harvesting
function add_harvested()
	if this_tile:GetAttribute("harvested") ~= "" then
		if this_tile:GetAttribute("harvested") == x .. "x" .. y then
			add_harvested_count(lands)
		else
			local harvesting_tile = tile_group:FindFirstChild(tile_type_string .. "_" .. this_tile:GetAttribute("harvested"))
			print(harvesting_tile)
			local harvesting_lands = get_lands(harvesting_tile)
			
			add_harvested_count(harvesting_lands)
		end
	end
end

-- TODO: issue: when building on tile that is being harvested in another tier, no way to update income calculator
--> solution was to just check if that tile is blocked. is that good enough?
--> alternative: give more attributes to land
function remove_harvested_count(harvesting_lands)
	if harvesting_lands[1]:GetAttribute("harvesting") == x .. "x" .. y then
		harvesting_lands[1]:SetAttribute("harvesting", "")
	else
		local harvesting_str = harvesting_lands[1]:GetAttribute("harvesting")
		local start_str, end_str = string.find(harvesting_str, x .. "x" .. y)

		local new_str = ""

		if start_str == 1 then
			new_str = string.sub(harvesting_str, end_str + 2, -1)
		elseif end_str == #harvesting_str then
			new_str = string.sub(harvesting_str, 1, start_str - 2)
		else
			new_str = string.sub(harvesting_str, 1, start_str - 2) .. "," .. string.sub(harvesting_str, end_str + 2, -1)
		end

		harvesting_lands[1]:SetAttribute("harvesting", new_str)
	end
end

function remove_harvested(removed_coordinates)
	if removed_coordinates == x .. "x" .. y then
		remove_harvested_count(lands)
	else -- different tile
		local harvesting_tile = tile_group:FindFirstChild(tile_type_string .. "_" .. removed_coordinates)
		local harvesting_lands = get_lands(harvesting_tile)

		remove_harvested_count(harvesting_lands)
	end
end

function reset_harvested_count()
	lands[1]:SetAttribute("harvesting", "")
end

function remove_harvested_from_neighboring_land()
	local neighbor_list = get_neighbor_list(this_tile)

	for _, neighbor_tile in ipairs(neighbor_list) do
		local neighbor_tile_lands = get_lands(neighbor_tile)
		if neighbor_tile_lands[1]:GetAttribute("harvesting") and neighbor_tile_lands[1]:GetAttribute("harvesting") ~= "" then
			if string.find(neighbor_tile_lands[1]:GetAttribute("harvesting"), x .. "x" .. y) then
				remove_harvested_count(neighbor_tile_lands)
				return
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																-- Updating changes made while tiles werent in play ---
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

this_tile:GetPropertyChangedSignal("CFrame"):Connect(function()
	-- update tiles after changes were made while in another tier
	if this_tile:GetAttribute("revealed") then
		-- below operations need to wait. this is bottom of function so wait wont harm us
		--task.wait()

		if has_building(lands) then
			-- tile was previously harvesting, now new building is on top
			if this_tile:GetAttribute("harvester") and resource_building_list[tile_type_string] ~= lands[1].Buildings:GetChildren()[1].Name then
				sell_harvester()

				if this_tile:GetAttribute("bomb") then
					block_bomb(this_tile)
				end

				-- bomb was not blocked prior
			elseif not this_tile:GetAttribute("harvester") and this_tile:GetAttribute("bomb") and text_label.TextColor3 ~= Color3.fromRGB(255, 0, 4) then
				block_bomb(this_tile)
				update_color()
			end

			-- now there is no building
		else
			if this_tile:GetAttribute("harvester") then
				sell_harvester()

				-- bomb was blocked earlier
			elseif this_tile:GetAttribute("bomb") and text_label.TextColor3 == Color3.fromRGB(255, 0, 4) then			
				-- must wait for other tiles to load!
				free_bomb(this_tile)
				update_color()
			end
		end
	end
end)

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																						-- Player Actions ---
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function flag()
	local flag = false

	for _, land in ipairs(lands) do

		if land.Color == Color3.fromRGB(255, 0, 4) then
			flag = true
			break
		end
	end

	for _, land in ipairs(lands) do
		if flag then
			if not this_tile:GetAttribute("revealed") then
				this_tile.SurfaceGui.Frame.TextLabel.Text = ""
			end

			if land.Material == Enum.Material.Plastic then
				land.Color = Color3.fromRGB(99, 95, 98)
			else
				land.Color = Color3.fromRGB(0, 107, 0)
			end
		else
			land.Color = Color3.fromRGB(255, 0, 4)

			if not this_tile:GetAttribute("revealed") then
				this_tile.SurfaceGui.Frame.TextLabel.Text = this_tile:GetAttribute("cost")
			end
		end
	end
end

-- right click, as in putting flag
click_detector.RightMouseClick:Connect(flag)

-- left click to apply action on tile
click_detector.MouseClick:Connect(function(player)
	local tile_event = player:GetAttribute("build")
	--print(tile_event)

	if tile_event == nil then
		return

			-- prospect
	elseif tile_event == tile_event_list[1] then
		prospect()

		-- flag
	elseif tile_event == tile_event_list[2] then
		flag()

		-- sell
	elseif tile_event == tile_event_list[3] then
		sell()

		-- building
	else 
		build(tile_event)
	end

	---- bigger capital
	--elseif tile_event == tile_event_list[5] then
	--	build_8x8(tile_event)

	---- house
	--elseif tile_event == tile_event_list[6] then
	--	build_4x4(tile_event)
	---- farm
	--elseif tile_event == tile_event_list[7] then
	--	build_4x4(tile_event)
	---- sawmill
	--elseif tile_event == tile_event_list[8] then
	--	build_4x4(tile_event)
	---- future
	--elseif tile_event == tile_event_list[9] then
	--	build_8x8(tile_event)
	--end

	--print("test")
end)

-- TODO eventually make this clientsided
if true then
	this_tile.SelectionBox.Transparency = 1

	click_detector.MouseHoverEnter:Connect(function()
		this_tile.SelectionBox.Transparency = 0
	end)

	click_detector.MouseHoverLeave:Connect(function()
		this_tile.SelectionBox.Transparency = 1
	end)
end