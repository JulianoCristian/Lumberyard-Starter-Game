local StateMachine = require "scripts/common/StateMachine"
local utilities = 
{
	LerpAimingAnim = function(weaponcontroller, timeLeft, targetValue, deltaTime)
		local targetDiff = targetValue - weaponcontroller.shootingParamValue;
		if(deltaTime >= timeLeft) then
			deltaTime = timeLeft;
		end
		local timeFrac = deltaTime / timeLeft;
		weaponcontroller.shootingParamValue = weaponcontroller.shootingParamValue + (timeFrac * targetDiff);
		return timeLeft - deltaTime;
	end
}
local weaponcontroller = 
{
    Properties = 
    {
		Stats =
		{
			EnergyMax = { default = 100, description = "Max Energy of the player." },
			Energy = { default = 100, description = "Current Energy of the player." }, 
			EnergyRegen = { default = 25, description = "amount of enegy i regen a second.", suffix = " sec" },
			EnergyRegenDelay = { default = 0.5, description = "Delay in seconds after firing that i will start to regen." },
			EnergyRegenOverheat = { default = 1.5, description = "Additional Delay in seconds to wait if i try to use enegy when i have none / not enough." },
		},
		
		UIMessages = 
		{
			SetEnergyMessage = { default = "SetEnergyEvent", description = "The event used to set the Energy percent (0%-100%)" },
			SetHideUIMessage = { default = "HideUIEvent", description = "The event used to set the whole UI visible / invisible" },
			SetCrosshairStatusMessage = { default = "SetCrosshairStatusEvent", description = "set the visible crosshair type" },
		},
		
		-- The weapons to be used.
		Weapons =
		{

			GenericEvents =
			{
				Fire = "EventFire";
				Reload = "EventReload";
				UseWeaponForwardForAiming = "EventUseWeaponForwardForAiming";
				OwnerDied = "HealthEmpty";
			},
			-- The bone that the weapons will attach to.
			-- This may need to become weapon-specific if we end up having weird weapons (e.g. shoulder-mounted).
			AimDelay = { default = 2.5, description = "Time that the player should keep aiming after firing" },
			BeginAimingLerpTime = {default = 0.1, description = "Time that the character takes to start aiming at target after pressing fire" },
			EndAimingLerpTime = {default = 0.3, description = "Time that the character takes to holster the waapon after AimDelay elapses" },
			MaxUpAimAngle = {default = 55, description = "Maximum angle that the character can aim upwards in degrees."},
			MaxDownAimAngle = {default = 35, description = "Maximum angle that the character can aim downwards in degrees."},
			MaxHorizontalAimAngle = {default = 155, description = "Maximum angle in degrees that the player can aim behind them relative to the forward direction."},
			
		},
        InitialState = "Down",
        DebugStateMachine = false,
    },
    States = 
    {
		-- Weapon is down
        Down = 
        {      
            OnEnter = function(self, sm)
				sm.UserData.shootingParamValue = 0.0;
				sm.UserData.isAiming = false;
            end,
            OnExit = function(self, sm)
				sm.UserData.isAiming = true;
            end,            
            OnUpdate = function(self, sm, deltaTime)
            end,
            Transitions =
            {
				Rising = 
				{
                    Evaluate = function(state, sm)
						return sm.UserData.WantsToShoot;
                    end	
				},
				Dead = 
				{
					Evaluate = function(state, sm)
						return sm.UserData.IsOwnerDead;
					end
				}
            },
        },
		-- Weapon is coming up after fire was pressed
        Rising = 
        {      
            OnEnter = function(self, sm)
				self.aimTimer = sm.UserData.Properties.Weapons.AimDelay;
				AimIKComponentRequestBus.Event.EnableAimIK(sm.EntityId, true);
				self.aimLerpTime = sm.UserData.Properties.Weapons.BeginAimingLerpTime;
				self.aimLerpTarget = 1.0;
				self.aimTimer = 0.0;
            end,
            OnExit = function(self, sm)

            end,            
            OnUpdate = function(self, sm, deltaTime)
				if(self.aimLerpTime > 0) then
					self.aimLerpTime = utilities.LerpAimingAnim(sm.UserData, self.aimLerpTime, self.aimLerpTarget, deltaTime, nil);
				end
            end,           
            Transitions =
            {
				RisingInBuffer = 
				{
                    Evaluate = function(state, sm)
						return state.aimLerpTime == 0;
                    end	
				},
				Dead = 
				{
					Evaluate = function(state, sm)
						return sm.UserData.IsOwnerDead;
					end
				}
            },
        },
		-- Small buffer after raising gun to ensure AimIK has caught up
		RisingInBuffer = 
		{
			OnEnter = function(self, sm)
				self.bufferTimeLeft = 0.1;
            end,
            OnExit = function(self, sm)
				sm.UserData:TellWeaponToFire();
            end,            
            OnUpdate = function(self, sm, deltaTime)
				self.bufferTimeLeft = self.bufferTimeLeft - deltaTime;
			end,
            Transitions =
            {
				UpFireRequested = 
				{
                    Evaluate = function(state, sm)
						return state.bufferTimeLeft <= 0 and sm.UserData.WantsToShoot == true;
                end	
				},
				UpFireNotRequested = 
				{
                    Evaluate = function(state, sm)
						return state.bufferTimeLeft <= 0 and sm.UserData.WantsToShoot == false;
	                end	
				},
				Dead = 
				{
					Evaluate = function(state, sm)
						return sm.UserData.IsOwnerDead;
					end
				}
            },
		},
		-- Weapon up and ready to fire
        UpFireRequested = 
        {      
            OnEnter = function(self, sm)
            end,
            OnExit = function(self, sm)
            end,            
            OnUpdate = function(self, sm, deltaTime)
				sm.UserData:TellWeaponToFire();
            end,
            Transitions =
            {
				UpFireNotRequested = 
				{
                    Evaluate = function(state, sm)
						return sm.UserData.WantsToShoot == false;
                    end	
				},
				Dead = 
				{
					Evaluate = function(state, sm)
						return sm.UserData.IsOwnerDead;
					end
				}
            },
        },
		-- Weapon up and ready to fire
        UpFireNotRequested = 
        {      
            OnEnter = function(self, sm)
				self.aimTimeLeft = sm.UserData.Properties.Weapons.AimDelay;
            end,
            OnExit = function(self, sm)
            end,            
            OnUpdate = function(self, sm, deltaTime)
				self.aimTimeLeft = self.aimTimeLeft - deltaTime;
            end,
            Transitions =
            {
				UpFireRequested = 
				{
                    Evaluate = function(state, sm)
						return sm.UserData.WantsToShoot == true;
	                end	
				},
				Lowering = 
				{
                    Evaluate = function(state, sm)
						return state.aimTimeLeft <= 0;
                    end	
				},
				Dead = 
				{
					Evaluate = function(state, sm)
						return sm.UserData.IsOwnerDead;
					end
				}
            },
        },
		-- Weapon is lowering
        Lowering = 
        {      
            OnEnter = function(self, sm)
				AimIKComponentRequestBus.Event.EnableAimIK(sm.EntityId, false);
				self.aimLerpTime = sm.UserData.Properties.Weapons.EndAimingLerpTime;
				self.aimLerpTarget = 0;
				self.aimLerpComplete = nil;
				sm.UserData.isAiming = false;
            end,
            OnExit = function(self, sm)
            end,            
            OnUpdate = function(self, sm, deltaTime)
				if(self.aimLerpTime > 0) then
					self.aimLerpTime = utilities.LerpAimingAnim(sm.UserData, self.aimLerpTime, self.aimLerpTarget, deltaTime, self.aimLerpComplete);
				end
            end,
            Transitions =
            {
				Down = 
				{
                    Evaluate = function(state, sm)
						return state.aimLerpTime == 0;
					end	
				},
				Dead = 
				{
					Evaluate = function(state, sm)
						return sm.UserData.IsOwnerDead;
					end
				}

            },
        },	
		Dead =
		{
			OnAnimationEvent = function(self, evName)
				if(evName == "SwitchRagdoll") then
					self.switchRagdoll = true;
				end
			end,
			OnEnter = function(self, sm)
				self.switchRagdoll = false;
				sm.UserData.WantsToShoot = false;
				self.weaponTransform = TransformBus.Event.GetWorldTM(sm.UserData.weapon);
				-- Stop aiming
				AimIKComponentRequestBus.Event.EnableAimIK(sm.EntityId, false);
				self.aimLerpTime = sm.UserData.Properties.Weapons.EndAimingLerpTime;
				self.aimLerpTarget = 0;
				self.aimLerpComplete = nil;
				sm.UserData.isAiming = false;
			end,
            OnUpdate = function(self, sm, deltaTime)
				if(self.switchRagdoll == true) then
					self.switchRagdoll = false;
					AttachmentComponentRequestBus.Event.Detach(sm.UserData.weapon);
					local currentWeaponTransform = TransformBus.Event.GetWorldTM(sm.UserData.weapon);
					local prevRotation = Quaternion.CreateFromTransform(self.weaponTransform);
					local currRotation = Quaternion.CreateFromTransform(currentWeaponTransform);
					local prevPosition = self.weaponTransform:GetTranslation();
					local currPosition = currentWeaponTransform:GetTranslation();
					local offset = currPosition - prevPosition;
					local velocity = offset / deltaTime;
					PhysicsComponentRequestBus.Event.EnablePhysics(sm.UserData.weapon);
					PhysicsComponentRequestBus.Event.SetVelocity(sm.UserData.weapon, velocity);
				end
				if(self.aimLerpTime > 0) then
					self.aimLerpTime = utilities.LerpAimingAnim(sm.UserData, self.aimLerpTime, self.aimLerpTarget, deltaTime, self.aimLerpComplete);
				end
				self.weaponTransform = TransformBus.Event.GetWorldTM(sm.UserData.weapon);				
            end,
            Transitions =
            {
            },
		},
	},
	ShootingBlendParam = eMotionParamID_BlendWeight2, -- Blend parameter index to determine if shooting
	MaxAimRange = 1000.0, -- Range to do ray cast when detecting aim location
}

