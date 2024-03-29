-- GuildInfo
-- by Pizzasgood

declare('GuildInfo', GuildInfo or {})

GuildInfo.version = 0.1

dofile('tcpsock.lua')
dofile('http.lua')

local color = '\127FFFFFF'
local subcolor = '\127AAAAAA'
local titlecolor = '\127FFFFAA'

GuildInfo.main_url = 'http://www.vendetta-online.com'
GuildInfo.guildinfo_url = GuildInfo.main_url .. '/x/guildinfo/'
GuildInfo.charinfo_url = GuildInfo.main_url .. '/x/stats/'
GuildInfo.guilds = {}
GuildInfo.players = {}
GuildInfo.processing = {}
GuildInfo.rwr_timer = Timer()

function GuildInfo:is_active()
	return self.busy or table.getn2(self.processing) > 0
end

function GuildInfo:ready_check()
	if self:is_active() then
		print(color .. "Error:  GuildInfo is still processing, please wait for it to finish." .. '\127o')
		return false
	else
		return true
	end
end

function GuildInfo:run_when_ready(callback)
	if self:is_active() then
		self.rwr_timer:SetTimeout(100, function() self:run_when_ready(callback) end)
	else
		callback()
	end
end

function GuildInfo:update_links()
	self.busy = true
	print(color .. "Updating guild info..." .. '\127o')
	self.main_page = nil
	HTTP.urlopen(self.guildinfo_url, 'POST', function(success, header, page) 
			if success ~= nil and header.status == 200 then
				GuildInfo.main_page = page
				GuildInfo:process_main_page()
				GuildInfo:process_results()
			end
			self.busy = false
			self:run_when_ready(function()
				self:update_players()
				print(color .. "Finished" .. '\127o')
			end)
		end, {})
end

function GuildInfo:process_main_page()
	if self.main_page == nil then return end
	for id, name, tag, num_members in self.main_page:gmatch("/x//guildinfo/(%d+).->(.-)</a>[^[]*%[(.-)%]</td>.-<td>(%d+)</td>") do
		if self.guilds[tag] == nil then self.guilds[tag] = {} end
		self.guilds[tag].id = id
		self.guilds[tag].name = name
		self.guilds[tag].tag = tag
		self.guilds[tag].num_members = tonumber(num_members)
	end
end
function GuildInfo:process_results(force)
	if self.guilds == nil then return end
	self.processing = {}
	for i,guild in pairs(self.guilds) do
		if self.guilds[i].members == nil then self.guilds[i].members = {} end
		if force or self.guilds[i].num_members ~= table.getn2(self.guilds[i].members) then
			self.processing[i] = true
			self:process_guild(i)
		end
	end
end

function GuildInfo:process_guild(index)
	HTTP.urlopen(self.guildinfo_url .. self.guilds[index].id, 'POST', function(success, header, page) 
			if success ~= nil and header ~= nil and header.status == 200 then
				GuildInfo:process_sub_page(index, page)
			end
			GuildInfo.processing[index] = nil
		end, {})
end

function GuildInfo:process_sub_page(index, page)
	if page == nil then return end
	for id, nation, name, rank in page:gmatch("/x/stats/(%d+).-class=['\"]?(.-)['\"]?>(.-)</font></a>.-([%a ]+)</td></tr>") do
		if self.guilds[index].members == nil then self.guilds[index].members = {} end
		self.guilds[index].members[name] = {}
		self.guilds[index].members[name].name = name
		self.guilds[index].members[name].id = id
		self.guilds[index].members[name].nation = nation
		self.guilds[index].members[name].rank = rank
	end
end


function GuildInfo:get_commander(tag)
	for i,m in self.guilds[tag].members do
		if m.rank == "Commander" then
			return(m.name)
		end
	end
end


function GuildInfo:get_officers(tag)
	local officers = {}
	for i,m in pairs(self.guilds[tag].members) do
		if m.rank == "Lieutenant" or m.rank == "Council and Lieutenant" then
			officers[m.name] = m.rank
		end
	end
	return officers
end


function GuildInfo:get_council(tag)
	local council = {}
	for i,m in pairs(self.guilds[tag].members) do
		if m.rank == "Council" or m.rank == "Council and Lieutenant" then
			council[m.name] = m.rank
		end
	end
	return council
end


function GuildInfo:get_important(tag)
	local people = {}
	for i,m in pairs(self.guilds[tag].members) do
		if m.rank ~= "Member" then
			people[m.name] = m.rank
		end
	end
	return people
end


function GuildInfo:list_guilds()
	for i,g in pairs(self.guilds) do
		print(color .. "[" .. g.tag .. "] " .. g.name .. '\127o')
	end
end


function GuildInfo:update_players()
	self.players = {}
	for gi,g in pairs(self.guilds) do
		for mi,m in pairs(g.members) do
			self.players[m.name] = g.tag
		end
	end
