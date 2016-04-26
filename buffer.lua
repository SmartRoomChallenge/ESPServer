return function()
	local list = {}
	local first = 0
	local last = 0
	
	return {
		push = function(data)
			list[last] = data
			last = last + 1
		end,
		peek =  function()
			return list[first]
		end,
		next = function()
			if(first == last) then
				return nil
			end
			local val = list[first]
			list[first] = nil	
			first = first + 1
			return val
		end
	}
end