--------------------------------------------------
-- Component behavior
--------------------------------------------------

function weaponcontroller:OnActivate()    
	AudioTriggerComponentRequestBus.Event.Play(self.entityId);
	
	-- Enable and disable events
	self.enableEventId = GameplayNotificationId(self.entityId, "Enable");
	self.enableHandler = GameplayNotificationBus.Connect(self, self.enableEventId);
	self.disableEventId = GameplayNotificationId(self.entityId, "Disable");
	self.disableHandler = GameplayNotificationBus.Connect(self, self.disableEventId);

	-- Input listeners (weapon).
	self.weaponFirePressedEventId = GameplayNotificationId(self.entityId, "WeaponFirePressed");
	self.weaponFirePressedHandler = GameplayNotificationBus.Connect(self, self.weaponFirePressedEventId);
	self.weaponFireReleasedEventId = GameplayNotificationId(self.entityId, "WeaponFireReleased");
	self.weaponFireReleasedHandler = GameplayNotificationBus.Connect(self, self.weaponFireReleasedEventId);
	self.ownerDiedEventId = GameplayNotificationId(self.entityId, self.Properties.Weapons.GenericEvents.OwnerDied)
	self.ownerDiedHandler = GameplayNotificationBus.Connect(self, self.ownerDiedEventId);

	-- Tick needed to detect aim timeout
    self.tickBusHandler = TickBus.Connect(self);
	self.performedFirstUpdate = false;
	self.setupComplete = false;

    self.Fragments = {};

	-- AimIK setup
	AimIKComponentRequestBus.Event.EnableAimIK(self.entityId, false);
	AimIKComponentRequestBus.Event.SetAimIKLayer(self.entityId, 3);
	AimIKComponentRequestBus.Event.SetAimIKPolarCoordinatesMaxRadiansPerSecond(self.entityId, Vector2(24.0, 24.0));
	AimIKComponentRequestBus.Event.SetAimIKPolarCoordinatesSmoothTimeSeconds(self.entityId, 0.0);
	AimIKComponentRequestBus.Event.SetAimIKFadeOutTime(self.entityId, self.Properties.Weapons.EndAimingLerpTime);
	AimIKComponentRequestBus.Event.SetAimIKFadeInTime(self.entityId, self.Properties.Weapons.BeginAimingLerpTime);
	self.Fragments.Aiming = MannequinRequestsBus.Event.QueueFragment(self.entityId, 1, "Aiming", "", false);
	self.WantsToShoot = false;
	self.IsTargetingEnemy = false;
	self.isAiming = false;
	self.IsOwnerDead = false;

	self.EnergyRegenTimer = 0;
	self.minHorizontalAimDot = Math.Cos(Math.DegToRad(self.Properties.Weapons.MaxHorizontalAimAngle));
	self.maxVerticalAimDot = Math.Sin(Math.DegToRad(self.Properties.Weapons.MaxUpAimAngle));
	self.minVerticalAimDot = -Math.Sin(Math.DegToRad(self.Properties.Weapons.MaxDownAimAngle));

	-- weapon response listeners.
	self.weaponFireSuccessEventId = GameplayNotificationId(self.entityId, "WeaponFireSuccess");
	self.weaponFireSuccessHandler = GameplayNotificationBus.Connect(self, self.weaponFireSuccessEventId);
	self.weaponFireFailEventId = GameplayNotificationId(self.entityId, "WeaponFireFail");
	self.weaponFireFailHandler = GameplayNotificationBus.Connect(self, self.weaponFireFailEventId);

	self.onSetupNewWeaponEventId = GameplayNotificationId(self.entityId, "OnSetupNewWeapon");
	self.onSetupNewWeaponHandler = GameplayNotificationBus.Connect(self, self.onSetupNewWeaponEventId);
	self.shootingParamValue = 0;
	
    -- Create and start our state machine.
    self.StateMachine = {}
    setmetatable(self.StateMachine, StateMachine);
    self.StateMachine:Start("Weapon", self.entityId, self, self.States, self.Properties.InitialState, self.Properties.DebugStateMachine)
	-- Direction from aim origin to do raycast to find aim target
	self.aimDirection = Vector3(0.0, 0.0, 1.0); 
	-- Origin of raycast to find aim target
	self.aimOrigin = Vector3(0,0,0);
	self.setAimDirectionEventId = GameplayNotificationId(self.entityId, "SetAimDirection");
	self.setAimDirectionHandler = GameplayNotificationBus.Connect(self, self.setAimDirectionEventId);
	self.setAimOriginEventId = GameplayNotificationId(self.entityId, "SetAimOrigin");
	self.setAimOriginHandler = GameplayNotificationBus.Connect(self, self.setAimOriginEventId);
	
	self.requestAimUpdateEventId = GameplayNotificationId(self.entityId, "RequestAimUpdate");
