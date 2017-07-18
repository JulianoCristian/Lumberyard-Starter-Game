local utilities = require "scripts/common/utilities"

local aispawner =
{
	Properties =
	{
		Enabled = { default = true },
		OverrideDebugManager = { default = false },
		GroupId = { default = "", description = "Spawner's spawn group." },
	},
}

function aispawner:OnActivate()

	self.spawnerHandler = SpawnerComponentNotificationBus.Connect(self, self.entityId);
	self.spawnTicket = false;
	
	self.tickHandler = TickBus.Connect(self);
	self.performedFirstUpdate = false;
	
	self.enteredAITriggerEventId = GameplayNotificationId(EntityId(), "EnteredAITrigger");
	self.enteredAITriggerHandler = GameplayNotificationBus.Connect(self, self.enteredAITriggerEventId);	
	self.exitedAITriggerEventId = GameplayNotificationId(EntityId(), "ExitedAITrigger");
	self.exitedAITriggerHandler = GameplayNotificationBus.Connect(self, self.exitedAITriggerEventId);	
end

function aispawner:OnDeactivate()

	if (self.tickHandler ~= nil) then
		self.tickHandler:Disconnect();
		self.tickHandler = nil;
	end
	
	if (self.spawnerHandler ~= nil) then
		self.spawnerHandler:Disconnect();
		self.spawnerHandler = nil;
	end
	if(self.enteredAITriggerHandler ~= nil) then
		self.enteredAITriggerHandler:Disconnect();
		self.enteredAITriggerHandler = nil;
	end
	if(self.exitedAITriggerHandler ~= nil) then
		self.exitedAITriggerHandler:Disconnect();
		self.exitedAITriggerHandler = nil;
	end

end

function aispawner:OnTick(deltaTime, timePoint)

	if (self.performedFirstUpdate == false) then
		-- Check with the debug manager whether or not we should spawn A.I.
		-- default to spawn if debug manager does not exist
		local shouldSpawn = self.Properties.OverrideDebugManager or utilities.DebugManagerGetBool("EnableAISpawning", true);
		
		-- Spawn the A.I.
		if (shouldSpawn and self.Properties.Enabled == true) then
			-- Look below the spawner for a piece of terrain to spawn on.
			local rayCastConfig = RayCastConfiguration();
			rayCastConfig.origin = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
			rayCastConfig.direction =  Vector3(0.0, 0.0, -1.0);
			rayCastConfig.maxDistance = 2.0;
			rayCastConfig.maxHits = 1;
			rayCastConfig.physicalEntityTypes = PhysicalEntityTypes.Static;		
			local hits = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfig);				
			if (#hits > 0) then
				local tm = Transform.CreateIdentity();
				tm:SetTranslation(hits[1].position);
				self.spawnTicket = SpawnerComponentRequestBus.Event.SpawnAbsolute(self.entityId, tm);
				if (self.spawnTicket == nil) then
					Debug.Log("Spawn failed");
				end
			else
				-- This asserts if we couldn't find terrain below the spawner to place the
				-- slice.
				-- This would need to be changed if we had flying enemies (obviously).
				-- I want this to be an assert, but apparently asserts and warnings don't
				-- do anything so I'll have to keep it as a log.
				Debug.Log("AISpawner: '" .. tostring(StarterGameUtility.GetEntityName(self.entityId)) .. "' couldn't find a point to spawn the A.I.");
			end
		end
	
		self.performedFirstUpdate = true;
	end
	
	-- Unregister from the tick bus.
	self.tickHandler:Disconnect();
	self.tickHandler = nil;

end
function aispawner:EnableAI()
	if(self.spawnedEntityId ~= nil) then -- Will be nil if the spawner is not enabled or spawning failed
		local eventId = GameplayNotificationId(self.spawnedEntityId, "Enable");
		GameplayNotificationBus.Event.OnEventBegin(eventId, self.entityId);
	end
end
function aispawner:DisableAI()
	if(self.spawnedEntityId ~= nil) then -- Will be nil if the spawner is not enabled or spawning failed
		local eventId = GameplayNotificationId(self.spawnedEntityId, "Disable");
		GameplayNotificationBus.Event.OnEventBegin(eventId, self.entityId);
	end
end
function aispawner:EnteredAITrigger(groupId)
	if(groupId == self.Properties.GroupId) then
		self:EnableAI();
	end
end
function aispawner:ExitedAITrigger(groupId)
	if(groupId == self.Properties.GroupId) then
		self:DisableAI();
	end
end
function aispawner:OnEventBegin(value)
	if (GameplayNotificationBus.GetCurrentBusId() == self.enteredAITriggerEventId) then
		self:EnteredAITrigger(value);
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.exitedAITriggerEventId) then
		self:ExitedAITrigger(value);
	end
end

function aispawner:OnEntitySpawned(ticket, spawnedEntityId)

	local isMainEntity = StarterGameUtility.EntityHasTag(spawnedEntityId, "AICharacter");
	if (self.spawnTicket == ticket and isMainEntity) then
		self.spawnedEntityId = spawnedEntityId;
		local eventId = GameplayNotificationId(spawnedEntityId, "AISpawned");
		GameplayNotificationBus.Event.OnEventBegin(eventId, self.entityId);
	end

end

return aispawner;