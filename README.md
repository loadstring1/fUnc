# fUnc (fixed  Unc)
used for testing exploit capability

tutorial how to run
1. if your exploit supports request function you should use this
```
loadstring(request({Url="https://raw.githubusercontent.com/loadstring1/fUnc/refs/heads/main/fUnc.lua",Method="GET"}).Body)()
```
2. if your exploit is so garbage that it doesn't support basic request and requires game:HttpGet instead then use this
```
loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstring1/fUnc/refs/heads/main/fUnc.lua"))()
```

19.10.2025
- fixed WebSocket test connecting to a websocket that doesn't even work
- fixed getscriptclosure test failing because of non-existant Constants module that roblox removed ages ago from CoreGui