end

function weaponcontroller:OnDeactivate()
	self.weaponFirePressedHandler:Disconnect();
	self.weaponFirePressedHandler  = nil;
	self.weaponFireReleasedHandler:Disconnect();
	self.weaponFireReleasedHandler = nil;
	self.onSetupNewWeaponHandler:Disconnect();
	self.onSetupNewWeaponHandler = nil;
	self.tickBusHandler:Disconnect();
	self.tickBusHandler = nil;
	
	if (self.enableHandler ~= nil) then
		self.enableHandler:Disconnect();
		self.enableHandler = nil;
	end
	if (self.disableHandler ~= nil) then
		self.disableHandler:Disconnect();
		self.disableHandler = nil;	
	end
end


function weaponcontroller:CheckCanHitTarget(target)
	if(self.weapon == nil) then
		return false;
	else
		local weaponTm = TransformBus.Event.GetWorldTM(self.weapon);
		local weaponForward = weaponTm:GetColumn(2):GetNormalized();
		local canHitTargetVertical = (weaponForward.z <= self.maxVerticalAimDot) and (weaponForward.z >= self.minVerticalAimDot);
		local tm = TransformBus.Event.GetWorldTM(self.entityId);
		weaponForward.z = 0;
		weaponForward:Normalize();
		local facing = tm:GetColumn(1):GetNormalized();
		local dot = facing:Dot(weaponForward);
		local canHitTargetHorizontal = dot > self.minHorizontalAimDot;
		return canHitTargetHorizontal and canHitTargetVertical;
	end
