--!strict
local HttpService = game:GetService("HttpService")

export type RepoDetails = {
	Owner: string,
	Name: string,
	Branch: string?,
}

export type Settings = {
	skipDotDirectories: boolean?,
	loadLuaFiles: boolean?,
	loadJSONFiles: boolean?,
	arrayNumericNamedFiles: boolean?,
	getDepth: number?,
}

export type GitHub = {
	_AuthToken: string?,

	SetAuthToken: (GitHub, string) -> (),
	BuildQuery: (GitHub, string, string, string?, number?) -> (string, number),
	GetRepo: (GitHub, Repo, Settings) -> (boolean, string | { [string | number]: any }),
}

local function escape(str)
	return string.gsub(string.gsub(string.gsub(str, "%c+", " "), "%s+", " "), '"', '\\"')
end

local queryHandlerChunk = escape([[ ... on Tree {
  entries {
    name
    type
    extension
    object {
      ... on Blob {
        text
      }]])

local GitHub: GitHub = {
	_AuthToken = nil,

	--[[
		token: string - The personal access token you generated on GitHub (make sure it has the repo read permission)
	--]]
	SetAuthToken = function(self: GitHub, token: string)
		if type(token) ~= "string" then
			error("Invalid token", token)
		end

		self._AuthToken = token
	end,

	BuildQuery = function(_: GitHub, owner: string, name: string, branch: string?, depth: number?): (string, number)
		local queryBuilder = {
			string.format(
				[[query { repository(owner: "%s", name: "%s") { object(expression: "%s:") {]],
				owner,
				name,
				branch or "HEAD"
			),
		}

		for _ = 1, depth or 5 do
			table.insert(queryBuilder, queryHandlerChunk)
		end
		for _ = 1, depth or 5 do
			table.insert(queryBuilder, [[ } } }]])
		end

		table.insert(queryBuilder, [[ } } }]])

		return escape(table.concat(queryBuilder))
	end,

	GetRepo = function(
		self: GitHub,
		repoDetails: RepoDetails,
		settings: Settings
	): (boolean, string | { [string | number]: any })
		if type(self._AuthToken) ~= "string" then
			error("Cannot :GetRepo until auth token is set via :SetAuthToken")
		end

		if repoDetails == nil or settings == nil then
			error("Must pass repo and settings arguments")
		end

		local owner = repoDetails.Owner
		local name = repoDetails.Name
		local branch = repoDetails.Branch or "HEAD"

		local getDepth = if type(settings.getDepth) == "number" then settings.getDepth else 6
		local loadLuaFiles = if type(settings.loadLuaFiles) == "boolean" then settings.loadLuaFiles else true
		local loadJSONFiles = if type(settings.loadJSONFiles) == "boolean" then settings.loadJSONFiles else true
		local arrayNumericNamedFiles = if type(settings.arrayNumericNamedFiles) == "boolean"
			then settings.arrayNumericNamedFiles
			else true
		local skipDotDirectories = if type(settings.skipDotDirectories) == "boolean"
			then settings.skipDotDirectories
			else false

		local query: string = self:BuildQuery(owner, name, branch, getDepth)

		local success, result = pcall(HttpService.RequestAsync, HttpService, {
			Method = "POST",
			Url = "https://api.github.com/graphql",
			Headers = {
				Authorization = "bearer " .. (self._AuthToken :: string),
			},
			Body = '{ "query": "' .. query .. '"',
		})
		if not success then
			return false, result
		end

		local decodeSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, result.Body)
		if not decodeSuccess then
			return false, decoded
		end

		local repo: { [string | number]: any } = {}

		local function handleEntry(entry, parent)
			local children = entry.entries or (entry.object and entry.object.entries)
			local skipChildren = false

			local newParent
			if entry.type == "tree" then
				if skipDotDirectories and string.find(entry.name, "^%.") then
					skipChildren = true
				else
					newParent = table.create(children and #children or 0)

					local directoryKey: string | number = entry.name
					if arrayNumericNamedFiles then
						directoryKey = tonumber(entry.name) or directoryKey
					end

					parent[directoryKey] = newParent
				end
			elseif entry.type == "blob" then
				local fileType: string = entry.extension
				local fileName = string.gsub(entry.name, fileType .. "$", "")

				local fileValue: any = entry.object.text
				if fileType == ".lua" or fileType == ".luau" then
					if loadLuaFiles then
						local loadedCode, compileError = loadstring(fileValue)
						if loadedCode == nil then
							warn(entry.name, "loadstring failed", compileError)
						else
							local callSuccess, callResult = pcall(loadedCode)
							if not callSuccess then
								warn(entry.name, "loadstring failed", callResult)
							else
								fileValue = callResult
							end
						end
					end
				elseif fileType == ".json" then
					if loadJSONFiles then
						local jsonSuccess, json = pcall(HttpService.JSONDecode, HttpService, fileValue)
						if not jsonSuccess then
							warn(entry.name, "JSONDecode failed", json)
						else
							fileValue = json
						end
					end
				end

				local fileKey: string | number = fileName
				if arrayNumericNamedFiles then
					fileKey = tonumber(fileName) or fileKey
				end

				parent[fileKey] = fileValue
			end

			if children and not skipChildren then
				for _, child in ipairs(children) do
					handleEntry(child, newParent or parent)
				end
			end
		end

		handleEntry(decoded.data.repository.object, repo)

		-- print("Retrieved GH repository", owner.."/"..name, repo)

		return true, repo
	end,
}

return GitHub
