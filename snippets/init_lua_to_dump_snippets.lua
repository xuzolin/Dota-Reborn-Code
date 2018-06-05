--============ Copyright (c) Valve Corporation, All rights reserved. ==========
--
--
--=============================================================================

Msg( "Initializing script VM(Modified)...\n" )


-------------------------------------------------------------------------------

-- returns a string like "foo.nut:53"
-- with the source file and line number of its caller.
-- returns the empty string if it couldn't get the source file and line number of its caller.
function _sourceline() 
    local v = debug.getinfo(2, "sl")
    if v then 
        return tostring(v.source) .. ":" .. tostring(v.currentline) .. " "
    else 
        return ""
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
require "utils.class"
require "utils.library"
require "utils.vscriptinit"
require "core.coreinit"
require "utils.utilsinit"
require "framework.frameworkinit"
require "framework.entities.entitiesinit"
require "game.globalsystems.timeofday_init"
require "game.gameinit"

local function string_split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {} ; i = 1
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[i] = str
        i    = i + 1
    end
    return t
end


function DumpScriptBindings()
	function BuildFunctionSignatureString( fnName, fdesc )
		local docList = {}
		table.insert( docList, string.format( "---[[ %s  %s ]]", fnName, fdesc.desc ) )
		table.insert( docList, string.format( "-- @return %s", fdesc.returnType ) )
		local parameterList = {}

		local completionParamterList = {}
		local completionParamterListForVSC = {}

		-- try to get param description from the description
		local possibleParamDesc
		if string.find(fdesc.desc, "%(") and string.find(fdesc.desc, '%)') then
			possibleParamDesc = string.sub(fdesc.desc, string.find(fdesc.desc, "%(") + 1, string.find(fdesc.desc, "%)") - 1)
			possibleParamDesc = string_split(possibleParamDesc, ',')
		end

		for i = 0, #fdesc-1 do
			local prmType, prmName = unpack( fdesc[i] )
			if prmName == nil or prmName == "" then 
				if possibleParamDesc and possibleParamDesc[i+1] then
					prmName = string.gsub(possibleParamDesc[i+1], " ", "")
				else
					prmName = string.format( "%s_%d", prmType, i+1 ) 
				end
			end
			table.insert( docList, string.format( "-- @param %s %s", prmName, prmType ) )
			table.insert( parameterList, prmName )
			table.insert( completionParamterList, string.format('${%s:%s}', i+1, prmName))
			table.insert( completionParamterListForVSC, string.format('${%s}', prmName))
		end

		local realFnName = fnName
		local classFnName
		if string.find(fnName, ':') then
			realFnName = string.sub(fnName, string.find(fnName, ':')+1, -1)
			classFnName = string.gsub(fnName, ':','_')
			return string.format( "%s\nfunction %s( %s ) end\n", table.concat( docList, "\n"), fnName, table.concat( parameterList, ", " ) ) , -- 用来打印的
			string.format( '"%s":\n\t{\n\t\t"body":"%s(%s)",\n\t\t"description":"%s",\n\t\t"prefix":"%s"\n\t}', classFnName, realFnName, table.concat(completionParamterListForVSC, ", "), 
				string.format('%s:\\n%s\\n%s', classFnName, fdesc.desc, string.format( "return %s", fdesc.returnType )), realFnName), -- 用来给VSC的补全
			string.format( '{ "trigger": "%s", "contents": "%s(%s)" }', realFnName, realFnName, table.concat(completionParamterList, ", ")), -- 不带有class提示的sublime
			string.format( '{ "trigger": "%s", "contents": "%s(%s)" }', classFnName, realFnName, table.concat(completionParamterList, ", ")) -- 带有class提示的sublime
		else
			return string.format( "%s\nfunction %s( %s ) end\n", table.concat( docList, "\n"), fnName, table.concat( parameterList, ", " ) ) , -- 用来打印的
			string.format( '"%s":\n\t{\n\t\t"body":"%s(%s)",\n\t\t"description":"%s",\n\t\t"prefix":"%s"\n\t}', realFnName, realFnName, table.concat(completionParamterListForVSC, ", "), 
				string.format('%s:\\n%s\\n%s', realFnName, fdesc.desc, string.format( "return %s", fdesc.returnType )), realFnName), -- 用来给VSC的补全
			string.format( '{ "trigger": "%s", "contents": "%s(%s)" }', realFnName, realFnName, table.concat(completionParamterList, ", ")) -- 全局的sublime
		end
	end
	function SortedKeys( tbl )
		local result = {}
		if tbl ~= nil then
			for k,_ in pairs( tbl ) do table.insert( result, k ) end
		end
		table.sort( result )
		return result
	end

	local constant_str = [[
// This file is auto generated by modified init.lua
{
	"scope": 	["source.lua", "source.moonscript", "source.txt"],
	"completions":
	[
		]]

	local function_str = [[
// This file is auto generated by modified init.lua
{
	"scope": 	"source.lua",
	"completions":
	[
		]]

	local vsc_str = [[
{
	]]

	local func_completions = {}
	local cons_completions = {}
	local vsc_completions = {}

	for _,fnName in ipairs( SortedKeys( FDesc ) ) do
		local fdesc = FDesc[ fnName ]
		local dump, vsc, fn1, fn2 = BuildFunctionSignatureString( fnName, fdesc )
		-- print(dump)
		table.insert(vsc_completions, vsc)
		table.insert(func_completions, fn1)
		if fn2 then
			table.insert(func_completions, fn2)
		end
	end
	for _,enumName in ipairs( SortedKeys( EDesc ) ) do
		local edesc = EDesc[ enumName ]
		-- print( string.format( "\n--- Enum %s", enumName ) )
		for _,valueName in ipairs( SortedKeys( edesc ) ) do
			if edesc[valueName] ~= "" then
				-- print( string.format( "%s = %d -- %s", valueName, _G[valueName], edesc[valueName] ) )
			else
				-- print( string.format( "%s = %d", valueName, _G[valueName] ) )
			end
			table.insert(cons_completions, '"' .. valueName .. '"')

			local vsc_s = string.format('"%s":{"body":"%s", "description":"%s", "prefix": "%s"}', valueName, valueName, edesc[valueName], valueName)
			table.insert(vsc_completions, vsc_s)
			-- print(vsc_s)
		end
	end
	for _,className in ipairs( SortedKeys( CDesc ) ) do
		local cdesc = CDesc[ className ]
		for _,fnName in ipairs( SortedKeys( cdesc.FDesc ) ) do
			local fdesc = cdesc.FDesc[ fnName ]
			local dump, vsc, fn1, fn2 = BuildFunctionSignatureString( string.format( "%s:%s", className, fnName ), fdesc )
			-- print(dump)
			table.insert(vsc_completions, vsc)			
			table.insert(func_completions, fn1)
			if fn2 then
				table.insert(func_completions, fn2)
			end
		end
	end

	func_completions = table.concat(func_completions, ",\n\t\t")
	function_str = function_str .. func_completions .. '\n\t]\n}'

	cons_completions = table.concat(cons_completions, ",\n\t\t")
	constant_str = constant_str .. cons_completions .. '\n\t]\n}'

	vsc_completions = table.concat(vsc_completions, ",\n\t")
	vsc_str = vsc_str .. vsc_completions .. '\n}'


	local func_file = io.open('D:/Git/Dota-Reborn-Package/dota-lua/completions/Functions.sublime-completions', 'w')
	func_file:write(function_str)
	func_file:close()

	local cons_file = io.open('D:/Git/Dota-Reborn-Package/dota-lua/completions/Constants.sublime-completions', 'w')
	cons_file:write(constant_str)
	cons_file:close()

	local vsc_file = io.open('D:/Git/Dota-Reborn-Code/snippets/lua.json', 'w')
	vsc_file:write(vsc_str)
	vsc_file:close()
	print("done")
end

function ScriptFunctionHelp( scope )
	if FDesc == nil or CDesc == nil then
		print( "Script help is only available in developer mode." )
		return
	end
	function SortedKeys( tbl )
		local result = {}
		if tbl ~= nil then
			for k,_ in pairs( tbl ) do table.insert( result, k ) end
		end
		table.sort( result )
		return result
	end
	function PrintEnum( enumName, enumTable )
		print( "\n***** Enum " .. tostring( enumName ) .. " *****" )
		for i,name in ipairs(SortedKeys( enumTable )) do
			print ( string.format( "%s (%d) %s", tostring( name ), _G[name], tostring( enumTable[name] ) ) )
		end
	end
	function PrintBindings( tbl )
		for _,name in ipairs( SortedKeys( tbl.FDesc ) ) do
			print( tostring( tbl.FDesc[name] ) )
		end
		for _,name in ipairs( SortedKeys( tbl.EDesc ) ) do
			PrintEnum( name, tbl.EDesc[name ] )
		end
	end

	if scope and scope ~= "" then
		if scope == "dump" then
			DumpScriptBindings()
		elseif scope == "global" then
			PrintBindings( _G )
		elseif scope == "all" then
			print( "***** Global Scope *****" )
			ScriptFunctionHelp( "global" )
			for _,className in ipairs( SortedKeys( CDesc ) ) do
				print( string.format( "\n***** Class %s ******", className ) )
				ScriptFunctionHelp( className )
			end
		elseif CDesc[scope] then
			print( string.format( "**** Class %s *****", scope ) )
			PrintBindings( CDesc[ scope ] )
		elseif EDesc[scope] then
			PrintEnum( scope, EDesc[scope] )
		else
			print( "Unable to find scope: " .. scope )
		end
	else
		print( "Usage: \"script_help <scope>\" where <scope> is one of the following:\n\tall\tglobal\tdump" )
		for _,className in ipairs( SortedKeys( CDesc ) ) do
			print( "\t" .. className )
		end
		for _,enumName in ipairs( SortedKeys( EDesc ) ) do
			print( "\t" .. enumName )
		end
	end
end

function GetFunctionSignature( func, name )
	local signature = name .. "( "
	local nParams = debug.getinfo( func ).nparams
	for i = 1, nParams do
		signature = signature .. debug.getlocal( func, i )
		if i ~= nParams then
			signature = signature .. ", "
		end
	end
	signature = signature .. " )"
	return signature
end

_PublishedHelp = {}
function AddToScriptHelp( scopeTable )
	if FDesc == nil then
		return
	end

	for name, val in pairs( scopeTable ) do
		if type(val) == "function" then
			local helpstr = "scripthelp_" .. name
			if vlua.contains( scopeTable, helpstr ) and ( not vlua.contains( _PublishedHelp, helpstr ) ) then
				FDesc[name] = GetFunctionSignature( val, name ) .. "\n" .. scopeTable[helpstr]
				_PublishedHelp[helpstr] = true
			end
		end
	end
end

-- This chunk of code forces the reloading of all modules when we reload script.
if g_reloadState == nil then
	g_reloadState = {}
	for k,v in pairs( package.loaded ) do
		g_reloadState[k] = v
	end
else
	for k,v in pairs( package.loaded ) do
		if g_reloadState[k] == nil then
			package.loaded[k] = nil
		end
	end
end

-- This function lets a lua instance extend a c++ instance.
function ExtendInstance( instance, luaClass )
	-- Assume if BaseClass has already been set, we're in the script_reload case.
	if instance.BaseClass ~= nil and getmetatable( instance ).__index ~= luaClass then
		setmetatable( luaClass, { __index = instance.BaseClass } )
		setmetatable( instance, { __index = luaClass } )
		return instance
	end
	instance.BaseClass = getmetatable( instance ).__index
    setmetatable( luaClass, getmetatable( instance ) )
    setmetatable( instance, { __index = luaClass } )
    return instance
end



Msg( "...done\n" )