end

function weaponcontroller:UpdateAim()
	
	if (self.setupComplete) then
	
		local rayCastConfig = RayCastConfiguration();
		rayCastConfig.origin = self.aimOrigin;
		rayCastConfig.direction =  self.aimDirection;
		rayCastConfig.maxDistance = self.MaxAimRange;
		rayCastConfig.maxHits = 10;
		rayCastConfig.physicalEntityTypes = PhysicalEntityTypes.All;
		rayCastConfig.piercesSurfacesGreaterThan = 13;
		local hits = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfig);
		
		local target;
		local targetingEnemy = false;
	
		if(hits:HasBlockingHit()) then
			local hit = hits:GetBlockingHit();
			
			if (hit.entityId == self.entityId) then
				target = self.aimOrigin + self.aimDirection * self.MaxAimRange;
			else
			target = hit.position;
			end
			
			-- if im looking at an enemy, then i need to change the cursor
			if (hit.entityId:IsValid() and StarterGameUtility.EntityHasTag(hit.entityId, "AICharacter")) then
				--Debug.Log("Looking At enemy");
				targetingEnemy = true;
			end
		else
			target = self.aimOrigin + self.aimDirection * self.MaxAimRange;
		end
		
		if(self.IsTargetingEnemy ~= targetingEnemy) then
			self.IsTargetingEnemy = targetingEnemy;
			--Debug.Log("TargetChanged");
			local value = 0;
			if (targetingEnemy) then
				value = 1;
			end
			GameplayNotificationBus.Event.OnEventBegin(self.SetCrosshairStatusEventId, value);
		end
		
		AimIKComponentRequestBus.Event.SetAimIKTarget(self.entityId, target);
	
		-- player always fires directly at reticule, even if AimIK cannot point the weapon that way
		local canHitTarget = self.isPlayerWeapon or self:CheckCanHitTarget(target);
		local useWeaponForwardForAiming = 1.0;
		if(canHitTarget == true) then
			useWeaponForwardForAiming = 0.0;
		end
		
		GameplayNotificationBus.Event.OnEventBegin(self.activeWeaponUseWeaponForwardForAimingEventId, useWeaponForwardForAiming);
	end
