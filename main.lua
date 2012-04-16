-- GuildInfo
-- by Pizzasgood

declare('GuildInfo', GuildInfo or {})

GuildInfo.version = 0.1

dofile('tcpsock.lua')
dofile('http.lua')

local color = '\127FFFFFF'
local subcolor = '\127AAAAAA'
local titlecolor = '\127FFFFAA'

GuildInfo.main_url = 'http://www.vendetta-online.com/x/guildinfo'
GuildInfo.guilds = {}

function GuildInfo:process_page()
	if self.main_page == nil then return end
	print("processing")
	for link, name, tag, num_members in self.main_page:gmatch("(/x//guildinfo/%d+).->(.-)</a>[^[]*%[(.-)%]</td>.-<td>(%d+)</td>") do
		self.guilds[tag] = {}
		self.guilds[tag].link = link
		self.guilds[tag].name = name
		self.guilds[tag].tag = tag
		self.guilds[tag].num_members = num_members
	end
end

function GuildInfo:update_links()
	self.main_page = nil
	HTTP.urlopen(self.main_url, 'POST', function(success, header, page) 
			if success ~= nil and header.status == 200 then
				print("worked")
				GuildInfo.main_page = page
				GuildInfo:process_page()
			else
				print("Failed")
				print(success)
				if header ~= nil then print(header.status) end
			end
		end, {})
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
