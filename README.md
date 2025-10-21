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