end

function weaponcontroller:OnSetupNewWeapon(weapon)
	self.weapon = weapon;
	self.activeWeaponFireEventId = GameplayNotificationId(weapon, self.Properties.Weapons.GenericEvents.Fire);
 	self.activeWeaponUseWeaponForwardForAimingEventId = GameplayNotificationId(weapon, self.Properties.Weapons.GenericEvents.UseWeaponForwardForAiming);
	self.activeWeaponReloadEventId = GameplayNotificationId(weapon, self.Properties.Weapons.GenericEvents.Reload);
	self.setupComplete = true;
end

function weaponcontroller:TellWeaponToFire()
	GameplayNotificationBus.Event.OnEventBegin(self.activeWeaponFireEventId, self.Properties.Stats.Energy);
end

function weaponcontroller:WeaponFireSuccess(value)
	self.FirstShotFired = true;
	local infiniteEnergy = false;
	if (self.debugMan ~= nil and self.debugMan:IsValid()) then
		infiniteEnergy = DebugManagerComponentRequestsBus.Event.GetDebugBool(self.debugMan, "InfiniteEnergy");
	end
	if (not infiniteEnergy) then
		self.Properties.Stats.Energy = self.Properties.Stats.Energy - value;
	end
	
	self.EnergyRegenTimer = self.Properties.Stats.EnergyRegenDelay;
	GameplayNotificationBus.Event.OnEventBegin(self.setEnergyEventId, 100 * self.Properties.Stats.Energy / self.Properties.Stats.EnergyMax);
	self.Fragments.Shoot = MannequinRequestsBus.Event.QueueFragment(self.entityId, 1, "Shoot", "", false);
end

function weaponcontroller:WeaponFireFail(value)
	self.FirstShotFired = true;
	self.EnergyRegenTimer = self.Properties.Stats.EnergyRegenDelay + self.Properties.Stats.EnergyRegenOverheat;
	
	-- FOR SOUND - depleated
	AudioTriggerComponentRequestBus.Event.ExecuteTrigger(self.entityId, "Play_HUD_energy_depleted");

end

function weaponcontroller:UpdateAiming(deltaTime)
	-- These AimIK settings need to be set here everyframe because of a late initialisation
	-- issue with the AimIKComponent which means putting them in 'OnActivate()' or the first
	-- 'OnTick()' is too early and they don't get registered for dynamic slices.
	AimIKComponentRequestBus.Event.SetAimIKLayer(self.entityId, 3);
	AimIKComponentRequestBus.Event.SetAimIKPolarCoordinatesMaxRadiansPerSecond(self.entityId, Vector2(24.0, 24.0));
	AimIKComponentRequestBus.Event.SetAimIKPolarCoordinatesSmoothTimeSeconds(self.entityId, 0.0);
	AimIKComponentRequestBus.Event.SetAimIKFadeOutTime(self.entityId, self.Properties.Weapons.EndAimingLerpTime);
	AimIKComponentRequestBus.Event.SetAimIKFadeInTime(self.entityId, self.Properties.Weapons.BeginAimingLerpTime);
	
	-- The player needs to update aiming every frame (for the crosshair) but A.I. only need
	-- to update when they want to shoot.
	if (self.isAiming or self.isPlayerWeapon) then
		self:UpdateAim();
	end

	CharacterAnimationRequestBus.Event.SetBlendParameter(self.entityId, self.ShootingBlendParam, self.shootingParamValue);	
