local utils = require "scripts/common/utilities"
local StateMachine = require "scripts/common/StateMachine"


local bullet =
{
	Properties =
	{
		Lifespan = { default = 6, description = "How long before the bullet explodes (regardless of impact).", suffix = " s" },
		Speed = { default = 35.0, description = "" },
		
		StateMachine =
		{
			InitialState = "Idle",
			DebugStateMachine = false,
		},
		
		Firepower =
		{
			Damage = { default = 50.0, description = "The amount of damage a single shot does." },
			ForceMultiplier = { default = 1250, description = "The strength of the explosion at the center." },
		},
		
		Range =
		{
			Initial = { default = 4, description = "The initial range of the explosion", suffix = " m" },
			Max = { default = 12, description = "The range of the explosion.", suffix = " m" },
			
			ExpansionDuration = { default = 0.5, description = "Time taken for the explosion to reach its maximum range.", suffix = " s" },
		},
		
		Shockwave =
		{
			Shockwave = { default = EntityId() },
			RotationSpeed = { default = 5, description = "Rotation speed of the shockwave effect.", suffix = " deg/s" },
			
			OpacityInitial = { default = 60, description = "Shockwave's initial opacity (0 - 100)." },
			OpacityEnd = { default = 20, description = "Shockwave's opacity at the end of the explosion (0 - 100)." },
			
			DiffuseInitial = { default = Vector3(50, 255, 255), description = "Shockwave's initial diffuse colour." },
			DiffuseEnd = { default = Vector3(150, 255, 255), description = "Shockwave's diffuse colour at the end of the explosion." },
			
			Dissipation =
			{
				ExtraDistance = { default = 1.0, description = "Additional distance the shockwave will travel before completely vanishing.", suffix = " m" },
				ExtraDuration = { default = 2.0, description = "Additional duration the shockwave will exist before completely vanishing.", suffix = " s" },
				
				OpacityFinal = { default = 0, description = "Shockwave's opacity at the end of dissipation (0 - 100)." },
				
				DiffuseFinal = { default = Vector3(255, 0, 0), description = "Shockwave's diffuse colour at the end of dissipation." },
			},
		},
		
		Events =
		{
			GotShot = "GotShotEvent";
			DealDamage = "HealthDeltaValueEvent";
		},
	},
	
	--------------------------------------------------
	-- State Machine Definition
	-- States:
	--		Idle		- waiting to be used
	--		Fired		- flying through the air
	--		Exploding	- collided and applying impulses/damage
	--		Dissipating	- fading away and NOT applying impulses/damage
	--
	-- Transitions:
	--		Idle		 -> Fired
	--					<-  Dissipating
	--		Fired		 -> Exploding
	--					<-  Idle
	--		Exploding	 -> Dissipating
	--					<-  Fired
	--		Dissipating	 -> Idle
	--					<-  Exploding
	--------------------------------------------------
	States =
	{
		Idle =
		{
			OnEnter = function(self, sm)
				sm.UserData:Reset();
			end,
			
			OnExit = function(self, sm)
			
			end,
			
			OnUpdate = function(self, sm, deltaTime)
			
			end,
			
			Transitions =
			{
				Fired =
				{
					Evaluate = function(state, sm)
						return sm.UserData.launchDir ~= Vector3(0.0, 0.0, 0.0);
					end
				},
			},
		},
		
		Fired =
		{
			OnEnter = function(self, sm)
				sm.UserData:JustFired();
			end,
			
			OnExit = function(self, sm)
			
			end,
			
			OnUpdate = function(self, sm, deltaTime)
				sm.UserData:UpdateFired(deltaTime);
			end,
			
			Transitions =
			{
				-- The 'Detonate()' function will change the state to Exploding.
			},
		},
		
		Exploding =
		{
			OnEnter = function(self, sm)
				sm.UserData.explosionTimer = 0.0;
				sm.UserData.dissipateTimer = 0.0;
			end,
			
			OnExit = function(self, sm)
				
			end,
			
			OnUpdate = function(self, sm, deltaTime)
				sm.UserData.explosionTimer = utils.Clamp(sm.UserData.explosionTimer + deltaTime, 0.0, sm.UserData.Properties.Range.ExpansionDuration);
				
				-- Perform any impulse on any additional nearby objects and update the shockwave.
				sm.UserData:UpdateExplosion(deltaTime);
			end,
			
			Transitions =
			{
				Dissipating =
				{
					Evaluate = function(state, sm)
						return sm.UserData.explosionTimer >= sm.UserData.Properties.Range.ExpansionDuration;
					end
				},
			},
		},
		
		Dissipating =
		{
			OnEnter = function(self, sm)
				
			end,
			
			OnExit = function(self, sm)
				sm.UserData.launchDir = Vector3(0.0, 0.0, 0.0);
			end,
			
			OnUpdate = function(self, sm, deltaTime)
				sm.UserData.dissipateTimer = utils.Clamp(sm.UserData.dissipateTimer + deltaTime, 0.0, sm.UserData.Properties.Shockwave.Dissipation.ExtraDuration);
				
				-- Update the shockwave.
				sm.UserData:UpdateShockwave(deltaTime, nil);
			end,
			
			Transitions =
			{
				Idle =
				{
					Evaluate = function(state, sm)
						return sm.UserData.dissipateTimer >= sm.UserData.Properties.Shockwave.Dissipation.ExtraDuration;
					end
				},
			},
		},
	},
}

