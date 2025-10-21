local passes, fails, undefined = 0, 0, 0
local running = 0

local function getGlobal(path)
	local value = getfenv(0)

	while value ~= nil and path ~= "" do
		local name, nextValue = string.match(path, "^([^.]+)%.?(.*)$")
		value = value[name]
		path = nextValue
	end

	return value
end

local function test(name, aliases, callback)
	running += 1

	task.spawn(function()
		if not callback then
			print("⏺️ " .. name)
		elseif not getGlobal(name) then
			fails += 1
			warn("⛔ " .. name)
		else
			local success, message = pcall(callback)
	
			if success then
				passes += 1
				print("✅ " .. name .. (message and " • " .. message or ""))
			else
				fails += 1
				warn("⛔ " .. name .. " failed: " .. message)
			end
		end
	
		local undefinedAliases = {}
	
		for _, alias in ipairs(aliases) do
			if getGlobal(alias) == nil then
				table.insert(undefinedAliases, alias)
			end
		end
	
		if #undefinedAliases > 0 then
			undefined += 1
			warn("⚠️ " .. table.concat(undefinedAliases, ", "))
		end

		running -= 1
	end)
end

-- Header and summary

print("\n")

print("openUNC Environment Check")
print("✅ - Pass, ⛔ - Fail, ⏺️ - No test, ⚠️ - Missing aliases\n")

task.defer(function()
	repeat task.wait() until running == 0

	local rate = math.round(passes / (passes + fails) * 100)
	local outOf = passes .. " out of " .. (passes + fails)

	print("\n")

	print("openUNC Summary")
	print("✅ Tested with a " .. rate .. "% success rate (" .. outOf .. ")")
	print("⛔ " .. fails .. " tests failed")
	print("⚠️ " .. undefined .. " globals are missing aliases")
end)

-- Cache

test("cache.invalidate", {}, function()
	local container = Instance.new("Folder")
	local part = Instance.new("Part", container)
	cache.invalidate(container:FindFirstChild("Part"))
	assert(part ~= container:FindFirstChild("Part"), "Reference `part` could not be invalidated")
end)

test("cache.iscached", {}, function()
	local part = Instance.new("Part")
	assert(cache.iscached(part), "Part should be cached")
	cache.invalidate(part)
	assert(not cache.iscached(part), "Part should not be cached")
end)

test("cache.replace", {}, function()
	local part = Instance.new("Part")
	local fire = Instance.new("Fire")
	cache.replace(part, fire)
	assert(part ~= fire, "Part was not replaced with Fire")
end)

test("cloneref", {}, function()
	local part = Instance.new("Part")
	local clone = cloneref(part)
	assert(part ~= clone, "Clone should not be equal to original")
	clone.Name = "Test"
	assert(part.Name == "Test", "Clone should have updated the original")
end)

test("compareinstances", {}, function()
	local part = Instance.new("Part")
	local clone = cloneref(part)
	assert(part ~= clone, "Clone should not be equal to original")
	assert(compareinstances(part, clone), "Clone should be equal to original when using compareinstances()")
end)

-- Closures

local function shallowEqual(t1, t2)
	if t1 == t2 then
		return true
	end

	local UNIQUE_TYPES = {
		["function"] = true,
		["table"] = true,
		["userdata"] = true,
		["thread"] = true,
	}

	for k, v in pairs(t1) do
		if UNIQUE_TYPES[type(v)] then
			if type(t2[k]) ~= type(v) then
				return false
			end
		elseif t2[k] ~= v then
			return false
		end
	end

	for k, v in pairs(t2) do
		if UNIQUE_TYPES[type(v)] then
			if type(t2[k]) ~= type(v) then
				return false
			end
		elseif t1[k] ~= v then
			return false
		end
	end

	return true
end

test("checkcaller", {}, function()
	assert(checkcaller(), "Main scope should return true")
end)

test("clonefunction", {}, function()
	local function test()
		return "success"
	end
	local copy = clonefunction(test)
	assert(test() == copy(), "The clone should return the same value as the original")
	assert(test ~= copy, "The clone should not be equal to the original")
end)

test("getcallingscript", {}, function()
	local cameraTable=filtergc("table",{
		Keys={"Update","ShouldUseVehicleCamera"},
	},true)

	assert(typeof(cameraTable)=="table","cameraTable is not a table!")
	local update=rawget(cameraTable,"Update")
	assert(typeof(update)=="function","Update value from cameratable is not a function")
	
	local playerscripts=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerScripts") or nil
	local cameramodule=playerscripts and playerscripts:FindFirstChild("PlayerModule") and playerscripts:FindFirstChild("PlayerModule"):FindFirstChild("CameraModule") or nil

	playerscripts=nil
	assert(cameramodule,"Unable to find CameraModule (you should join empty baseplate game because this game has its own custom cameramodule)")

	local callingscript
	local org;org=hookfunction(update,newlclosure(function(...)
		if not callingscript then
			callingscript=getcallingscript()
		end
		return org(...)
	end))
	
	local clock=os.clock()
	repeat task.wait(1) until callingscript or os.clock()-clock>20
	restorefunction(update)

	assert(cameramodule==callingscript,"Calling script is not CameraModule")
	assert(typeof(callingscript)=="Instance","Calling script is not a Instance")
	assert(typeof(cameramodule)=="Instance","Camera module is not a Instance")
	assert(callingscript:IsA("ModuleScript"),"Calling script is not a ModuleScript")
	assert(cameramodule:IsA("ModuleScript"),"Camera module is not a ModuleScript")

	cameramodule,callingscript,update,cameraTable=nil,nil,nil,nil
end)