end

function weaponcontroller:OnTick(deltaTime, timePoint)
	
	if (not self.performedFirstUpdate) then
		local uiElement = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("UIPlayer"));
		
		local playerId = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("PlayerCharacter"));
		self.isPlayerWeapon = (self.entityId == playerId);

		-- Initialise the weapon.
		self.SetCrosshairStatusEventId = GameplayNotificationId(self.entityId, self.Properties.UIMessages.SetCrosshairStatusMessage);
		
		self.SetHideUIEventId = GameplayNotificationId(uiElement, self.Properties.UIMessages.SetHideUIMessage);

		self.setEnergyEventId = GameplayNotificationId(uiElement, self.Properties.UIMessages.SetEnergyMessage);
		
		self.debugMan = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("DebugManager"));
		
		-- Make sure we don't do this 'first update' again.
		self.performedFirstUpdate = true;
	end

	GameplayNotificationBus.Event.OnEventBegin(self.requestAimUpdateEventId, nil);

    self:UpdateAiming(deltaTime); 
	-- update weapon energy
	if (self.EnergyRegenTimer > 0) then
		self.EnergyRegenTimer = self.EnergyRegenTimer - deltaTime;
		--Debug.Log("Regen delay left " .. self.EnergyRegenTimer);
		if(self.EnergyRegenTimer <= 0) then
			-- FOR SOUND - regen starting
			AudioTriggerComponentRequestBus.Event.ExecuteTrigger(self.entityId, "Play_HUD_energy_restoring");
		end
		
	elseif (self.Properties.Stats.Energy < self.Properties.Stats.EnergyMax) then
		self.Properties.Stats.Energy = self.Properties.Stats.Energy + self.Properties.Stats.EnergyRegen * deltaTime;
		if (self.Properties.Stats.Energy > self.Properties.Stats.EnergyMax) then
			self.Properties.Stats.Energy = self.Properties.Stats.EnergyMax;
			--Debug.Log("Regen energy maxed " .. self.Properties.Stats.Energy);
			-- FOR SOUND -> Energy Level Restored
			AudioTriggerComponentRequestBus.Event.ExecuteTrigger(self.entityId, "Play_HUD_energy_full");
		else
			--Debug.Log("Regen energy currently " .. self.Properties.Stats.Energy);
		end
		GameplayNotificationBus.Event.OnEventBegin(self.setEnergyEventId, 100 * self.Properties.Stats.Energy / self.Properties.Stats.EnergyMax);
	end	
end

function weaponcontroller:OnEnable()
	self.StateMachine:Resume();
	self.tickBusHandler = TickBus.Connect(self);
end

function weaponcontroller:OnDisable()
	self.StateMachine:Stop();
	self.tickBusHandler:Disconnect();
end

function weaponcontroller:OnEventBegin(value)
	if (GameplayNotificationBus.GetCurrentBusId() == self.weaponFirePressedEventId) and self:IsDead() == false then
		self.WantsToShoot = true;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.weaponFireReleasedEventId) and self:IsDead() == false then
		self.WantsToShoot = false;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.onSetupNewWeaponEventId) then
		self:OnSetupNewWeapon(value);
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.setAimDirectionEventId) then
		self.aimDirection = value;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.setAimOriginEventId) then
		self.aimOrigin = value;
	end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.weaponFireSuccessEventId) then
		self:WeaponFireSuccess(value);
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.weaponFireFailEventId) then
		self:WeaponFireFail(value);    
    end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.enableEventId) then
		self:OnEnable();
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.disableEventId) then
		self:OnDisable();
	end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.ownerDiedEventId) then
		self.IsOwnerDead = true;
	end
	
end

function weaponcontroller:IsDead()
	local isDead = self.StateMachine.CurrentState == self.States.Dead;
	return isDead;
end

return weaponcontroller;
