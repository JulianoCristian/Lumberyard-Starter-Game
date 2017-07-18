local debugmanager =
{
	Properties =
	{
		DebugTheDebugManager = { default = false },
		AI =
		{
			EnableAISpawning = { default = false, description = "Enable the spawning of A.I. mobs." },
			EnableAICombat = { default = false, description = "Allow the A.I. to actively combat the player." },
			PreventAIDisabling = { default = false, description = "Ignores trigger volumes that enable/disable A.I." },
		},
		
		Player =
		{
			InfiniteEnergy = { default = false, description = "If true, player does not lose energy when firing." },
			GodMode = { default = false, description = "If true, the player can't lose health." },
		},
		
		Rendering =
		{
			EnableDynamicDecals = { default = true, description = "Enable dynamic decals such as the plasma rifle's scorch mark." },
		},
	},
}

function debugmanager:OnActivate()
	-- We can't gaurantee that everything will already be initialised at this point and thus
	-- some entities may not receive our messages. As a result, we have to do the message
	-- sending on the first tick instead.
	if (Config.Build ~= Config.Release) then
		Debug.Log("Debug manager enabled");
		self.tickHandler = TickBus.Connect(self);
		self.performedFirstTick = false;
	end
	
end

function debugmanager:OnDeactivate()

	if (self.tickHandler ~= nil) then
		self.tickHandler:Disconnect();
		self.tickHandler = nil;
	end

end
	
function debugmanager:OnTick(deltaTime, timePoint)
	
	if (self.performedFirstTick == false) then
		local mt = getmetatable(self.Properties);
		self:StoreDebugVarBool("EnableAISpawning", self.Properties.AI.EnableAISpawning, mt.AI.EnableAISpawning.default);
		self:StoreDebugVarBool("EnableAICombat", self.Properties.AI.EnableAICombat, mt.AI.EnableAICombat.default);
		self:StoreDebugVarBool("PreventAIDisabling", self.Properties.AI.PreventAIDisabling, mt.AI.PreventAIDisabling.default);
		
		self:StoreDebugVarBool("InfiniteEnergy", self.Properties.Player.InfiniteEnergy, mt.Player.InfiniteEnergy.default);
		self:StoreDebugVarBool("GodMode", self.Properties.Player.GodMode, mt.Player.GodMode.default);
		
		self:StoreDebugVarBool("EnableDynamicDecals", self.Properties.Rendering.EnableDynamicDecals, mt.Rendering.EnableDynamicDecals.default);
		
		self.performedFirstTick = true;
	end
	
	-- TODO: Ideally, we'd like to have the debug manager register changes in the console
	-- variables and broadcast those as well (if we can't have a bus that each script
	-- can register with).
	
	-- This function is a work-around because we can't disconnect the tick handler directly
	-- inside the 'OnTick()' function, but we can inside another function; apparently, even
	-- if that function is called FROM the 'OnTick()' function.
	self:StopTicking();

end

function debugmanager:StopTicking()

	if (self.tickHandler ~= nil) then
		self.tickHandler:Disconnect();
		self.tickHandler = nil;
	end
	
end

function debugmanager:ChooseDebugOrReleaseValue(debugVal, releaseVal)
	-- Use the default value if we're in a release build; otherwise use the debug value.
	local res = debugVal;
	if (Config.Build == Config.Release) then
		res = releaseVal;
	end
	return res;
end

function debugmanager:StoreDebugVarBool(event, value, default)
	if (self.Properties.DebugTheDebugManager == true) then
		Debug.Log("Adding variable " .. tostring(event) .. " (default: " .. tostring(default) .. "): " .. tostring(value));
	end
	DebugManagerComponentRequestsBus.Event.SetDebugBool(self.entityId, event, self:ChooseDebugOrReleaseValue(value, default));
end

function debugmanager:StoreDebugVarFloat(event, value, default)
	if (self.Properties.DebugTheDebugManager == true) then
		Debug.Log("Adding variable " .. tostring(event) .. " (default: " .. tostring(default) .. "): " .. tostring(value));
	end
	DebugManagerComponentRequestsBus.Event.SetDebugFloat(self.entityId, event, self:ChooseDebugOrReleaseValue(value, default));
end

return debugmanager;