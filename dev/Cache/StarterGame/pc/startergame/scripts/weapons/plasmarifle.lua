require "scripts/Weapons/Weapon"

local plasmarifle =
{
	Properties = {
	}
}

PopulateProperties(plasmarifle.Properties);

plasmarifle.Properties.Firepower.Range = { default = 1000.0, description = "The range that the bullets can hit something.", suffix = " m" };
plasmarifle.Properties.Firepower.Damage = { default = 10.0, description = "The amount of damage a single shot does." };
plasmarifle.Properties.Firepower.ForceMultiplier = { default = 400.0, description = "The strength of the impulse." };
plasmarifle.Properties.Laser =
	{
		StartEffect = { default = "SpawnLaserStart" },
		EndEffect = { default = "SpawnLaserEnd" },
	};
plasmarifle.Properties.Events.GotShot = "GotShotEvent";
plasmarifle.Properties.Events.DealDamage = "HealthDeltaValueEvent";
plasmarifle.Properties.EndOfBarrel = { default = EntityId() };
plasmarifle.Properties.Events.Owner = "EventOwner";

function plasmarifle:SendEventToParticle(event, from, to, targetToFollow)

	local params = ParticleSpawnerParams();
	params.transform = MathUtils.CreateLookAt(from, to, AxisType.YPositive);
	params.event = event;
	params.targetId = targetToFollow;
	params.attachToEntity = targetToFollow:IsValid();
	
	GameplayNotificationBus.Event.OnEventBegin(self.particleSpawnEventId, params);

end
function plasmarifle:DoFirstUpdate()
	local particleMan = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("ParticleManager"));
	self.particleSpawnEventId = GameplayNotificationId(particleMan, "SpawnParticleEvent");
	self.debugMan = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("DebugManager"));