end


function GuildInfo:short_guild_info(tag)
	if self.guilds[tag] == nil then
		print(color .. "Unknown guild " .. tag .. '\127o')
		return
	end

	local people = self:get_important(tag)
	local name = self.guilds[tag].name
	local size = self.guilds[tag].num_members

	print(titlecolor .. "[" .. tag .. "] " .. name .. '\127o')
	print(color .. "Total members: " .. size .. '\127o')
	if people then
		for m,r in pairs(people) do
			if r == "Commander" then
				print(subcolor .. r .. ": " .. '\127o' .. self:get_colored_name(m))
				break
			end
		end
		for m,r in pairs(people) do
			if r == "Lieutenant" or r == "Council and Lieutenant" then
				print(subcolor .. r .. ": " .. '\127o' .. self:get_colored_name(m))
			end
		end
		for m,r in pairs(people) do
			if r == "Council" then
				print(subcolor .. r .. ": " .. '\127o' .. self:get_colored_name(m))
			end
		end
	end
end


function GuildInfo:long_guild_info(tag)
	if self.guilds[tag] == nil then
		print(color .. "Unknown guild " .. tag .. '\127o')
		return
	end

	self:short_guild_info(tag)

	for i,m in pairs(self.guilds[tag].members) do
		if m.rank == "Member" then
			print(subcolor .. m.rank .. ": " .. '\127o' .. self:get_colored_name(m))
		end
	end
end


function GuildInfo:short_player_info(name)
	if self.players[name] == nil then
		print(color .. "Unknown player " .. name .. '\127o')
		return
	end

	local player = self:get_player(name)
	print(subcolor .. "(" .. player.rank .. ") " .. '\127o' .. self:get_colored_name_with_tag(player))
end


function GuildInfo:long_player_info(name)
	print(color .. "This is not implemented, falling back to short_player_info" .. '\127o')
	self:short_player_info(name)
end


function GuildInfo:get_player(name)
	if name == nil or self.players[name] == nil then return end
	return self.guilds[self.players[name]].members[name]
end


function GuildInfo:get_colored_name_with_tag(player)
	if player == nil then return '' end
	if player.name == nil then player = self:get_player(player) end
	return(self:get_color(player.nation) .. "[" .. self.players[player.name] .. "] " .. player.name .. '\127o')
end

function GuildInfo:get_colored_name(player)
	if player == nil then return '' end
	if player.name == nil then player = self:get_player(player) end
	return(self:get_color(player.nation) .. player.name .. '\127o')
end

function GuildInfo:get_color(nation)
	local faction = nation
	--the website calls UIT people Neutral instead, so fix
	if nation == 'Neutral' then
		faction = 'UIT'
	end

	local factionid = 0
	for i,v in pairs(FactionName) do
		if faction == v then
			factionid = tonumber(i)
			break
		end
	end

	return rgbtohex(FactionColor_RGB[factionid])
end


function GuildInfo.proc(_,data)
	if (data == nil) then
		if not GuildInfo:ready_check() then return end
		GuildInfo:update_links()
	elseif (data[1] == "l") then
		if not GuildInfo:ready_check() then return end
		GuildInfo:list_guilds()
	elseif (#data > 1 and data[1] == "g") then
		if not GuildInfo:ready_check() then return end
		GuildInfo:short_guild_info(string.upper(data[2]))
	elseif (#data > 1 and data[1] == "gg") then
		if not GuildInfo:ready_check() then return end
		GuildInfo:long_guild_info(string.upper(data[2]))
	elseif (#data > 1 and data[1] == "p") then
		if not GuildInfo:ready_check() then return end
		GuildInfo:short_player_info(data[2])
	elseif (#data > 1 and data[1] == "pp") then
		if not GuildInfo:ready_check() then return end
		GuildInfo:long_player_info(data[2])
	else
		print(titlecolor .. "GuildInfo" .. '\127o' .. color .. " " .. string.format("%0.1f",GuildInfo.version) .. '\127o')
		print(subcolor .. "Pulls information about guilds from the website." .. '\127o')
		print(color .. "/guildinfo          " .. '\127o' .. subcolor .. "\tupdates database" .. '\127o')
		print(color .. "/guildinfo l        " .. '\127o' .. subcolor .. "\tlist guilds" .. '\127o')
		print(color .. "/guildinfo p <name> " .. '\127o' .. subcolor .. "\tplayer info" .. '\127o')
		print(color .. "/guildinfo g <tag>  " .. '\127o' .. subcolor .. "\tguild info" .. '\127o')
		print(color .. "/guildinfo gg <tag> " .. '\127o' .. subcolor .. "\tfull guild info" .. '\127o')
	end
end

RegisterUserCommand("guildinfo", GuildInfo.proc)