test("getscriptclosure", {"getscriptfunction"}, function()
	local module = game:GetService("CoreGui").RobloxGui.Modules.Common.AvatarChatConstants
	local constants = getrenv().require(module)
	local generated = getscriptclosure(module)()
	assert(constants ~= generated, "Generated module should not match the original")
	assert(shallowEqual(constants, generated), "Generated constant table should be shallow equal to the original")
end)

test("hookfunction", {"replaceclosure"}, function()
	local function test()
		return true
	end
	local ref = hookfunction(test, function()
		return false
	end)
	assert(test() == false, "Function should return false")
	assert(ref() == true, "Original function should return true")
	assert(test ~= ref, "Original function should not be same as the reference")
end)

test("restorefunction",{},function()
	local function dummy_func()
		return "I am not hooked!"
	end

	assert(dummy_func()=="I am not hooked!", `Function should return "I am not hooked!"`)
	
	hookfunction(dummy_func,function() return "I am hooked!" end)
	assert(dummy_func()=="I am hooked!", `Function should return "I am hooked!"`)
	
	restorefunction(dummy_func)
	assert(dummy_func()=="I am not hooked!", `Function should return "I am not hooked!"`)
end)

test("getfunctionhash",{},function()
	local function is_sha384_hex(hash)
		return #hash == 96 and hash:match("^[0-9a-fA-F]+$") ~= nil
	end

	local dummy_function_0 = function() end
	local dummy_function_1 = function(...) end
	local dummy_function_2 = function() end
	local dummy_function_3 = function() return "Constant" end
	local dummy_function_4 = function() return "Constant2" end

	assert(is_sha384_hex(getfunctionhash(dummy_function_0))==true,"Function didn't return sha384 hex")
	assert(getfunctionhash(dummy_function_0) ~= getfunctionhash(dummy_function_1),"Function 0 hash shouldn't match function 1 hash")
	assert(getfunctionhash(dummy_function_0) == getfunctionhash(dummy_function_2),"Function 0 hash should match function 2 hash")
	assert(getfunctionhash(dummy_function_3) ~= getfunctionhash(dummy_function_4),"Function 3 hash shouldn't match function 4 hash")
end)

test("iscclosure", {}, function()
	assert(iscclosure(print) == true, "Function 'print' should be a C closure")
	assert(iscclosure(function() end) == false, "Executor function should not be a C closure")
end)

test("islclosure", {}, function()
	assert(islclosure(print) == false, "Function 'print' should not be a Lua closure")
	assert(islclosure(function() end) == true, "Executor function should be a Lua closure")
end)

test("isexecutorclosure", {"checkclosure", "isourclosure"}, function()
	assert(isexecutorclosure(isexecutorclosure) == true, "Did not return true for an executor global")
	assert(isexecutorclosure(newcclosure(function() end)) == true, "Did not return true for an executor C closure")
	assert(isexecutorclosure(function() end) == true, "Did not return true for an executor Luau closure")
	assert(isexecutorclosure(print) == false, "Did not return false for a Roblox global")
end)

test("loadstring", {}, function()
	local animate = game:GetService("Players").LocalPlayer.Character.Animate
	local bytecode = getscriptbytecode(animate)
	local func = loadstring(bytecode)
	assert(type(func) ~= "function", "Luau bytecode should not be loadable!")
	assert(assert(loadstring("return ... + 1"))(1) == 2, "Failed to do simple math")
	assert(type(select(2, loadstring("f"))) == "string", "Loadstring did not return anything for a compiler error")
end)

test("newcclosure", {}, function()
	local function test()
		return true
	end
	local testC = newcclosure(test)
	assert(test() == testC(), "New C closure should return the same value as the original")
	assert(test ~= testC, "New C closure should not be same as the original")
	assert(iscclosure(testC), "New C closure should be a C closure")
end)

test("newlclosure",{},function()
	local function test()
		return true
	end
	local testL = newlclosure(test)
	assert(test() == testL(), "New L closure should return the same value as the original")
	assert(test ~= testL, "New L closure should not be same as the original")
	assert(islclosure(testL), "New L closure should be a L closure")
end)

-- Console

test("rconsoleclear", {"consoleclear"})

test("rconsolecreate", {"consolecreate"})