function bullet:OnActivate()
	self.life = 0.0;
	self.launchDir = Vector3(0.0, 0.0, 0.0);
	self.owner = EntityId();
	
	self.explosionTimer = 0.0;
	self.dissipateTimer = 0.0;
	
	self.ignoreSurfaceId = StarterGameUtility.GetSurfaceIndexFromString("mat_nodraw");
	
	self.entitiesHit = {}
		
	self.Properties.Shockwave.RotationSpeed = Math.DegToRad(self.Properties.Shockwave.RotationSpeed);
	self.Properties.Shockwave.OpacityInitial = self.Properties.Shockwave.OpacityInitial * 0.01;
	self.Properties.Shockwave.OpacityEnd = self.Properties.Shockwave.OpacityEnd * 0.01;
	self.Properties.Shockwave.Dissipation.OpacityFinal = self.Properties.Shockwave.Dissipation.OpacityFinal * 0.01;

	self.performedFirstReset = false;
	
	self.physicsNotificationHandler = nil;
	
	-- Disable the physics.
	PhysicsComponentRequestBus.Event.DisablePhysics(self.entityId);
	
	-- Disable the trails particle.
	ParticleComponentRequestBus.Event.Enable(self.entityId, false);
	
	-- Listen for spawn events.
	self.spawnedEventId = GameplayNotificationId(self.entityId, "ParticlePostSpawnParams");
	self.spawnedHandler = GameplayNotificationBus.Connect(self, self.spawnedEventId);
	
    -- Create the state machine but don't start it yet.
    self.StateMachine = {}
    setmetatable(self.StateMachine, StateMachine);
	
	self.tickBusHandler = TickBus.Connect(self);
	
	self.debugMan = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("DebugManager"));
end

function bullet:OnDeactivate()
 	local swEnt = self.Properties.Shockwave.Shockwave;
 	if (self.performedFirstReset) then
 		StarterGameUtility.RestoreOriginalMaterial(swEnt);
 	end
	if (self.spawnedHandler ~= nil) then
		self.spawnedHandler:Disconnect();
		self.spawnedHandler = nil;	
	end
	if (self.physicsNotificationHandler ~= nil) then
		self.physicsNotificationHandler:Disconnect();
		self.physicsNotificationHandler = nil;
	end

end

function bullet:OnTick(deltaTime, timePoint)
	-- Start the state machine now.
    self.StateMachine:Start("Bullet", self.entityId, self, self.States, self.Properties.StateMachine.InitialState, self.Properties.StateMachine.DebugStateMachine);
	
	-- We only want this update for the first update.
	self.tickBusHandler:Disconnect();
	self.tickBusHandler = nil;
end

