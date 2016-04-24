SSID = "HOME"
PASSWORD = "BE195A5D4B"
MAXATTEMPTS = 5 -- 15-second timeout
MAIN = "main.lua"

function connect()
	local attempts = 0
	wifi.sta.connect()

	if (not tmr.alarm(0, 3000, tmr.ALARM_AUTO, function()
        local status = wifi.sta.status()
		if wifi.sta.status() == 5 then --Got ip status
			tmr.unregister(0)
			print("Connection: Connected to "..SSID..", IP: " .. wifi.sta.getip())
			dofile(MAIN)
		elseif status == 2 then
            tmr.unregister(0)
            print("Connection: Error: Wrong password.")
        elseif status == 3 then
            tmr.unregister(0)
            print("Connection: Error: Network access point not found.")
        elseif status == 4 then
            tmr.unregister(0)
            print("Connection: Error: Connection failed.")
		elseif attempts > MAXATTEMPTS then
			tmr.unregister(0)
			print("Connection: Error: Timeout.")
			if wifi.sta.status() == 0 then print("Connection: Status: idling.") end
			if wifi.sta.status() == 1 then print("Connection: Status: connecting.") end
		end
        attempts = attempts + 1
	end
	)) then
        print("Timer: Error: Unable to start timer. Retrying.")
        connect(timeout)
    end
end

print("Connection: Connecting to Wi-Fi.")
wifi.setmode(wifi.STATION)
wifi.sta.config(SSID, PASSWORD)
connect()
