# openUNC (open source  UNC)
used for testing exploit capability

tutorial how to run
1. **RECOMMENDED** if your exploit supports request function you should use this
```lua
loadstring(request({Url="https://raw.githubusercontent.com/loadstring1/openUNC/refs/heads/main/openUNC.lua",Method="GET"}).Body)()
```

2. if your exploit is so garbage that it doesn't support basic request and requires game:HttpGet instead then use this
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstring1/openUNC/refs/heads/main/openUNC.lua"))()
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
- improved fireclickdetector test
- added fireproximityprompt test
- added firetouchinterest test
- added firesignal test
- added newlclosure test
- removed dofile check (its useless and we already have loadfile anyways)
- added canreplicatesignal test
- added getrendersteppedlist check
- added isnetworkowner test
- improved getinstances test
- improved getnilinstances test
- added clear_teleport_queue check
- improved getloadedmodules test (currently thats commented out bc potassium crashes when i do that and i dont have other executors than potassium)
- added run_on_actor check
- added getactors check
- added get_comm_channel check