test("rconsoledestroy", {"consoledestroy"})

test("rconsoleinput", {"consoleinput"})

test("rconsoleprint", {"consoleprint"})

test("rconsolesettitle", {"rconsolename", "consolesettitle"})

-- Crypt

test("base64encode", {"crypt.base64.encode", "crypt.base64_encode", "base64.encode", "base64_encode","crypt.base64encode"}, function()
	assert(base64encode("test") == "dGVzdA==", "Base64 encoding failed")
end)

test("base64decode", {"crypt.base64.decode", "crypt.base64_decode", "base64.decode", "base64_decode","crypt.base64decode"}, function()
	assert(base64decode("dGVzdA==") == "test", "Base64 decoding failed")
end)

test("crypt.encrypt", {}, function()
	local key = crypt.generatekey()
	local encrypted, iv = crypt.encrypt("test", key, nil, "CBC")
	assert(iv, "crypt.encrypt should return an IV")
	local decrypted = crypt.decrypt(encrypted, key, iv, "CBC")
	assert(decrypted == "test", "Failed to decrypt raw string from encrypted data")
end)

test("crypt.decrypt", {}, function()
	local key, iv = crypt.generatekey(), crypt.generatekey()
	local encrypted = crypt.encrypt("test", key, iv, "CBC")
	local decrypted = crypt.decrypt(encrypted, key, iv, "CBC")
	assert(decrypted == "test", "Failed to decrypt raw string from encrypted data")
end)