end
function plasmarifle:DoFire(useForwardForAiming, playerOwned)
	-- Perform a raycast from the gun into the world. If the ray hits something then apply an
	-- impulse to it. This weapon's bullet won't have physics because it's the raycast that'll
	-- apply the impulse.
	local mask = PhysicalEntityTypes.Static + PhysicalEntityTypes.Dynamic + PhysicalEntityTypes.Living;
	local camTm = TransformBus.Event.GetWorldTM(TagGlobalRequestBus.Event.RequestTaggedEntities(self.cameraFinderTag));
	local camPos = camTm:GetTranslation();
	local endOfBarrelPos = TransformBus.Event.GetWorldTM(self.Properties.EndOfBarrel):GetTranslation();
	local dir;
	local hits = nil;
	local rch = nil;
	local hasBlockingHit = false;
	
	local rayCastConfig = RayCastConfiguration();
	rayCastConfig.maxHits = 10;
	rayCastConfig.physicalEntityTypes = mask;
	rayCastConfig.piercesSurfacesGreaterThan = 13;
	rayCastConfig.maxDistance = self.Properties.Firepower.Range;
	
	-- Always use the weapon's direction for A.I.
	if (not playerOwned or useForwardForAiming == true) then
		dir = self.weapon:GetJitteredDirection(TransformBus.Event.GetWorldTM(self.entityId):GetColumn(2):GetNormalized());
		rayCastConfig.origin = endOfBarrelPos;
		rayCastConfig.direction =  dir;
		hits = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfig);
		hasBlockingHit = hits:HasBlockingHit();
		rch = hits:GetBlockingHit();
	else
		rayCastConfig.origin = camPos;
		rayCastConfig.direction =  camTm:GetColumn(1);
		hits = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfig);	
		hasBlockingHit = hits:HasBlockingHit();
		rch = hits:GetBlockingHit();
		local endPoint = nil;
		if (hasBlockingHit) then
			endPoint = rch.position;
		else
			-- If the camera's ray didn't hit anything then the gun's raycast should be to the
			-- maximum distance.
			endPoint = camPos + (camTm:GetColumn(1) * self.Properties.Firepower.Range);
		end
		
		-- Now do a ray from the gun to see if there's anything in the way.
		local offsetVector = endPoint - endOfBarrelPos;
		local offsetDistance = offsetVector:GetLength();
		dir = self.weapon:GetJitteredDirection(offsetVector / offsetDistance);
		
		rayCastConfig.origin = endOfBarrelPos;
		rayCastConfig.direction = dir;
		rayCastConfig.maxDistance = offsetDistance;
		local gunHits = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfig);
		-- If the gun's raycast hit something then it means there's something in the way between the gun and
		-- the camera's target. This means we want to override the rch variable with this new information.
		-- If we didn't hit anything then we want to use the camera's rch information (as it may be that the
		-- gun's raycast fell short of hitting the camera's target because we're using its hit position as
		-- the maximum distance).
		if (gunHits:HasBlockingHit()) then
			hasBlockingHit = true;
			rch = gunHits:GetBlockingHit();
		end
	end
	
	-- Apply an impulse if we hit a physics object.
	if (hasBlockingHit) then
		-- send damage event, make sure that i cannot hurt myself
		
		local godMode = false;
		if (self.debugMan ~= nil and self.debugMan:IsValid()) then
			godMode = DebugManagerComponentRequestsBus.Event.GetDebugBool(self.debugMan, "GodMode");
		end
		
		if (rch.entityId:IsValid() and ((rch.entityId ~= self.Properties.Owner) and not ((godMode == true) and StarterGameUtility.EntityHasTag(hitEntityId, "PlayerCharacter"))) ) then
			local eventId = GameplayNotificationId(rch.entityId, self.Properties.Events.DealDamage);
			--Debug.Log("Damaging [" .. tostring(rch.entityId) .. "] for " .. self.Properties.Firepower.Damage .. " by [" .. tostring(self.Properties.Owner) .. "] message \"" .. self.Properties.Events.DealDamage .. "\", combinedID == " .. tostring(eventId));
			GameplayNotificationBus.Event.OnEventBegin(eventId, -self.Properties.Firepower.Damage);
		end
	
		if (rch.entityId:IsValid() and (StarterGameUtility.EntityHasTag(rch.entityId, "PlayerCharacter") or StarterGameUtility.EntityHasTag(rch.entityId, "AICharacter"))) then
			-- We don't want to apply an impulse to player or A.I. characters.
			local params = GotShotParams();
			params.damage = self.Properties.Firepower.Damage;
			params.direction = dir;
			params.assailant = self.Properties.Owner;
			local eventId = GameplayNotificationId(rch.entityId, self.Properties.Events.GotShot);
			GameplayNotificationBus.Event.OnEventBegin(eventId, params);
		else
			--Debug.Log("Applying impulse to " .. tostring(rch.entityId) .. " with force " .. dir.x .. ", " .. dir.y .. ", " .. dir.z);
			PhysicsComponentRequestBus.Event.AddImpulseAtPoint(rch.entityId, dir * self.Properties.Firepower.ForceMultiplier, rch.position);
		end
	end
	
	-- Render the line.
	local rayEnd;
	if (hasBlockingHit) then
		rayEnd = rch.position;
	else
		-- If the raycast didn't hit anything then put the hit position as the
		-- barrel position + the range.
		rayEnd = endOfBarrelPos + (dir * self.Properties.Firepower.Range);
	end
	local rayStart = endOfBarrelPos;
	LineRendererRequestBus.Event.SetStartAndEnd(self.entityId, rayStart, rayEnd, camPos);
	
	-- Spawn the particle effects at the start and end (if a hit occured) of the line.
	--Debug.Log("Direction: " .. tostring(dir));
	self:SendEventToParticle(self.Properties.Laser.StartEffect, rayStart, rayEnd, self.entityId);
	if (hasBlockingHit) then
		self:SendEventToParticle(self.Properties.Laser.EndEffect, rayEnd, rayStart, EntityId());
		
		local particleManager = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("ParticleManager"));
		if (particleManager == nil or particleManager:IsValid() == false) then
			Debug.Assert("Invalid particle manager.");
		end
		
		local params = ParticleSpawnerParams();
		params.event = "SpawnDecalRifleShot";
		params.transform = MathUtils.CreateLookAt(rayEnd, rayEnd + rch.normal, AxisType.ZPositive);
		params.surfaceType = StarterGameUtility.GetSurfaceType(rayEnd - (dir * 0.5), dir);
		params.attachToEntity = rch.entityId:IsValid();
		if (params.attachToEntity == true) then
			params.targetId = rch.entityId;
		end
		
		-- Override the attachment if the entity doesn't exist.
		if (params.attachToEntity == true) then
			if (not params.targetId:IsValid()) then
				params.attachToEntity = false;
				Debug.Log("The decal was meant to follow an entity, but it doesn't have one assigned.");
			end
		end
		
		--Debug.Log("Decal surface: " .. tostring(params.surfaceType));
		local pmEventId = GameplayNotificationId(particleManager, "SpawnParticleEvent");
		GameplayNotificationBus.Event.OnEventBegin(pmEventId, params);
	end
		
	-- This probably wants to be changed to a struct rather than an entityId so
	-- we can provide other information such as target, sound range, etc.
	GameplayNotificationBus.Event.OnEventBegin(self.shotFiredEventId, self.Properties.Owner);
end
function plasmarifle:OnActivate()
	self.shotFiredEventId = GameplayNotificationId(EntityId(), "ShotsFired");	

	-- Use this to get the camera information when firing. It saves making an entity property
	-- and linking the weapon to a specific camera entity.
	-- Note: this only returns the LAST entity with this tag, so make sure there's only one
	-- entity with the "PlayerCamera" tag otherwise weird stuff might happen.
	self.cameraFinderTag = Crc32("PlayerCamera");
	self.weapon = weapon:new();
	self.weapon:OnActivate(self, self.entityId, self.Properties);
end

function plasmarifle:OnDeactivate()
	self.weapon:OnDeactivate();
end

return plasmarifle;