function bullet:Reset()
	self.life = 0.0;
	self.launchDir = Vector3(0.0, 0.0, 0.0);
	self.owner = EntityId();
	
	self.explosionTimer = 0.0;
	self.dissipateTimer = 0.0;
	
	-- Clear the list of things we've applied an impulse to.
	for i,h in ipairs(self.entitiesHit) do
		self.entitiesHit[i] = nil;
	end
	
	-- Disable the bullet mesh.
	MeshComponentRequestBus.Event.SetVisibility(self.entityId, false);
	
	-- Disable the physics.
	PhysicsComponentRequestBus.Event.DisablePhysics(self.entityId);
	
	-- Ensure the bullet's trail is disabled.
	ParticleComponentRequestBus.Event.Enable(self.entityId, false);
	
	local swEnt = self.Properties.Shockwave.Shockwave;
	if (self.performedFirstReset == false) then
		StarterGameUtility.ReplaceMaterialWithClone(swEnt);
		self.performedFirstReset = true;
	end
	
	-- Set the shockwave to be invisible.
	StarterGameUtility.SetShaderFloat(swEnt, "Opacity", 0.0);
	-- Set the shockwave's initial size.
	self:SetScale(swEnt, Vector3(self.Properties.Range.Initial));
	
	-- Instead of deleting, just move away.
	local tm = TransformBus.Event.GetWorldTM(self.entityId);
	tm:SetTranslation(tm:GetTranslation() + Vector3(0.0, 0.0, -1000.0));
	TransformBus.Event.SetWorldTM(self.entityId, tm);
	
	if (self.physicsNotificationHandler ~= nil) then
		self.physicsNotificationHandler:Disconnect();
		self.physicsNotificationHandler = nil;
	end
end

function bullet:JustFired()
	self.life = 0.0;
	self.explosionTimer = 0.0;
	self.dissipateTimer = 0.0;
	
	-- Enable the bullet mesh.
	MeshComponentRequestBus.Event.SetVisibility(self.entityId, true);
	
	-- Enable the physics.
	PhysicsComponentRequestBus.Event.EnablePhysics(self.entityId);
	-- Get and set the direction the bullet should travel in.
	PhysicsComponentRequestBus.Event.SetVelocity(self.entityId, self.launchDir * self.Properties.Speed);
	
	-- Enable the bullet's trail.
	ParticleComponentRequestBus.Event.Enable(self.entityId, true);
	
	-- Set the shockwave to be invisible.
	StarterGameUtility.SetShaderFloat(self.Properties.Shockwave.Shockwave, "Opacity", 0.0);
	-- Set the shockwave's initial size.
	self:SetScale(self.Properties.Shockwave.Shockwave, Vector3(self.Properties.Range.Initial));
	
	-- Listen for collisions.
	if (self.physicsNotificationHandler == nil) then
		self.physicsNotificationHandler = PhysicsComponentNotificationBus.Connect(self, self.entityId);
	end
end

function bullet:UpdateFired(deltaTime)
	self.life = self.life + deltaTime;
	-- If the bullet has lived long enough then blow up.
	if (self.life >= self.Properties.Lifespan) then
		self:Detonate(nil);
	end
end

function bullet:OnCollision(data)
	if (data and data ~= nil) then
		local player = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("PlayerCharacter"));
		--Debug.Log("Collision surfaces " .. data.surfaces[1] .. " " .. data.surfaces[2]);
		if (data.entity ~= player and data.surfaces[2] ~= self.ignoreSurfaceId) then
			--Debug.Log("Collided with " .. tostring(data.entity) .. " (" .. tostring(StarterGameUtility.GetEntityName(data.entity)) .. ") at " .. tostring(data.position));
			
			self:Detonate(data);
		end
	end
	
	--Debug.Log("Collision at: " .. tostring(data.position.x) .. " - " .. tostring(data.position.y) .. " - " .. tostring(data.position.z));
end

