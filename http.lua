-- $Id$
--
-- Copyright (c) 2007 Fabian "firsm" Hirschmann

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
-- 
-- The Vendetta Online Knowledge Base - http://vokb.org

-- TODO: Make this thing use make_client from vokb.

declare('HTTP', {})
HTTP.user_agent = "VOKB HTTP Client"

local wanted_headers = {
    location="Location",
    poweredby="X-Powered-By",
    contenttype="Content-type",
    server="Server",
}

local function unescape (s)
    s = string.gsub(s, "+", " ")
    s = string.gsub(s, "%%(%x%x)", function (h)
        return string.char(tonumber(h, 16))
    end)
    return s
end

local function escape (s)
    s = string.gsub(s, "([&=+%c])", function (c)
        return string.format("%%%02X", string.byte(c))
    end)
    s = string.gsub(s, " ", "+")
    return s
end

local function encode (t)
    local s = ""
    for k,v in pairs(t) do
        s = s .. "&" .. escape(k) .. "=" .. escape(v)
    end
    return string.sub(s, 2)     -- remove first `&'
end

local function decode (s)
    local cgi = {}
    for name, value in string.gfind(s, "([^&=]+)=([^&=]+)") do
        name = unescape(name)
        value = unescape(value)
        cgi[name] = value
    end
    return cgi
end

function HTTP.urlopen (url, method, callback, postdata)
    local body = ""
    local header = {}
    header.status = false
    local buffer = ""
    local to_body = false
    local active = false
    local appended = false
    local _, host, path, sock, type, length, rest
    local port = 80
    local gotit = false
    local nolen = false
    local postthis = ""
    if (method == nil) then method = "GET" end
    
    -- <a1k0n> this would be a lot easier if you just use _,_,method,host,path = string.find(url, "(.-)://(.-)/(.*)$"),
    -- but you _do_ need to append a trailing slash to urls with no path.

    if not (string.find(url, "http://(.-)/(.*)$")) then url = url..'/' end
    _,_,host,path = string.find(url, "http://(.-)/(.*)$")
    if string.find(host, ':') then
        _, _, host, port = string.find(host, "(.*):(.*)$")
        port = tonumber(port)
    end
    
    local function callcallback(suc, hd, pg)
        active = false
        if (sock) and (sock.tcp) then
            sock.tcp:Disconnect()
        end
        sock = nil
        if not (callback == nil) then
            return callback(suc, hd, pg)
        end
    end

    if not (postdata == nil) then
        postthis = encode(postdata)

        if (method == "GET") then
            path = path.."?"..postthis
        end
    elseif method == "POST" then
        return callback("I need something to post", nil, nil)
    end

    local request = ""
    request = request..method.." /"..path.." HTTP/1.1\r\n"
    request = request.."Host: "..host..":"..tostring(port).."\r\n"
    request = request.."User-Agent: "..HTTP.user_agent.."\r\n"
    request = request.."Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\n"
    request = request.."Accept-Language: en-us,en;q=0.5\r\n"
    request = request.."Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7\r\n"
    --request = request.."Keep-Alive: 300\r\n"
    request = request.."Connection: close\r\n"
    
    if method == "POST" then
        request = request.."Content-Type: application/x-www-form-urlencoded\r\n"
        request = request.."Content-Length: "..string.len(postthis).."\r\n"
        request = request.."\r\n"..postthis
    else
        request = request.."\r\n"
    end
    
    local function ConnectionTimeOut()
        if active and sock then
            return callcallback("Connection timed out", nil, nil)
        end
    end

    local function ConnectionMade(con, suc)
        if not (suc == nil) then
            return callcallback(suc, nil, nil)
        else
            con:Send(request)
            local t = Timer()
            active = true
            t:SetTimeout(15000, ConnectionTimeOut)
        end
    end
    local function LineReceived(con, line)
        --print('---'..line)

        if line == '\r' then
            to_body = true
            --print('--- got the header')
        end
        if not header.status and string.find(line, "^HTTP") then
            header.status = tonumber(string.sub(line, 10, 10+3))
        end
        
        if to_body then
            body = body..line..'\n'
            local curlen = string.len(body)
            if not (length == nil) then
                if curlen == length or curlen > length or length == 0 then
                    --print('-- got the body')
                    gotit = true
                    return callcallback(false, header, body)
                end
            else
                if not nolen then
                    --print('-- don\'t know the length, waiting for the connection to get closed by the webserver')
                    nolen = true
                end
            end
        else
            local var, val
            _, _, var, val = string.find(line, "(.*): (.*)")
            if not (var == nil) and not (val == nil) then
                for wanted, real in pairs(wanted_headers) do
                    if var == real then
                        header[wanted] = val
                    end
                end
            end

            if string.find(line, "^Content(.*)Length") and length == nil then
                _, _, _, length = string.find(line, "Content(.*): (.*)$")
                length = tonumber(length)
            end
        end
    end
    local function ConnectionLost(con)
        --print('lost connection')
        if (header.status) then
            return callcallback(false, header, body)
        else
            return callcallback("Unknown error", nil, nil)
        end
    end
    sock = TCP.make_client(host, port, ConnectionMade, LineReceived, ConnectionLost)
end


-- #### EXAMPLE 1 - HTTP GET
local function PageReceived(not_ok, header, page)
    if not_ok then
        print("ERROR: "..not_ok)
    else
        if header.status == 302 then
            print('WARNING: Document has moved, new location: '..header.location)
        elseif header.status == 404 then
            print('ERROR: Document not found!')
        elseif header.status == 200 then
            print(page)
        else
            print('ERROR: HTTP Error '..tostring(header.status))
        end
        
        --print(header.server)
        --print(header.location)
        --print(header.contenttype)
        --print(header.poweredby)
    end
end
-- Comment this out to test it
--HTTP.urlopen('http://localhost:8000/rq/test/', 'GET', PageReceived, {a='b b&c', c='d', e='f'})


-- #### EXAMPLE 2 - HTTP POST
local function PageReceived2(not_ok, header, page)
    if not_ok then
        print("ERROR: "..not_ok)
    else
        if header.status == 200 then
            --print(header.status)
            print(page) --this may or may not work
        else
            print("ERROR: HTTP Error "..header.status)
        end
    end
end

-- Comment one of these out to test it
--HTTP.urlopen('http://localhost:8000/rq/', 'POST', {a='b b', c='d&d', e='f'})
--HTTP.urlopen('http://localhost:8000/rq/', 'POST', nil, {a='b b', c='d&d', e='f'})
