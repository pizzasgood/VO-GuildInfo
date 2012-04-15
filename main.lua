-- GuildInfo
-- by Pizzasgood

declare('GuildInfo', GuildInfo or {})

GuildInfo.version = 0.1

dofile('http.lua')

local color = '\127FFFFFF'
local subcolor = '\127AAAAAA'
local titlecolor = '\127FFFFAA'

function GuildInfo.proc(_,data)
	if (data == nil) then
		GuildInfo.toggle()
	elseif (data[1] == "start") then
		GuildInfo.enable()
	elseif (data[1] == "stop") then
		GuildInfo.disable()
	else
		print(titlecolor.."GuildInfo"..'\127o'..color.." "..string.format("%0.1f",GuildInfo.version)..'\127o')
		print(color.." Pulls information about guilds from the website."..'\127o')
	end
end

RegisterUserCommand("guildinfo", GuildInfo.proc)