function bullet:Detonate(data)

	-- Disconnect from the physics notifications because we don't care about collisions anymore.
	if (self.physicsNotificationHandler ~= nil) then
		self.physicsNotificationHandler:Disconnect();
		self.physicsNotificationHandler = nil;
	end

	-- Disable the bullet mesh.
	MeshComponentRequestBus.Event.SetVisibility(self.entityId, false);
	-- Disable the bullet particle.
	ParticleComponentRequestBus.Event.Enable(self.entityId, false);
	-- Disable the physics.
	PhysicsComponentRequestBus.Event.DisablePhysics(self.entityId);
	
	-- Create the explosion particle.
	local particleManager = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("ParticleManager"));
	if (particleManager == nil or particleManager:IsValid() == false) then
		Debug.Assert("Invalid particle manager.");
	end
	local params = ParticleSpawnerParams();
	params.transform = TransformBus.Event.GetWorldTM(self.entityId);
	params.event = "SpawnLauncherExplosion";
	params.attachToEntity = false;
	local pmEventId = GameplayNotificationId(particleManager, "SpawnParticleEvent");
	GameplayNotificationBus.Event.OnEventBegin(pmEventId, params);
	
	-- Create the explosion decal.
	if (data ~= nil) then
		local paramsDecal = ParticleSpawnerParams();
		paramsDecal.event = "SpawnDecalLauncherShot";
		paramsDecal.transform = MathUtils.CreateLookAt(data.position, data.position + data.normal, AxisType.ZPositive);
		paramsDecal.surfaceType = data.surfaces[2];
		paramsDecal.attachToEntity = data.entity:IsValid();
		if (paramsDecal.attachToEntity == true) then
			paramsDecal.targetId = data.entity;
		end
		
		-- Override the attachment if the entity doesn't exist.
		if (paramsDecal.attachToEntity == true) then
			if (not paramsDecal.targetId:IsValid()) then
				paramsDecal.attachToEntity = false;
				Debug.Log("The decal was meant to follow an entity, but it doesn't have one assigned.");
			end
		end
	
		GameplayNotificationBus.Event.OnEventBegin(pmEventId, paramsDecal);
	end
	
	self.StateMachine:GotoState("Exploding");
end

