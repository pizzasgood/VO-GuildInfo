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
GuildInfo.processing = {}

function GuildInfo:update_links()
	if table.getn2(self.processing) > 0 then
		print("GuildInfo is already processing, please wait for it to finish.")
		return
	end
	print("Fetching main page...")
	self.main_page = nil
	HTTP.urlopen(self.guildinfo_url, 'POST', function(success, header, page) 
			if success ~= nil and header.status == 200 then
				print("Success")
				GuildInfo.main_page = page
				GuildInfo:process_main_page()
				GuildInfo:process_results()
			else
				print("Failed")
				print(success)
				if header ~= nil then print(header.status) end
			end
		end, {})
end

function GuildInfo:process_main_page()
	if self.main_page == nil then return end
	print("processing main page")
	for id, name, tag, num_members in self.main_page:gmatch("/x//guildinfo/(%d+).->(.-)</a>[^[]*%[(.-)%]</td>.-<td>(%d+)</td>") do
		if self.guilds[tag] == nil then self.guilds[tag] = {} end
		self.guilds[tag].id = id
		self.guilds[tag].name = name
		self.guilds[tag].tag = tag
		self.guilds[tag].num_members = tonumber(num_members)
	end
	print("finished processing main page")
end
function GuildInfo:process_results(force)
	if self.guilds == nil then return end
	print("processing results")
	self.processing = {}
	for i,guild in pairs(self.guilds) do
		if self.guilds[i].members == nil then self.guilds[i].members = {} end
		if force or self.guilds[i].num_members ~= table.getn2(self.guilds[i].members) then
			print(self.guilds[i].tag .. ": " .. self.guilds[i].num_members .. " != " .. table.getn2(self.guilds[i].members))
			self.processing[i] = true
			self:process_guild(i)
		else
			print(self.guilds[i].tag .. " is fine")
		end
	end
	print("finished processing results")
end

function GuildInfo:process_guild(index)
	print("Fetching page for "..self.guilds[index].tag)
	HTTP.urlopen(self.guildinfo_url .. self.guilds[index].id, 'POST', function(success, header, page) 
			if success ~= nil and header.status == 200 then
				--print("Success")
				GuildInfo:process_sub_page(index, page)
			else
				print("Failed")
				print(success)
				if header ~= nil then print(header.status) end
			end
			GuildInfo.processing[index] = nil
		end, {})
end

function GuildInfo:process_sub_page(index, page)
	if page == nil then return end
	--print("processing sub page for "..index)
	for id, nation, name, rank in page:gmatch("/x/stats/(%d+).-class=['\"]?(.-)['\"]?>(.-)</font></a>.-(%a+)</td></tr>") do
		if self.guilds[index].members == nil then self.guilds[index].members = {} end
		self.guilds[index].members[name] = {}
		self.guilds[index].members[name].name = name
		self.guilds[index].members[name].id = id
		self.guilds[index].members[name].nation = nation
		self.guilds[index].members[name].rank = rank
	end
	--print("finished processing sub page")
end


function GuildInfo.proc(_,data)
	if (data == nil) then
		GuildInfo:update_links()
	else
		print(titlecolor.."GuildInfo"..'\127o'..color.." "..string.format("%0.1f",GuildInfo.version)..'\127o')
		print(color.." Pulls information about guilds from the website."..'\127o')
	end
end

RegisterUserCommand("guildinfo", GuildInfo.proc)
