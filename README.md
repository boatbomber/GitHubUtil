# GitHub Util

Utility module for handling GitHub APIs from a Roblox experience

## Usage

```Lua
local GitHubUtil = require(ServerPackages.GitHubUtil)

GitHubUtil:SetAuthToken("ghp_YOUR-KEY-HERE")

local repoSuccess, repoContent = GitHubUtil:GetRepo({
    Owner = "Roblox",
    Name = "Roact",
    Branch = "master",
}, {
    skipDotDirectories = true,
    loadLuaFiles = false,
})
```

## API

```Lua
function GitHubUtil:SetAuthToken(token: string) -> ()
```

Sets the auth token that will be used in requests. Must be called prior to attempting any requests.

```Lua
function GitHubUtil:GetRepo(repo: RepoDetails, settings: Settings) -> (success: boolean, result: string | {})
```

Fetches the given repository according to the settings passed.

```Lua
type RepoDetails = {
    Owner: string,
    Name: string,
    Branch: string?
}

type Settings = {
    getDepth: number? -- How many nested directories deep to query
    skipDotDirectories: boolean?, -- Exclude folders starting with .
    loadLuaFiles: boolean?, -- Put .lua files through loadstring and use their result
    loadJSONFiles: boolean?, -- Put .json file through HttpService:JSONDecode and use the resulting table
    arrayNumericNamedFiles: boolean?, -- Put 1.txt, 2.txt, ... into numeric keys instead of string
}
```