function bullet:UpdateExplosion(deltaTime)
	local progress = self.explosionTimer / self.Properties.Range.ExpansionDuration;
	progress = progress * progress;
	
	-- Perform progressively large spherecasts so that we only apply impulses to things
	-- inside the shockwave area as it gets larger.
	local pos = TransformBus.Event.GetWorldTM(self.entityId):GetPosition();
	local impulseRange = utils.Lerp(self.Properties.Range.Initial, self.Properties.Range.Max, progress);
	local maxRangeSq = self.Properties.Range.Max * self.Properties.Range.Max;
	local query = PhysicalEntityTypes.Static + PhysicalEntityTypes.Dynamic + PhysicalEntityTypes.Living;
	local hits = PhysicsSystemRequestBus.Broadcast.GatherPhysicalEntitiesAroundPoint(pos, impulseRange, query);
	local numHits = #hits;
	for i=1,numHits,1 do
		local hitEntityId = hits[i];
		-- Ignore this entity if we dealt with it on a previous frame.
		for j in ipairs(self.entitiesHit) do
			if (hitEntityId == self.entitiesHit[j]) then
				hitEntityId = nil;
			end
		end
		if (hitEntityId == self.entityId) then
			hitEntityId = nil;
		end
		
		if (hitEntityId ~= nil and hitEntityId:IsValid()) then
			-- Apply an impulse to it.
			local hitPos = TransformBus.Event.GetWorldTM(hitEntityId):GetTranslation();
			local dir = hitPos - pos;
			local dist = dir:GetLengthSq() / maxRangeSq;
			-- This distance should now be between 0.0 and 1.0 (so we can lerp the strength of
			-- the impulse. If the distance is greater than 1.0 then it means the entity is
			-- actually outside the range.
			if (dist > 0.0 and dist < 1.0) then
				-- deal damage to other things
				local godMode = false;
				if (self.debugMan ~= nil and self.debugMan:IsValid()) then
					godMode = DebugManagerComponentRequestsBus.Event.GetDebugBool(self.debugMan, "GodMode");
				end
				
				local hitPlayer = StarterGameUtility.EntityHasTag(hitEntityId, "PlayerCharacter");
				if( (self.owner ~= hitEntityId) and not ((godMode == true) and hitPlayer)) then
					local damageEventId = GameplayNotificationId(hitEntityId, self.Properties.Events.DealDamage);
					GameplayNotificationBus.Event.OnEventBegin(damageEventId, -self.Properties.Firepower.Damage);
				end
				
				-- If it's an A.I. then deal damage to it as well.
				if (StarterGameUtility.EntityHasTag(hitEntityId, "AICharacter")) then
					local params = GotShotParams();
					params.damage = self.Properties.Firepower.Damage;
					params.assailant = self.owner;
					params.immediatelyRagdoll = true;
					local eventId = GameplayNotificationId(hitEntityId, self.Properties.Events.GotShot);
					GameplayNotificationBus.Event.OnEventBegin(eventId, params);
				end
				
				if (not hitPlayer) then
					-- We need to invert the distance so that 1.0 is at the center (and thus has the
					-- strongest impulse applied to it).
					local imp = (dir:GetNormalized() * self.Properties.Firepower.ForceMultiplier) * (1.0 - dist);
					PhysicsComponentRequestBus.Event.AddImpulseAtPoint(hitEntityId, imp, pos);
				end
			end
			
			-- Store this entity ID so we don't do anything to it next frame.
			table.insert(self.entitiesHit, hitEntityId);
		end
	end
	
	-- Update the shockwave.
	self:UpdateShockwave(deltaTime, progress, impulseRange);
end

function bullet:UpdateShockwave(deltaTime, progress, range)
	local swEnt = self.Properties.Shockwave.Shockwave;
	local opacityStart, opacityEnd;
	local diffuseStart, diffuseEnd;
	
	-- If the range is nil then it means the explosion has finished and we're now
	-- doing a slow dissipate.
	if (progress == nil and range == nil) then
		progress = self.dissipateTimer / self.Properties.Shockwave.Dissipation.ExtraDuration;
		
		range = self.Properties.Range.Max + (self.Properties.Shockwave.Dissipation.ExtraDistance * progress);
		
		opacityStart = self.Properties.Shockwave.OpacityEnd;
		opacityEnd = self.Properties.Shockwave.Dissipation.OpacityFinal;
		
		diffuseStart = self.Properties.Shockwave.DiffuseEnd;
		diffuseEnd = self.Properties.Shockwave.Dissipation.DiffuseFinal;
	else
		opacityStart = self.Properties.Shockwave.OpacityInitial;
		opacityEnd = self.Properties.Shockwave.OpacityEnd;
		
		diffuseStart = self.Properties.Shockwave.DiffuseInitial;
		diffuseEnd = self.Properties.Shockwave.DiffuseEnd;
	end
	
	-- Set the new size of the shockwave.
	self:SetScale(swEnt, Vector3(range));
	
	-- Rotate the shockwave.
	self:Rotate(swEnt, self.Properties.Shockwave.RotationSpeed * deltaTime, 0);
	
	-- Set the opacity of the shockwave.
	local opacity = utils.Lerp(opacityStart, opacityEnd, progress);
	StarterGameUtility.SetShaderFloat(swEnt, "Opacity", opacity);
	
	local diffuse = diffuseStart:Lerp(diffuseEnd, progress);
	StarterGameUtility.SetShaderVec3(swEnt, "Diffuse", diffuse);
end

function bullet:SetScale(entity, newScale)
	-- Check the entity is valid.
	if (not entity:IsValid()) then
		return;
	end
	
	local tm = TransformBus.Event.GetWorldTM(entity);
	local oldScale = tm:RetrieveScale();
	tm:MultiplyByScale(newScale / oldScale);
	TransformBus.Event.SetWorldTM(entity, tm);
end

function bullet:Rotate(entity, rotation, axis)
	local rMat;
	if (axis == 0) then
		rMat = Transform.CreateRotationX(rotation);
	elseif (axis == 1) then
		rMat = Transform.CreateRotationY(rotation);
	else
		rMat = Transform.CreateRotationZ(rotation);
	end
	
	local tm = TransformBus.Event.GetWorldTM(entity);
	tm = tm * rMat;
	TransformBus.Event.SetWorldTM(entity, tm);
end

function bullet:OnEventBegin(value)

	if (GameplayNotificationBus.GetCurrentBusId() == self.spawnedEventId) then
		self.launchDir = value.impulse;
		self.owner = value.ownerId;
		
		self.StateMachine:GotoState("Fired");
	end
	
end


return bullet;
