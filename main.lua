mdns.register("wallsocket", {
    port = 219,
    service = 'iot-http',
    description = 'PowerSmart Connector'
})

Buffer = dofile('buffer.lua')

HTTPParser = function()
    local state = 'start'
    local headerBuffer
    local bodyBuffer
    local req
    return function(msg, conn, callback)
        if (state == 'start') then
        	req = {}
        	headerBuffer = Buffer()
        	bodyBuffer = Buffer()
        	if (msg ~= nil) then
        		--Fill buffer
        		local headers, body
        		_,_,headers, body = msg:find("^(.*\r?\n)\r?\n(.*)$")
        		if (headers == nil) then
        			headers = msg
        		end
		        for line in headers:gmatch(".-\r?\n") do
		        	print("adding ["..line.."] to buffer.")
		            headerBuffer.push(line)
		        end
		        if(body ~= nil) then
		        	print("Adding body "..body)
		        	headerBuffer.push("") --Signal end of headers
			        bodyBuffer.push(body)
		        end
		        msg = nil
        	end
        	
            --Check if its HTTP
            if (headerBuffer.peek():match("HTTP/%d+%.%d+") ~= nil) then
                _, _, req.method, req.path, req.http = headerBuffer.next():find("^(.+)%s+(.+)%s+(.+)\r?\n$")
                state = 'header'
            else
            	return nil
            end
                 
        end
        if(state == 'header') then
        	if (msg ~= nil) then
        		--Fill buffer
        		local headers, body
        		_,_,headers, body = msg:find("^(.*\r?\n)\r?\n(.*)$")
        		if (headers == nil) then
        			headers = msg
        		end
		        for line in headers:gmatch(".-\r?\n") do
		        	print("Adding ["..line.."] to buffer.")
		            headerBuffer.push(line)
		        end
		        if (body ~= nil) then
		        	print("Adding body "..body)
		        	headerBuffer.push("") --Signal end of headers
			        bodyBuffer.push(body)
		        end
		        msg = nil --msg consumed
        	end
        	
        	local headers = function ()
        		if (headerBuffer.peek() == nil) then
        			return nil
        		end
        		if (headerBuffer.peek():match("^\r?\n$") or headerBuffer.peek() == "") then --end of headers
        			state = 'body'
        			return nil
        		end
                return headerBuffer.next()
            end
        	
        	if (req.headers == nil) then
        		req.headers = {}
        	end
            for header in headers do
                local key
                local val
                --print("Analizing header: "..header)
                _,_,key,val = header:find("(.-)%s*:%s*(.+)\r?\n$")
                --print("Found header: "..key..":"..val)
                if(key ~= nil and val ~= nil) then --discard bad headers
                	req.headers[key:lower()] = val
                end
            end
        end
        if(state == 'body') then
        	if(msg ~= nil) then
        		bodyBuffer.push(msg)
        		msg = nil --msg consumed
        	end
        	
        	if (req.body == nil) then
            	req.body = ''
            end
            
            local body = function()
                return bodyBuffer.next()
            end
            
            for chunk in body do
            	req.body = req.body..chunk
            end
            
            --FIX: Send error "411:Needs length" if no content-length
            if (req.headers['content-length'] == nil) then
            	state = 'start'
            	req.body = bodyBuffer.next()
            	
            	return callback(conn, req)
            end
        	if (req.headers['content-length'] ~= nil and tonumber(req.headers['content-length']) <= req.body:len()) then
            	--body ends when content-length == req.body:len()
        		state = 'start'
        		
        		return callback(conn, req)
        	end
        end
    end
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
    
    if (req.headers['content-length'] == nil) then
    	res.status = "411 Length Required"
        res.body = '"Length Required"'
        respond(conn, res)
        print("Server: Error: Needs content length")
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
            else
                res.status = "400 Bad Request"
                res.body = '"Request should be of type boolean"'
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
            else
                res.status = "404 Bad Request"
                res.body = '"Request should be of type boolean"'
            end
        end
    }
}

tcpServer=net.createServer(net.TCP) 
tcpServer:listen(219,function(conn)
    print("Connected to something")
    local parseHTML = HTTPParser()
    conn:on("receive",function(conn, msg)
        print("Received data: "..msg)
        parseHTML(msg, conn, route)
    end) 
end)
