mdns.register("wallsocket", {
    port = 219,
    service = 'iot-http',
    description = 'PowerSmart Connector'
})

function parseHTTP(msg)
    --Check if its HTTP
    if(string.match(msg, "HTTP/.%.")==nil) then
        return nil
    end
    
    local lines = {}
    local regex = "[^(\r\n)]+"
    local i = 1
    for line in string.gmatch(msg, regex) do
        lines[i] = line
        i=i+1
    end

    local req = {}
    local iter = string.gmatch(lines[1], "[^%s]+")
    req.method = iter()
    req.path = iter()
    req.http = iter()

    req.body = lines[#lines] --temp hack must fix
    
    for k, v in pairs( lines ) do
        print(v)
    end

    return req
end

function route(conn, req)
    local res = {
        status = "200 OK",
        contentType = "application/json",
        connection = "keep-alive"
    }
    if(req == nil) then
        res.status = "400 Bad Request"
        res.body = '"Bad Request"'
        respond(conn, res)
        print("Server: Error: Received invalid HTTP request")
        return
    end
    
    print("Server: Received "..req.method.." request to path: "..req.path)
    for k,v in pairs(routes) do
        if (k == req.path) then
            if(type(v[req.method]) == "function") then
                v[req.method](req, res)
                respond(conn, res)
                return
            end
        end
    end
    
    res.status = "404 Not Found"
    res.body = '"Not Found"'
    respond(conn, res)
    return
end

function respond(conn, res) 
   function toHTTPCase(str)
        local result = ""
        
        str = str:sub(1,1):upper()..str:sub(2)
        for token in string.gmatch(str,"(%u%l+)") do
            result = result..token.."-"
        end
        
        return result:sub(1,-2)
    end
    
    local msg = "HTTP/1.1 "..res.status.."\r\n"
    local body = ""
    if(res.body ~= nil) then
        body = res.body
        res.contentLength = res.body:len()
    else
        res.contentLength = 0
    end
    res.status = nil
    res.body = nil
    for k, v in pairs(res) do
        msg = msg..toHTTPCase(k)..": "..v.."\r\n"
    end
    msg = msg.."\n"..body
    print("Server: Sending Response:")
    print(msg)
    conn:send(msg)
    
end

routes = {
    ["/"] = {
        GET = function(req, res)
            res.body = '{\n'..
'   "name": "PowerSmart Connector",\n'..
'   "devices":[\n'..
'       {\n'..
'           "url":"/socket0",\n'..
'           "description":"Connector 1",\n'..
'           "type":"boolean"\n'..
'       },\n'..
'       {\n'..
'           "url":"/socket1",\n'..
'           "description":"Connector 2",\n'..
'           "type":"boolean"\n'..
'       }\n'..
'   ]\n'..
'}'
        end
    },

    ["/socket0"] = {
        GET = function(req, res)
            if(gpio.read(3)==0) then
                res.body = "true"
            else
                res.body = "false"
            end
        end,
        PUT = function(req, res)
            if req.body == "true" then
                gpio.mode(3, gpio.OUTPUT)
                gpio.write(3, 0)
            elseif req.body == "false" then
                gpio.mode(3, gpio.OUTPUT)
                gpio.write(3, 1)
            end
        end
    },
    
    ["/socket1"] = {
        GET = function(req, res)
            if(gpio.read(4)==0) then
                res.body = "true"
            else
                res.body = "false"
            end
        end,
        PUT = function(req,res)
            if req.body == "true" then
                gpio.mode(4, gpio.OUTPUT)
                gpio.write(4, 0)
            elseif req.body == "false" then
                gpio.mode(4, gpio.OUTPUT)
                gpio.write(4, 1)
            end
        end
    }
}
tcpServer=net.createServer(net.TCP) 
tcpServer:listen(219,function(conn) 
    conn:on("receive",function(conn, msg)
        route(conn, parseHTTP(msg))
    end) 
end)
