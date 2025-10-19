# openUNC (open source  UNC)
used for testing exploit capability

tutorial how to run
1. **RECOMMENDED** if your exploit supports request function you should use this
```lua
loadstring(request({Url="https://raw.githubusercontent.com/loadstring1/fUnc/refs/heads/main/fUnc.lua",Method="GET"}).Body)()
```

2. if your exploit is so garbage that it doesn't support basic request and requires game:HttpGet instead then use this
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstring1/fUnc/refs/heads/main/fUnc.lua"))()
```

changelog: 
19.10.2025
- fixed WebSocket test connecting to a websocket that doesn't even work
- fixed getscriptclosure test failing because of non-existant Constants module that roblox removed ages ago from CoreGui
- added filtergc test
- added getcallingscript test
- added restorefunction test
- added getfunctionhash test
- added getreg test
- improved getgc test