test("crypt.generatebytes", {}, function()
	local size = math.random(10, 100)
	local bytes = crypt.generatebytes(size)
	assert(#crypt.base64decode(bytes) == size, "The decoded result should be " .. size .. " bytes long (got " .. #crypt.base64decode(bytes) .. " decoded, " .. #bytes .. " raw)")
end)

test("crypt.generatekey", {}, function()
	local key = crypt.generatekey()
	assert(#crypt.base64decode(key) == 32, "Generated key should be 32 bytes long when decoded")
end)

test("crypt.hash", {}, function()
	local algorithms = {'sha1', 'sha384', 'sha512', 'md5', 'sha256', 'sha3-224', 'sha3-256', 'sha3-512'}
	for _, algorithm in ipairs(algorithms) do
		local hash = crypt.hash("test", algorithm)
		assert(hash, "crypt.hash on algorithm '" .. algorithm .. "' should return a hash")
	end
end)

--- Debug

test("debug.getconstant", {}, function()
	local function test()
		print("Hello, world!")
	end
	assert(debug.getconstant(test, 1) == "print", "First constant must be print")
	assert(debug.getconstant(test, 2) == nil, "Second constant must be nil")
	assert(debug.getconstant(test, 3) == "Hello, world!", "Third constant must be 'Hello, world!'")
end)

test("debug.getconstants", {}, function()
	local function test()
		local num = 5000 .. 50000
		print("Hello, world!", num, warn)
	end
	local constants = debug.getconstants(test)
	assert(constants[1] == 50000, "First constant must be 50000")
	assert(constants[2] == "print", "Second constant must be print")
	assert(constants[3] == nil, "Third constant must be nil")
	assert(constants[4] == "Hello, world!", "Fourth constant must be 'Hello, world!'")
	assert(constants[5] == "warn", "Fifth constant must be warn")
end)

test("debug.getinfo", {}, function()
	local types = {
		source = "string",
		short_src = "string",
		func = "function",
		what = "string",
		currentline = "number",
		name = "string",
		nups = "number",
		numparams = "number",
		is_vararg = "number",
	}
	local function test(...)
		print(...)
	end
	local info = debug.getinfo(test)
	for k, v in pairs(types) do
		assert(info[k] ~= nil, "Did not return a table with a '" .. k .. "' field")
		assert(type(info[k]) == v, "Did not return a table with " .. k .. " as a " .. v .. " (got " .. type(info[k]) .. ")")
	end
end)

test("debug.getproto", {}, function()
	local function test()
		local function proto()
			return true
		end
	end
	local proto = debug.getproto(test, 1, true)[1]
	local realproto = debug.getproto(test, 1)
	assert(proto, "Failed to get the inner function")
	assert(proto() == true, "The inner function did not return anything")
	if not realproto() then
		return "Proto return values are disabled on this executor"
	end
end)

test("debug.getprotos", {}, function()
	local function test()
		local function _1()
			return true
		end
		local function _2()
			return true
		end
		local function _3()
			return true
		end
	end
	for i in ipairs(debug.getprotos(test)) do
		local proto = debug.getproto(test, i, true)[1]
		local realproto = debug.getproto(test, i)
		assert(proto(), "Failed to get inner function " .. i)
		if not realproto() then
			return "Proto return values are disabled on this executor"
		end
	end
end)

test("debug.getstack", {}, function()
	local _ = "a" .. "b"
	assert(debug.getstack(1, 1) == "ab", "The first item in the stack should be 'ab'")
	assert(debug.getstack(1)[1] == "ab", "The first item in the stack table should be 'ab'")
end)

test("debug.getupvalue", {}, function()
	local upvalue = function() end
	local function test()
		print(upvalue)
	end
	assert(debug.getupvalue(test, 1) == upvalue, "Unexpected value returned from debug.getupvalue")
end)

test("debug.getupvalues", {}, function()
	local upvalue = function() end
	local function test()
		print(upvalue)
	end
	local upvalues = debug.getupvalues(test)
	assert(upvalues[1] == upvalue, "Unexpected value returned from debug.getupvalues")
end)

test("debug.setconstant", {}, function()
	local function test()
		return "fail"
	end
	debug.setconstant(test, 1, "success")
	assert(test() == "success", "debug.setconstant did not set the first constant")
end)

test("debug.setstack", {}, function()
	local function test()
		return "fail", debug.setstack(1, 1, "success")
	end
	assert(test() == "success", "debug.setstack did not set the first stack item")
end)

test("debug.setupvalue", {}, function()
	local function upvalue()
		return "fail"
	end
	local function test()
		return upvalue()
	end
	debug.setupvalue(test, 1, function()
		return "success"
	end)
	assert(test() == "success", "debug.setupvalue did not set the first upvalue")
end)

-- Filesystem

if isfolder and makefolder and delfolder then
	if isfolder(".tests") then
		delfolder(".tests")
	end
	makefolder(".tests")
end

test("readfile", {}, function()
	writefile(".tests/readfile.txt", "success")
	assert(readfile(".tests/readfile.txt") == "success", "Did not return the contents of the file")
end)

test("listfiles", {}, function()
	makefolder(".tests/listfiles")
	writefile(".tests/listfiles/test_1.txt", "success")
	writefile(".tests/listfiles/test_2.txt", "success")
	local files = listfiles(".tests/listfiles")
	assert(#files == 2, "Did not return the correct number of files")
	assert(isfile(files[1]), "Did not return a file path")
	assert(readfile(files[1]) == "success", "Did not return the correct files")
	makefolder(".tests/listfiles_2")
	makefolder(".tests/listfiles_2/test_1")
	makefolder(".tests/listfiles_2/test_2")
	local folders = listfiles(".tests/listfiles_2")
	assert(#folders == 2, "Did not return the correct number of folders")
	assert(isfolder(folders[1]), "Did not return a folder path")
end)

test("writefile", {}, function()
	writefile(".tests/writefile.txt", "success")
	assert(readfile(".tests/writefile.txt") == "success", "Did not write the file")
	local requiresFileExt = pcall(function()
		writefile(".tests/writefile", "success")
		assert(isfile(".tests/writefile.txt"))
	end)
	if not requiresFileExt then
		return "This executor requires a file extension in writefile"
	end
end)

test("makefolder", {}, function()
	makefolder(".tests/makefolder")
	assert(isfolder(".tests/makefolder"), "Did not create the folder")
end)

test("appendfile", {}, function()
	writefile(".tests/appendfile.txt", "su")
	appendfile(".tests/appendfile.txt", "cce")
	appendfile(".tests/appendfile.txt", "ss")
	assert(readfile(".tests/appendfile.txt") == "success", "Did not append the file")
end)

test("isfile", {}, function()
	writefile(".tests/isfile.txt", "success")
	assert(isfile(".tests/isfile.txt") == true, "Did not return true for a file")
	assert(isfile(".tests") == false, "Did not return false for a folder")
	assert(isfile(".tests/doesnotexist.exe") == false, "Did not return false for a nonexistent path (got " .. tostring(isfile(".tests/doesnotexist.exe")) .. ")")
end)

test("isfolder", {}, function()
	assert(isfolder(".tests") == true, "Did not return false for a folder")
	assert(isfolder(".tests/doesnotexist.exe") == false, "Did not return false for a nonexistent path (got " .. tostring(isfolder(".tests/doesnotexist.exe")) .. ")")
end)

test("delfolder", {}, function()
	makefolder(".tests/delfolder")
	delfolder(".tests/delfolder")
	assert(isfolder(".tests/delfolder") == false, "Failed to delete folder (isfolder = " .. tostring(isfolder(".tests/delfolder")) .. ")")
end)

test("delfile", {}, function()
	writefile(".tests/delfile.txt", "Hello, world!")
	delfile(".tests/delfile.txt")
	assert(isfile(".tests/delfile.txt") == false, "Failed to delete file (isfile = " .. tostring(isfile(".tests/delfile.txt")) .. ")")
end)

test("loadfile", {}, function()
	writefile(".tests/loadfile.txt", "return ... + 1")
	assert(assert(loadfile(".tests/loadfile.txt"))(1) == 2, "Failed to load a file with arguments")
	writefile(".tests/loadfile.txt", "f")
	local callback, err = loadfile(".tests/loadfile.txt")
	assert(err and not callback, "Did not return an error message for a compiler error")
end)

--test("dofile", {}) useless no one needs this and we already have loadfile()

-- Input

test("isrbxactive", {"isgameactive"}, function()
	assert(type(isrbxactive()) == "boolean", "Did not return a boolean value")
end)

test("mouse1click", {})

test("mouse1press", {})

test("mouse1release", {})

test("mouse2click", {})

test("mouse2press", {})

test("mouse2release", {})

test("mousemoveabs", {})

test("mousemoverel", {})

test("mousescroll", {})

-- Instances

test("fireclickdetector", {}, function()
	local detector = Instance.new("ClickDetector")
	local connection
	local hasFired=false

	connection=detector.MouseHoverEnter:Connect(function()
		hasFired=true
		detector:Destroy()
		connection:Disconnect()
		connection,detector=nil,nil
	end)

	fireclickdetector(detector, 50, "MouseHoverEnter")
	assert(hasFired,"Click detector didnt get fired!")
end)

test("fireproximityprompt",{},function()
	local part=Instance.new("Part")
	local prompt=Instance.new("ProximityPrompt")
	local connection
	local hasFired=false

	prompt.Parent=part
	part.Parent=game:GetService("CoreGui")

	connection=prompt.Triggered:Connect(function()
		hasFired=true
		prompt:Destroy()
		part:Destroy()
		connection:Disconnect()
		connection,prompt,part=nil,nil,nil
	end)

	fireproximityprompt(prompt)
	assert(hasFired,"ProximityPrompt didn't get fired!")
end)

test("firetouchinterest",{},function()
	local lplr = game:GetService("Players").LocalPlayer
	local player_head = lplr.Character and lplr.Character:FindFirstChild("Head") or nil
	local connection,connection2

	lplr=nil
	assert(player_head,"You need to have a player character and head to test this function! (try running fUNC again after your character spawned correctly)")

	local touchFired=false
	local touchEndedFired=false
	local dummy_part = Instance.new("Part")
	dummy_part.CFrame = CFrame.new(0, -200, 0)
	dummy_part.Anchored = true
	dummy_part.Parent = workspace

	connection=dummy_part.Touched:Connect(function(part)
		if part~=player_head then return end
		touchFired=true
	end)

	connection2=dummy_part.TouchEnded:Connect(function(part)
		if part~=player_head then return end
		touchEndedFired=true
	end)

	firetouchinterest(player_head, dummy_part, 0)
	firetouchinterest(player_head, dummy_part, 1)
	task.wait(1)

	dummy_part:Destroy()
	connection:Disconnect()
	connection2:Disconnect()
	dummy_part,connection,connection2,player_head=nil,nil,nil,nil

	assert(touchFired,"Touched didn't get fired!")
	assert(touchEndedFired,"TouchEnded didn't get fired!")
end)

test("getcallbackvalue", {}, function()
	local bindable = Instance.new("BindableFunction")
	local function test()
	end
	bindable.OnInvoke = test
	assert(getcallbackvalue(bindable, "OnInvoke") == test, "Did not return the correct value")
end)

test("firesignal",{},function()
	local bind=Instance.new("BindableEvent")
	local fireArg

	bind.Event:Connect(function(args)
		fireArg=args
	end)

	firesignal(bind.Event,"hi")
	assert(fireArg=="hi",`fireArg should be set to "hi" immediately regardles of SignalBehavior`)
end)

test("cansignalreplicate",{"canreplicatesignal"},function()
	assert(cansignalreplicate(game:GetService("Players").LocalPlayer.Kill),"Kill should be possible to replicate.")
end)

test("getrendersteppedlist",{})

test("isnetworkowner",{},function()
	assert(isnetworkowner(game:GetService("Players").LocalPlayer.Character.HumanoidRootPart),"HumanoidRootPart should be network owner.")
end)

test("getconnections", {}, function()
	local types = {
		Enabled = "boolean",
		ForeignState = "boolean",
		LuaConnection = "boolean",
		Function = "function",
		Thread = "thread",
		Fire = "function",
		Defer = "function",
		Disconnect = "function",
		Disable = "function",
		Enable = "function",
	}
	local bindable = Instance.new("BindableEvent")
	bindable.Event:Connect(function() end)
	local connection = getconnections(bindable.Event)[1]
	for k, v in pairs(types) do
		assert(connection[k] ~= nil, "Did not return a table with a '" .. k .. "' field")
		assert(type(connection[k]) == v, "Did not return a table with " .. k .. " as a " .. v .. " (got " .. type(connection[k]) .. ")")
	end
end)

test("getcustomasset", {}, function()
	writefile(".tests/getcustomasset.txt", "success")
	local contentId = getcustomasset(".tests/getcustomasset.txt")
	assert(type(contentId) == "string", "Did not return a string")
	assert(#contentId > 0, "Returned an empty string")
	assert(string.match(contentId, "rbxasset://") == "rbxasset://", "Did not return an rbxasset url")
end)

test("gethiddenproperty", {}, function()
	local fire = Instance.new("Fire")
	local property, isHidden = gethiddenproperty(fire, "size_xml")
	assert(property == 5, "Did not return the correct value")
	assert(isHidden == true, "Did not return whether the property was hidden")
end)

test("sethiddenproperty", {}, function()
	local fire = Instance.new("Fire")
	local hidden = sethiddenproperty(fire, "size_xml", 10)
	assert(hidden, "Did not return true for the hidden property")
	assert(gethiddenproperty(fire, "size_xml") == 10, "Did not set the hidden property")
end)

test("gethui", {}, function()
	assert(typeof(gethui()) == "Instance", "Did not return an Instance")
end)

test("getinstances", {}, function()
	local part=Instance.new("Part")
	assert(getinstances()[1]:IsA("Instance"), "The first value is not an Instance")
	assert(table.find(getinstances(),part),"Nil part not found in getinstances")
	part:Destroy()
	part=nil
end)

test("getnilinstances", {}, function()
	local part=Instance.new("Part")
	assert(getnilinstances()[1]:IsA("Instance"), "The first value is not an Instance")
	assert(getnilinstances()[1].Parent == nil, "The first value is not parented to nil")
	assert(table.find(getnilinstances(),part),"Nil part not found in getnilinstances")
	part:Destroy()
	part=nil
end)

test("isscriptable", {}, function()
	local fire = Instance.new("Fire")
	assert(isscriptable(fire, "size_xml") == false, "Did not return false for a non-scriptable property (size_xml)")
	assert(isscriptable(fire, "Size") == true, "Did not return true for a scriptable property (Size)")
end)

test("setscriptable", {}, function()
	local fire = Instance.new("Fire")
	local wasScriptable = setscriptable(fire, "size_xml", true)
	assert(wasScriptable == false, "Did not return false for a non-scriptable property (size_xml)")
	assert(isscriptable(fire, "size_xml") == true, "Did not set the scriptable property")
	fire = Instance.new("Fire")
	assert(isscriptable(fire, "size_xml") == false, "⚠️⚠️ setscriptable persists between unique instances ⚠️⚠️")
end)

test("setrbxclipboard", {})

-- Metatable

test("getrawmetatable", {}, function()
	local metatable = { __metatable = "Locked!" }
	local object = setmetatable({}, metatable)
	assert(getrawmetatable(object) == metatable, "Did not return the metatable")
end)

test("hookmetamethod", {}, function()
	local object = setmetatable({}, { __index = newcclosure(function() return false end), __metatable = "Locked!" })
	local ref = hookmetamethod(object, "__index", function() return true end)
	assert(object.test == true, "Failed to hook a metamethod and change the return value")
	assert(ref() == false, "Did not return the original function")
end)

test("getnamecallmethod", {}, function()
	local method
	local ref
	ref = hookmetamethod(game, "__namecall", function(...)
		if not method then
			method = getnamecallmethod()
		end
		return ref(...)
	end)
	game:GetService("Lighting")
	assert(method == "GetService", "Did not get the correct method (GetService)")
end)

test("isreadonly", {}, function()
	local object = {}
	table.freeze(object)
	assert(isreadonly(object), "Did not return true for a read-only table")
end)

test("setrawmetatable", {}, function()
	local object = setmetatable({}, { __index = function() return false end, __metatable = "Locked!" })
	local objectReturned = setrawmetatable(object, { __index = function() return true end })
	assert(object, "Did not return the original object")
	assert(object.test == true, "Failed to change the metatable")
	if objectReturned then
		return objectReturned == object and "Returned the original object" or "Did not return the original object"
	end
end)

test("setreadonly", {}, function()
	local object = { success = false }
	table.freeze(object)
	setreadonly(object, false)
	object.success = true
	assert(object.success, "Did not allow the table to be modified")
end)

-- Miscellaneous

test("identifyexecutor", {"getexecutorname"}, function()
	local name, version = identifyexecutor()
	assert(type(name) == "string", "Did not return a string for the name")
	return type(version) == "string" and "Returns version as a string" or "Does not return version"
end)

test("lz4compress", {}, function()
	local raw = "Hello, world!"
	local compressed = lz4compress(raw)
	assert(type(compressed) == "string", "Compression did not return a string")
	assert(lz4decompress(compressed, #raw) == raw, "Decompression did not return the original string")
end)

test("lz4decompress", {}, function()
	local raw = "Hello, world!"
	local compressed = lz4compress(raw)
	assert(type(compressed) == "string", "Compression did not return a string")
	assert(lz4decompress(compressed, #raw) == raw, "Decompression did not return the original string")
end)

test("messagebox", {})

test("queue_on_teleport", {"queueonteleport"})
test("clear_teleport_queue",{})

test("request", {"http.request", "http_request"}, function()
	local response = request({
		Url = "https://httpbin.org/user-agent",
		Method = "GET",
	})
	assert(type(response) == "table", "Response must be a table")
	assert(response.StatusCode == 200, "Did not return a 200 status code")
	local data = game:GetService("HttpService"):JSONDecode(response.Body)
	assert(type(data) == "table" and type(data["user-agent"]) == "string", "Did not return a table with a user-agent key")
	return "User-Agent: " .. data["user-agent"]
end)

test("setclipboard", {"toclipboard"})

test("setfpscap", {}, function()
	local renderStepped = game:GetService("RunService").RenderStepped
	local function step()
		renderStepped:Wait()
		local sum = 0
		for _ = 1, 5 do
			sum += 1 / renderStepped:Wait()
		end
		return math.round(sum / 5)
	end
	setfpscap(60)
	local step60 = step()
	setfpscap(0)
	local step0 = step()
	return step60 .. "fps @60 • " .. step0 .. "fps @0"
end)

-- Scripts

test("getgc", {}, function()
	local gc = getgc()

	assert(typeof(gc) == "table", "Did not return a table")
	assert(#gc > 0, "Did not return a table with any values")

	local dummy_table={}
	local function dummy_function()end
	local dummy_proxy=newproxy(false)
	
	local foundTrue=0
	local foundFalse=0

	for i,v in getgc(true) do
		if v==dummy_table or v==dummy_function or v==dummy_proxy then
			foundTrue+=1
		end
	end

	for i,v in getgc(false) do
		if v==dummy_table or v==dummy_function or v==dummy_proxy then
			foundFalse+=1
		end
	end

	assert(foundFalse==1,"Failed to find dummyfunction, getgc(false) should only have functions and no proxies or tables.")
	assert(foundTrue==3, "Failed to find dummytable and dummyfunction and dummyproxy in getgc(true)")
end)

test("getreg", {}, function()
	local loop_thread = task.spawn(function()
		while task.wait(1) do
			print("I am still running...")
		end
	end)

	for _, value in getreg() do
		if value ~= loop_thread then continue end

		coroutine.close(value)
		assert(coroutine.status(value)=="dead","value thread status should be dead")
		break
	end

	assert(coroutine.status(loop_thread)=="dead","Loop thread status should be dead")
end)

test("filtergc",{},function()
	local function filtergcExample() return "hello from filtergc" end
	local exampleTable={["filtergcExample"]="cool"}

	local funcs={
		example=filtergc("function",{
			Name="filtergcExample",
			IgnoreExecutor=false,
		},true),
		cameraFunc=filtergc("function",{
			Name="ActivateCameraController",
			IgnoreExecutor=true,
		},true)
	}

	local tables={
		example=filtergc("table",{
			Keys={"filtergcExample"},
			Values={"cool"},
		},true),
		cameraTable=filtergc("table",{
			Keys={"activeCameraController"},
		},true)
	}

	assert(typeof(funcs.example)=="function","Example value from filtergc is not a function!")
	assert(typeof(funcs.cameraFunc)=="function","Camera value from filtergc is not a function!")

	assert(isexecutorclosure(funcs.example),"Example function from filtergc should be executor closure.")
	assert(isexecutorclosure(funcs.cameraFunc)==false, "Camera function should not be executor closure.")
	assert(funcs.example()==filtergcExample(), "Example function from filtergc didn't return same thing as the local function.")
	assert(funcs.example==filtergcExample,"Example function from filtergc isn't the same as the local function")

	assert(typeof(tables.example)=="table","Example value from filtergc is not a table!")
	assert(tables.example==exampleTable,"Example table from filtergc doesn't match local exampleTable")
	assert(rawget(tables.example,"filtergcExample")=="cool","Example table from filtergc - filtergcExample key is not equal to cool string.")

	assert(typeof(tables.cameraTable)=="table","Camera value from filtergc is not a table!")
	local rawMeta=getrawmetatable(tables.cameraTable)
	assert(typeof(rawget(rawMeta,"new"))=="function","new value is not a function from camera metatable.")
	assert(isexecutorclosure(rawget(rawMeta,"new"))==false,"new function from camera metatable should not be executor closure.")
end)

test("getgenv", {}, function()
	getgenv().__TEST_GLOBAL = true
	assert(__TEST_GLOBAL, "Failed to set a global variable")
	getgenv().__TEST_GLOBAL = nil
end)

test("getloadedmodules", {}, function()
	--[[local loaded=Instance.new("ModuleScript")
	pcall(require,loaded)]]

	local modules = getloadedmodules()
	assert(type(modules) == "table", "Did not return a table")
	assert(#modules > 0, "Did not return a table with any values")
	assert(typeof(modules[1]) == "Instance", "First value is not an Instance")
	assert(modules[1]:IsA("ModuleScript"), "First value is not a ModuleScript")
	--assert(table.find(modules,loaded),"Loaded module not found in getloadedmodules")
end)

test("getrenv", {}, function()
	assert(_G ~= getrenv()._G, "The variable _G in the executor is identical to _G in the game")
end)

test("getrunningscripts", {}, function()
	local scripts = getrunningscripts()
	assert(type(scripts) == "table", "Did not return a table")
	assert(#scripts > 0, "Did not return a table with any values")
	assert(typeof(scripts[1]) == "Instance", "First value is not an Instance")
	assert(scripts[1]:IsA("ModuleScript") or scripts[1]:IsA("LocalScript"), "First value is not a ModuleScript or LocalScript")
end)

test("getscriptbytecode", {"dumpstring"}, function()
	local animate = game:GetService("Players").LocalPlayer.Character.Animate
	local bytecode = getscriptbytecode(animate)
	assert(type(bytecode) == "string", "Did not return a string for Character.Animate (a " .. animate.ClassName .. ")")
end)

test("getscripthash", {}, function()
	local animate = game:GetService("Players").LocalPlayer.Character.Animate:Clone()
	local hash = getscripthash(animate)
	local source = animate.Source
	animate.Source = "print('Hello, world!')"
	task.defer(function()
		animate.Source = source
	end)
	local newHash = getscripthash(animate)
	assert(hash ~= newHash, "Did not return a different hash for a modified script")
	assert(newHash == getscripthash(animate), "Did not return the same hash for a script with the same source")
end)

test("getscripts", {}, function()
	local scripts = getscripts()
	assert(type(scripts) == "table", "Did not return a table")
	assert(#scripts > 0, "Did not return a table with any values")
	assert(typeof(scripts[1]) == "Instance", "First value is not an Instance")
	assert(scripts[1]:IsA("ModuleScript") or scripts[1]:IsA("LocalScript"), "First value is not a ModuleScript or LocalScript")
end)

test("getsenv", {}, function()
	local animate = game:GetService("Players").LocalPlayer.Character.Animate
	local env = getsenv(animate)
	assert(type(env) == "table", "Did not return a table for Character.Animate (a " .. animate.ClassName .. ")")
	assert(env.script == animate, "The script global is not identical to Character.Animate")
end)

test("getthreadidentity", {"getidentity", "getthreadcontext"}, function()
	assert(type(getthreadidentity()) == "number", "Did not return a number")
end)

test("setthreadidentity", {"setidentity", "setthreadcontext"}, function()
	setthreadidentity(3)
	assert(getthreadidentity() == 3, "Did not set the thread identity")
end)

-- Drawing

test("Drawing", {})

test("Drawing.new", {}, function()
	local drawing = Drawing.new("Square")
	drawing.Visible = false
	local canDestroy = pcall(function()
		drawing:Destroy()
	end)
	assert(canDestroy, "Drawing:Destroy() should not throw an error")
end)

test("Drawing.Fonts", {}, function()
	assert(Drawing.Fonts.UI == 0, "Did not return the correct id for UI")
	assert(Drawing.Fonts.System == 1, "Did not return the correct id for System")
	assert(Drawing.Fonts.Plex == 2, "Did not return the correct id for Plex")
	assert(Drawing.Fonts.Monospace == 3, "Did not return the correct id for Monospace")
end)

test("isrenderobj", {}, function()
	local drawing = Drawing.new("Image")
	drawing.Visible = true
	assert(isrenderobj(drawing) == true, "Did not return true for an Image")
	assert(isrenderobj(newproxy()) == false, "Did not return false for a blank table")
end)

test("getrenderproperty", {}, function()
	local drawing = Drawing.new("Image")
	drawing.Visible = true
	assert(type(getrenderproperty(drawing, "Visible")) == "boolean", "Did not return a boolean value for Image.Visible")
	local success, result = pcall(function()
		return getrenderproperty(drawing, "Color")
	end)
	if not success or not result then
		return "Image.Color is not supported"
	end
end)

test("setrenderproperty", {}, function()
	local drawing = Drawing.new("Square")
	drawing.Visible = true
	setrenderproperty(drawing, "Visible", false)
	assert(drawing.Visible == false, "Did not set the value for Square.Visible")
end)

test("cleardrawcache", {}, function()
	cleardrawcache()
end)

-- WebSocket

test("WebSocket", {})

test("WebSocket.connect", {}, function()
	local types = {
		Send = "function",
		Close = "function",
		OnMessage = {"table", "userdata"},
		OnClose = {"table", "userdata"},
	}
	local ws = WebSocket.connect("wss://echo.websocket.org")
	assert(type(ws) == "table" or type(ws) == "userdata", "Did not return a table or userdata")
	for k, v in pairs(types) do
		if type(v) == "table" then
			assert(table.find(v, type(ws[k])), "Did not return a " .. table.concat(v, ", ") .. " for " .. k .. " (a " .. type(ws[k]) .. ")")
		else
			assert(type(ws[k]) == v, "Did not return a " .. v .. " for " .. k .. " (a " .. type(ws[k]) .. ")")
		end
	end
	ws:Close()
end)

--parallel
test("run_on_actor",{})

test("getactors",{})

test("get_comm_channel",{})
