local utilities = require "scripts/common/utilities"
local StateMachine = require "scripts/common/StateMachine"

local aicontroller = 
{
    Properties = 
    {
		NavMarker = { default = EntityId(), description = "A blank marker for use with runtime navigation locations." },
		
		StateMachines =
		{
			AI =
			{
				InitialState = "Idle",
				DebugStateMachine = false,
				
				Idle =
				{
					MoveSpeed = { default = 2.0 },
					
					SentryTurnRate = { default = 6.0, description = "How long sentries wait before turning.", suffix = " seconds" },
					--SentryTurnAngle = { default = 30.0, description = "The angle that sentries turn each time.", suffix = " degrees" },
				},
				
				Suspicious =
				{
					MoveSpeed = { default = 3.0 },
					
					SuspicionRange = { default = 10.0, description = "Detection range in front of the A.I." },
					SuspicionRangeRear = { default = 4.0, description = "Detection range outside the A.I.'s F.o.V." },
					AIFieldOfView = { default = 75.0, description = "The angle of vision in front of the A.I. (in degrees).", suffix = " degrees" },
					DurationOfSuspicion = { default = 8.0, description = "How long the A.I. will inspect a suspicious location (in seconds).", suffix = " s" },
				},
				
				Combat =
				{
					MoveSpeed = { default = 4.0 },
					AngleBeforeReCentering = { default = 50.0, description = "How far before the A.I. turns towards the target.", suffix = " degrees" },
					
					Earshot = { default = 25.0, description = "The range at which A.I. can hear gunshots." },
					
					AggroRange = { default = 6.0, description = "The range at which the A.I. will start attacking." },
					SightRange = { default = 18.0, description = "The range at which the A.I. will stop attacking." },
					DelayBetweenShots = { default = 0.2, description = "The delay between firing shots." },
					DelayBetweenShotsVariance = { default = 0.2, description = "The margin of error on the DelayBetweenShots." },
					
					Goldilocks =
					{
						MinRange = { default = 3.0, description = "The range at which the A.I. will run away from the player." },
						MaxRange = { default = 9.0, description = "The range at which the A.I. will chase the player." },
					},
					
					Juking =
					{
						JukeDelay = { default = 1.0, description = "The delay between jukes." },
						JukeDelayVariance = { default = 0.8, description = "The margin of error on the JukeDelay." },
						JukeDistance = { default = 2.5, description = "The distance the A.I. will juke." },
						JukeDistanceVariance = { default = 1.0, description = "The margin of error on the JukeDistance." },
					},
				},
				
				Tracking =
				{
					MoveSpeed = { default = 4.0 },
					
					DurationToTrack = { default = 6.0, description = "How long the A.I. will inspect a suspicious location (in seconds).", suffix = " s" },
				},
			},
		},
		Events =
		{
			GotShot = { default = "GotShotEvent", description = "Indicates we were shot by something and will likely get hurt." },
			
			RequestSuspiciousLoc = { default = "RequestSuspiciousLocation", description = "Requests the A.I.'s current suspicious location." },
			SendingSuspiciousLoc = { default = "SendingSuspiciousLocation", description = "Sends the / Receives another A.I.'s suspicious location." },
		},
    },
    
	NoTurnIdleAngle = 0.78, -- The player won't play a turn idle animation if the move in a direction less than this angle from the facing direction
	
    InputValues = 
    {
        NavForwardBack = 0.0,
        NavLeftRight = 0.0,
    },
	
	--------------------------------------------------
	-- A.I. State Machine Definition
	-- States:
	--		Idle		- patrolling / sentry
	--		Suspicious	- detected an enemy but not seen yet
	--		Combat		- found a target and attacking them
	--		Tracking	- lost sight of target and trying to find them again
	--		Dead		- he's dead Jim
	--		
	-- Transitions:
	--		Idle		<-> Suspicious
	--					 -> Combat
	--					 -> Dead
	--		Suspicious	<-> Idle
	--					 -> Combat
	--					 -> Dead
	--		Combat		<-  Suspicious
	--					 -> Tracking
	--					 -> Dead
	--		Tracking	<-  Combat
	--					 -> Dead
	--		Dead		<-  Idle
	--					<-  Suspicious
	--					<-  Combat
	--					<-  Tracking
    --------------------------------------------------
	AIStates =
	{
		Idle =
		{
			OnEnter = function(self, sm)
				sm.UserData:SetMoveSpeed(sm.UserData.Properties.StateMachines.AI.Idle.MoveSpeed);
				sm.UserData:TravelToCurrentWaypoint();
				
				-- Reset the suspicious location as we're not suspicious of anything.
				sm.UserData.suspiciousLocation = nil;
			end,
			
			OnExit = function(self, sm)
				sm.UserData:CancelNavigation();
			end,
			
			OnUpdate = function(self, sm, deltaTime)
				sm.UserData:UpdatePatrolling(deltaTime);
			end,

			Transitions =
			{
				-- Become suspicious if an enemy (i.e. the player) is nearby.
				Suspicious =
				{
					Evaluate = function(state, sm)
						return sm.UserData:IsEnemyClose();
					end
				},
				
				-- Enter combat if shot and didn't die (if it did enough damage to kill then
				-- we'd transition straight to the 'Dead' state).
				Combat =
				{
					Evaluate = function(state, sm)
						return sm.UserData:WantsToFight(sm.UserData.Properties.StateMachines.AI.Combat.AggroRange);
					end
				},
			},
		},
		
		Suspicious =
		{
			OnEnter = function(self, sm)
				local speed = sm.UserData.Properties.StateMachines.AI.Suspicious.MoveSpeed;
				if (self.suspiciousFromBeingShot == true) then
					speed = sm.UserData.Properties.StateMachines.AI.Combat.MoveSpeed;
				end
				sm.UserData:SetMoveSpeed(speed);
				
				sm.UserData.justBecomeSuspicious = true;
				sm.UserData.timeBeforeSuspicionReset = sm.UserData.Properties.StateMachines.AI.Suspicious.DurationOfSuspicion;
			end,
			
			OnExit = function(self, sm)
				-- If we are currently navigating somewhere then stop (the next state has no
				-- responsibility to control the navigation initiated by this state).
				sm.UserData:CancelNavigation();
				
				-- Reset this variable.
				sm.UserData.suspiciousFromBeingShot = false;
			end,
			
			OnUpdate = function(self, sm, deltaTime)
				sm.UserData:UpdateSuspicions(deltaTime);
			end,

			Transitions =
			{

				-- Return to 'Idle' (patrolling/sentry) if the enemy couldn't be found.
				Idle =
				{
					Evaluate = function(state, sm)
						return sm.UserData:IsNoLongerSuspicious();
					end
				},
				
				-- Enter combat if shot and didn't die (if it did enough damage to kill then
				-- we'd transition straight to the 'Dead' state) or found the enemy.
				Combat =
				{
					Evaluate = function(state, sm)
						local range = sm.UserData.Properties.StateMachines.AI.Combat.AggroRange;
						if (sm.UserData.suspiciousFromBeingShot == true) then
							range = sm.UserData.Properties.StateMachines.AI.Combat.SightRange;
						end
						
						return sm.UserData:WantsToFight(range);
					end
				},
			},
		},
		
		Combat =
		{
			OnEnter = function(self, sm)
				sm.UserData:SetMoveSpeed(sm.UserData.Properties.StateMachines.AI.Combat.MoveSpeed);
				sm.UserData.timeUntilNextShot = sm.UserData.Properties.StateMachines.AI.Combat.DelayBetweenShots;
				sm.UserData.timeBeforeNextJuke = sm.UserData.Properties.StateMachines.AI.Combat.Juking.JukeDelay;
				sm.UserData.aimAtPlayer = true;
			end,
			
			OnExit = function(self, sm)
				sm.UserData.aimAtPlayer = false;
				-- If we are currently navigating somewhere then stop (the next state has no
				-- responsibility to control the navigation initiated by this state).
				sm.UserData:CancelNavigation();
				sm.UserData.isJuking = false;
				
				-- We don't care.
				-- Maybe we could implement a priority so if a V.I.P. gets shot and we're
				-- attacking a low priority target then we could switch?
				if (sm.UserData.shotHeard:IsValid()) then
					sm.UserData.shotHeard = EntityId();
				end
			end,
			
			OnUpdate = function(self, sm, deltaTime)
				sm.UserData:UpdateCombat(deltaTime);
			end,

			Transitions =
			{

				Idle =
				{
					Evaluate = function(state, sm)
						return sm.UserData:TargetIsDead();
					end
				},
				
				-- Start to track down the enemy (i.e. the player) if lost sight.
				Tracking =
				{
					Evaluate = function(state, sm)
						return sm.UserData:HasLostSightOfTarget();
					end
				},
			},
		},
		
		Tracking =
		{
			OnEnter = function(self, sm)
				sm.UserData:SetMoveSpeed(sm.UserData.Properties.StateMachines.AI.Tracking.MoveSpeed);
				sm.UserData.justBecomeSuspicious = true;
				sm.UserData.timeBeforeSuspicionReset = sm.UserData.Properties.StateMachines.AI.Tracking.DurationToTrack;
			end,
			
			OnExit = function(self, sm)
				-- If we are currently navigating somewhere then stop (the next state has no
				-- responsibility to control the navigation initiated by this state).
				sm.UserData:CancelNavigation();
			end,
			
			OnUpdate = function(self, sm, deltaTime)
				sm.UserData:UpdateSuspicions(deltaTime);
			end,

			Transitions =
			{

				-- Return to 'Idle' if the enemy couldn't be found.
				Idle =
				{
					Evaluate = function(state, sm)
						return sm.UserData:IsNoLongerSuspicious();
					end
				},
				
				-- Enter combat if shot and didn't die (if it did enough damage to kill then
				-- we'd transition straight to the 'Dead' state) or found the enemy.
				Combat =
				{
					Evaluate = function(state, sm)
						-- Need the '-1' to make sure the A.I. stops within the sight range distance.
						return sm.UserData:WantsToFight(sm.UserData.Properties.StateMachines.AI.Combat.SightRange - 1.0);
					end
				},
			},
		},
		
		Dead =
		{
			OnEnter = function(self, sm)
				sm.UserData:CancelNavigation();
			end,
			
			OnExit = function(self, sm)
				
			end,
			
			OnUpdate = function(self, sm, deltaTime)
				
			end,

			Transitions =
			{
				-- "Heroes never die"... shame you're not a hero.
			},
		},
	},
	
	-- The player's position is at his feet. The correct way of getting the player's height
	-- would be to query the player entity for it, but this is just a quick solution.
	PlayerHeight = 1.5,
}

--------------------------------------------------
-- Component behavior
--------------------------------------------------

function aicontroller:OnActivate()

	-- Play the specified Audio Trigger (wwise event) on this component
	AudioTriggerComponentRequestBus.Event.Play(self.entityId);

	self.Properties.StateMachines.AI.Combat.AngleBeforeReCentering = Math.DegToRad(self.Properties.StateMachines.AI.Combat.AngleBeforeReCentering);

	-- Listen for which spawner created us.
	self.spawnedEventId = GameplayNotificationId(self.entityId, "AISpawned");
	self.spawnedHandler = GameplayNotificationBus.Connect(self, self.spawnedEventId);

	-- Enable and disable events
	self.enableEventId = GameplayNotificationId(self.entityId, "Enable");
	self.enableHandler = GameplayNotificationBus.Connect(self, self.enableEventId);
	self.disableEventId = GameplayNotificationId(self.entityId, "Disable");
	self.disableHandler = GameplayNotificationBus.Connect(self, self.disableEventId);
	
	self.weaponFirePressedEventId = GameplayNotificationId(self.entityId, "WeaponFirePressed");
	self.weaponFireReleasedEventId = GameplayNotificationId(self.entityId, "WeaponFireReleased");
	self.weaponFireSuccessEventId = GameplayNotificationId(self.entityId, "WeaponFireSuccess");
	self.weaponFireSuccessHandler = GameplayNotificationBus.Connect(self, self.weaponFireSuccessEventId);
	self.weaponFireFailEventId = GameplayNotificationId(self.entityId, "WeaponFireFail");
	self.weaponFireFailHandler = GameplayNotificationBus.Connect(self, self.weaponFireFailEventId);
	
	self.setAimDirectionId = GameplayNotificationId(self.entityId, "SetAimDirection");
	self.setAimOriginId = GameplayNotificationId(self.entityId, "SetAimOrigin");
	
	self.requestAimUpdateEventId = GameplayNotificationId(self.entityId, "RequestAimUpdate");
	self.requestAimUpdateHandler = GameplayNotificationBus.Connect(self, self.requestAimUpdateEventId);
	
	self.idleTurnStartedEventId = GameplayNotificationId(self.entityId, "EventIdleTurnStarted");
	self.idleTurnStartedHandler = GameplayNotificationBus.Connect(self, self.idleTurnStartedEventId);
	self.idleTurnEndedEventId = GameplayNotificationId(self.entityId, "EventIdleTurnEnded");
	self.idleTurnEndedHandler = GameplayNotificationBus.Connect(self, self.idleTurnEndedEventId);
	self.setMovementDirectionId = GameplayNotificationId(self.entityId, "SetMovementDirection");
	
	self.onDeathEventId = GameplayNotificationId(self.entityId, "HealthEmpty");
	self.onDeathHandler = GameplayNotificationBus.Connect(self, self.onDeathEventId);
    
	-- Input listeners (events).
	self.gotShotEventId = GameplayNotificationId(self.entityId, self.Properties.Events.GotShot);
	self.gotShotHandler = GameplayNotificationBus.Connect(self, self.gotShotEventId);
	self.heardShotEventId = GameplayNotificationId(EntityId(), "ShotsFired");
	self.heardShotHandler = GameplayNotificationBus.Connect(self, self.heardShotEventId);
	
	self.requestSuspiciousLocEventId = GameplayNotificationId(self.entityId, self.Properties.Events.RequestSuspiciousLoc);
	self.requestSuspiciousLocHandler = GameplayNotificationBus.Connect(self, self.requestSuspiciousLocEventId);
	self.sendingSuspiciousLocEventId = GameplayNotificationId(self.entityId, self.Properties.Events.SendingSuspiciousLoc);
	self.sendingSuspiciousLocHandler = GameplayNotificationBus.Connect(self, self.sendingSuspiciousLocEventId);
	
	self.justGotShotBy = EntityId();
	self.suspiciousFromBeingShot = false;
	self.shotHeard = EntityId();

	-- Tick needed to detect aim timeout
    self.tickBusHandler = TickBus.Connect(self);
	self.performedFirstUpdate = false;
	
	-- Need to store the previous Transform so we can keep track of the A.I.'s movement
	-- because we don't get any information directly from the navigation system.
	self.prevTm = TransformBus.Event.GetWorldTM(self.entityId);
	
	self.isTurningToFace = false;
	self.justFinishedTurning = false;

	-- Create the A.I.'s state machine (but don't start it yet).
	self.AIStateMachine = {}
	setmetatable(self.AIStateMachine, StateMachine);
	
	-- Initialise the sentry values.
	self.sentry = false;
	self.timeUntilSentryTurns = self.Properties.StateMachines.AI.Idle.SentryTurnRate;
	--self.Properties.StateMachines.AI.Idle.SentryTurnAngle = Math.DegToRad(self.Properties.StateMachines.AI.Idle.SentryTurnAngle);
	
	-- Ensure the movement values are initialised.
	self.moveSpeed = 0.0;
	self:SetMovement(0.0, 0.0);
	
	self.aimDirection = Vector3(1.0,0.0,0.0);
	self.aimOrigin = Vector3(0.0,0.0,0.0);
end

function aicontroller:OnDeactivate()

    -- Terminate our state machine.
	self.AIStateMachine:Stop();
	
	if (self.tickBusHandler ~= nil) then
		self.tickBusHandler:Disconnect();
		self.tickBusHandler = nil;
	end
	
	if (self.navHandler ~= nil) then
		self.navHandler:Disconnect();
		self.navHandler = nil;
	end
	if (self.rsNavHandler ~= nil) then
		self.rsNavHandler:Disconnect();
		self.rsNavHandler = nil;
	end
	
	if (self.weaponFireSuccessHandler ~= nil) then
		self.weaponFireSuccessHandler:Disconnect();
		self.weaponFireSuccessHandler = nil;
	end
	if (self.weaponFireFailHandler ~= nil) then
		self.weaponFireFailHandler:Disconnect();
		self.weaponFireFailHandler = nil;
	end
	
	if (self.idleTurnStartedHandler ~= nil) then
		self.idleTurnStartedHandler:Disconnect();
		self.idleTurnStartedHandler = nil;
	end
	if (self.idleTurnEndedHandler ~= nil) then
		self.idleTurnEndedHandler:Disconnect();
		self.idleTurnEndedHandler = nil;
	end
	
	if (self.onDeathHandler ~= nil) then
		self.onDeathHandler:Disconnect();
		self.onDeathHandler = nil;
	end
	
	if (self.gotShotHandler ~= nil) then
		self.gotShotHandler:Disconnect();
		self.gotShotHandler = nil;
	end
	if (self.heardShotHandler ~= nil) then
		self.heardShotHandler:Disconnect();
		self.heardShotHandler = nil;
	end
	
	if (self.requestSuspiciousLocHandler ~= nil) then
		self.requestSuspiciousLocHandler:Disconnect();
		self.requestSuspiciousLocHandler = nil;
	end
	if (self.sendingSuspiciousLocHandler ~= nil) then
		self.sendingSuspiciousLocHandler:Disconnect();
		self.sendingSuspiciousLocHandler = nil;
	end
	
	if (self.spawnedHandler ~= nil) then
		self.spawnedHandler:Disconnect();
		self.spawnedHandler = nil;
	end
	if (self.enableHandler ~= nil) then
		self.enableHandler:Disconnect();
		self.enableHandler = nil;
	end
	if (self.disableHandler ~= nil) then
		self.disableHandler:Disconnect();
		self.disableHandler = nil;	
	end

end

function aicontroller:IsMoving()
    return (self.InputValues.NavForwardBack ~= 0 or self.InputValues.NavLeftRight ~= 0);
end

-- Returns a Vector3 containing the stick input values in x and y
function aicontroller:GetInputVector()
	return Vector3(self.InputValues.NavForwardBack, self.InputValues.NavLeftRight, 0);
end

-- Returns the angle to turn in the requested direction and the length of the input vector
function aicontroller:GetAngleDelta(moveLocal)
    if (moveLocal:GetLengthSq() > 0.01) then
        local tm = TransformBus.Event.GetWorldTM(self.entityId);
        
        local moveMag = moveLocal:GetLength();
        if (moveMag > 1.0) then 
            moveMag = 1.0 
        end

		local desiredFacing = moveLocal:GetNormalized();
        local facing = tm:GetColumn(1):GetNormalized();
        local dot = facing:Dot(desiredFacing);
		local angleDelta = Math.ArcCos(dot);
		
		local side = desiredFacing:Dot(tm:GetColumn(0):GetNormalized());
        if (side > 0.0) then
            angleDelta = -angleDelta;
        end
		
		-- Guard against QNANs.
		if (utilities.IsNaN(angleDelta)) then
			angleDelta = 0.0;
		end
		
        return angleDelta, moveMag, desiredFacing;
	else
		return 0.0;
	end

end

function aicontroller:IsFacing(target)
	local angleDelta = self:GetAngleDelta(target);
	if(angleDelta < 0) then
		angleDelta = -angleDelta;
	end
	return angleDelta < self.NoTurnIdleAngle;
end

function aicontroller:OnTick(deltaTime, timePoint)
	-- Initialise anything that requires other entities here because they might not exist
	-- yet in the 'OnActivate()' function.
	if (not self.performedFirstUpdate) then
		-- Initialise the navigation variables and start the A.I. state machine.
		self.navHandler = NavigationComponentNotificationBus.Connect(self, self.entityId);
		self.rsNavHandler = StarterGameNavigationComponentNotificationBus.Connect(self, self.entityId);
		self.requestId = 0;
		self.searchingForPath = false;
		self.reachedWaypoint = false;
		self.navCancelled = false;
		self.AIStateMachine:Start("AI", self.entityId, self, self.AIStates, self.Properties.StateMachines.AI.InitialState, self.Properties.StateMachines.AI.DebugStateMachine);
		
		self.playerId = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("PlayerCharacter"));
		if ((self.playerId == nil) or (not self.playerId:IsValid())) then
			Debug.Log("AIController can't find player on first tick");
		end

		-- This is needed because otherwise the engine disables the A.I.'s physics when it's
		-- spawned because it thinks it's intersecting with something.
		-- This is an engine issue with components not initialising correctly.
		PhysicsComponentRequestBus.Event.EnablePhysics(self.entityId);
		self.prevTm = TransformBus.Event.GetWorldTM(self.entityId);
		
		-- Setup the variables for debugging the range visualisations.
		VisualiseRangeComponentRequestsBus.Event.SetSightRange(self.entityId, self.Properties.StateMachines.AI.Combat.AggroRange, self.Properties.StateMachines.AI.Combat.SightRange);
		VisualiseRangeComponentRequestsBus.Event.SetSuspicionRange(self.entityId, self.Properties.StateMachines.AI.Suspicious.SuspicionRange, self.Properties.StateMachines.AI.Suspicious.AIFieldOfView, self.Properties.StateMachines.AI.Suspicious.SuspicionRangeRear);
		
		if (not utilities.DebugManagerGetBool("PreventAIDisabling", false)) then
			GameplayNotificationBus.Event.OnEventBegin(self.disableEventId, self.entityId);
		end
		
		-- Make sure we don't do this 'first update' again.
		self.performedFirstUpdate = true;
	end
	
	-- Determine how much the A.I. has moved in the last frame and in which direction.
	self:CalculateCurrentMovement(deltaTime);

	self:UpdateMovement();
	self:UpdateWeaponAim();
	
end

function aicontroller:CalculateCurrentMovement(deltaTime)

	local tm = TransformBus.Event.GetWorldTM(self.entityId);
	if (self:IsNavigating() and not self.searchingForPath) then
		local diff = tm:GetTranslation() - self.prevTm:GetTranslation();
		diff.z = 0.0;
		
		-- Guard for coincident vectors.
		if (diff == Vector3(1.0, 0.0, 0.0)) then
			diff = Vector3(0.0, 0.0, 0.0);
		end
		
		if (diff:GetLength() > 0.001) then
			local res = diff:GetNormalized();	-- not sure if we want this
			self:SetMovement(res.x, res.y);
		end
	end
	self.prevTm = tm;
	
end

function aicontroller:UpdateMovement()
	local moveLocal = self:GetInputVector();
	local movementDirection = Vector3(0,0,0);
	if (moveLocal:GetLengthSq() > 0.01) then
		movementDirection = moveLocal:GetNormalized();
	end
	local moveMag = moveLocal:GetLength();
	if (moveMag > 1.0) then
		moveMag = 1.0;
	end
	movementDirection = movementDirection * moveMag;
	GameplayNotificationBus.Event.OnEventBegin(self.setMovementDirectionId, movementDirection);
end

function aicontroller:UpdateWeaponAim()
	-- Get the position we're aiming at (i.e. the player).
	local pos = TransformBus.Event.GetWorldTM(self.playerId):GetTranslation();
	pos.z = pos.z + self.PlayerHeight;	-- the player position is at his feet...
	-- Get the position we're aiming from (i.e. the A.I.).
	local aiTM = TransformBus.Event.GetWorldTM(self.entityId);
	local aiPos = aiTM:GetTranslation();
	aiPos.z = aiPos.z + self.PlayerHeight;	-- the A.I.'s position is at his feet...
	--aiPos = TransformBus.Event.GetWorldTM(self.activeWeapon.Weapon):GetTranslation();
	self.aimDirection = (pos - aiPos):GetNormalized();
	self.aimOrigin = aiPos + (self.aimDirection * 0.5);
end

function aicontroller:IsDead()
	return self.StateMachine.CurrentState == self.States.Dead;
end

function aicontroller:WeaponFired(value)
	GameplayNotificationBus.Event.OnEventBegin(self.weaponFireReleasedEventId, 0.0);
end

function aicontroller:OnEventBegin(value)

	if (GameplayNotificationBus.GetCurrentBusId() == self.spawnedEventId) then
		-- Copy the waypoints, that the A.I. should navigate around, from the spawner.
		WaypointsComponentRequestsBus.Event.CloneWaypoints(self.entityId, value);
		self.sentry = WaypointsComponentRequestsBus.Event.GetWaypointCount(self.entityId) == 1;
	end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.getHealthEventId) then
		self:Heal(value);
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.loseHealthEventId) then
		self:Injure(value);
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.gotShotEventId) then
		-- React to being hit (if it wasn't done by themselves).
		if (self.entityId ~= value.assailant) then
			self.justGotShotBy = value.assailant;
		end
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.heardShotEventId) then
		-- Only save the shot if we're close enough to it.
		if (self.entityId ~= value) then
			local pos = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
			local shotOrigin = TransformBus.Event.GetWorldTM(value):GetTranslation();
			local range = self.Properties.StateMachines.AI.Combat.Earshot * self.Properties.StateMachines.AI.Combat.Earshot;
			if ((pos - shotOrigin):GetLengthSq() <= range) then
				self.shotHeard = value;
			end
		end
	end
	if (GameplayNotificationBus.GetCurrentBusId() == self.enableEventId) then
		self:OnEnable();
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.disableEventId) then
		self:OnDisable();
	end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.requestSuspiciousLocEventId) then
		GameplayNotificationBus.Event.OnEventBegin(GameplayNotificationId(value, self.Properties.Events.SendingSuspiciousLoc), self.suspiciousLocation);
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.sendingSuspiciousLocEventId) then
		self.suspiciousLocation = value;
	end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.weaponFireSuccessEventId or GameplayNotificationBus.GetCurrentBusId() == self.weaponFireFailEventId) then
		self:WeaponFired(value);
    end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.idleTurnStartedEventId) then
		self.isTurningToFace = true;
		self.justFinishedTurning = false;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.idleTurnEndedEventId) then
		self.isTurningToFace = false;
		self.justFinishedTurning = true;
	end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.onDeathEventId) then
		self.AIStateMachine:GotoState("Dead");
	end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.requestAimUpdateEventId) then
		GameplayNotificationBus.Event.OnEventBegin(self.setAimDirectionId, self.aimDirection);
		GameplayNotificationBus.Event.OnEventBegin(self.setAimOriginId, self.aimOrigin);
	end
	
end

function aicontroller:OnEnable()
	self.tickBusHandler = TickBus.Connect(self);
	self.AIStateMachine:Resume();
	PhysicsComponentRequestBus.Event.EnablePhysics(self.entityId);
	MeshComponentRequestBus.Event.SetVisibility(self.entityId, true);
	MannequinRequestsBus.Event.ResumeAll(self.entityId, 7);
end

function aicontroller:OnDisable()
	MannequinRequestsBus.Event.PauseAll(self.entityId);
	MeshComponentRequestBus.Event.SetVisibility(self.entityId, false);
	PhysicsComponentRequestBus.Event.DisablePhysics(self.entityId);
	self.AIStateMachine:Stop();
	self.tickBusHandler:Disconnect();
end

--------------------------------------------------------
--------------------------------------------------------

function aicontroller:UpdatePatrolling(deltaTime)
	if (self.sentry == true) then
		-- If we're turning then reset the movement values so we don't start moving
		-- in that direction once we've finished turning.
		if (self.isTurningToFace == true) then
			self:SetMovement(0.0, 0.0);
		end
		
		-- If the A.I. is a sentry then stand in one place and occasionally turn.
		-- If we're not already navigating then check we're a reasonable distance
		-- from our sentry position.
		if (not self:IsNavigating()) then
			local pos = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
			local wpPos = TransformBus.Event.GetWorldTM(self.currentWaypoint):GetTranslation();
			local distSq = (wpPos - pos):GetLengthSq();
			if (distSq > (2.0 * 2.0)) then
				self:TravelToCurrentWaypoint();
			end
		end
		
		-- Turn every so often.
		-- We need to check again if we're navigating as the previous 'if' may have
		-- started navigation.
		if (not self:IsNavigating() and not self.isTurningToFace) then
			if (self.reachedWaypoint == true) then
				self.timeUntilSentryTurns = self.Properties.StateMachines.AI.Idle.SentryTurnRate;
				self.reachedWaypoint = false;
			end
			
			self.timeUntilSentryTurns = self.timeUntilSentryTurns - deltaTime;
			if (self.timeUntilSentryTurns <= 0.0) then
				local tm = TransformBus.Event.GetWorldTM(self.entityId);
				local forward = tm:GetColumn(1):GetNormalized() * Transform.CreateRotationZ(self.NoTurnIdleAngle + 0.01);
				self:TravelToNavMarker(tm:GetTranslation() + forward);
				
				self.timeUntilSentryTurns = self.Properties.StateMachines.AI.Idle.SentryTurnRate;
			end
		end
	else
		-- If not a sentry then patrol through the given waypoints.
		if (self.justFinishedTurning == true) then
			self:TravelToCurrentWaypoint();
			self.justFinishedTurning = false;
		elseif (self.reachedWaypoint == true) then
			self:TravelToNextWaypoint();
		end
	end
end

function aicontroller:CancelNavigation()
	if (self.requestId ~= 0) then
		-- The 'Stop()' function is processed immediately but I want 'self.requestId'
		-- to be 0 so I know that I'm deliberately stopping the navigation: hence
		-- the temporary variable.
		local id = self.requestId;
		self.requestId = 0;
		NavigationComponentRequestBus.Event.Stop(self.entityId, id);
	end
end

function aicontroller:TargetIsDead()
	-- For now, assume the player is invincible.
	return false;
end

function aicontroller:IsEnemyClose()
	-- If the debug manager says no...
	if (not utilities.DebugManagerGetBool("EnableAICombat", true)) then
		return false;
	end
	
	-- If the A.I. has just been shot then we immediately want to enter suspicion.
	if (self.justGotShotBy:IsValid()) then
		-- We also want to investigate.
		self.suspiciousLocation = TransformBus.Event.GetWorldTM(self.justGotShotBy):GetTranslation();
		
		self.justGotShotBy = EntityId();
		self.suspiciousFromBeingShot = true;
		return true;
	end
	
	-- Analyse any shots that we heard.
	if (self:ShouldReactToShot()) then
		return true;
	end
	
	-- Check if the player is nearby.
	-- We know that the A.I. only target the enemy so I can do this in Lua, but
	-- if we wanted them to attack other things as well (wildlife, practice targets,
	-- other A.I.) then we'd need to do the check in C++ to get the whole list of
	-- nearby enemies.
	local isSuspicious = false;
	local playerPos = TransformBus.Event.GetWorldTM(self.playerId):GetTranslation();
	local aiPos = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
	local aiToPlayer = playerPos - aiPos;
	local distSq = aiToPlayer:GetLengthSq();
	
	-- If the player is close enough to be detected behind then immediately become suspicious.
	if (distSq <= utilities.Sqr(self.Properties.StateMachines.AI.Suspicious.SuspicionRangeRear)) then
		isSuspicious = true;
	-- Otherwise, check if the player is within the broad suspicion range.
	elseif (distSq <= utilities.Sqr(self.Properties.StateMachines.AI.Suspicious.SuspicionRange)) then
		-- The player is nearby. Now check if they're in front of the A.I.
		local aiForward = TransformBus.Event.GetWorldTM(self.entityId):GetColumn(1);
		aiForward.z = 0.0;
		aiForward:Normalize();
		aiToPlayer.z = 0.0;
		aiToPlayer:Normalize();
		local dot = aiForward:Dot(aiToPlayer);
		local angle = Math.RadToDeg(Math.ArcCos(dot));
		
		-- If the player is in front of the A.I. then be suspicious of them.
		if (angle < (self.Properties.StateMachines.AI.Suspicious.AIFieldOfView * 0.5)) then
			isSuspicious = true;
		end
	end
	
	-- If the A.I. is suspicious then record the location for the 'Suspicious' state.
	if (isSuspicious) then
		self.suspiciousLocation = playerPos;
	end
	
	return isSuspicious;
end

function aicontroller:ShouldReactToShot()
	local shouldReact = false;
	if (self.shotHeard:IsValid()) then
		local isPlayer = StarterGameUtility.EntityHasTag(self.shotHeard, "PlayerCharacter");
		local isAI = StarterGameUtility.EntityHasTag(self.shotHeard, "AICharacter");
		if (isPlayer == true) then
			self.suspiciousLocation = TransformBus.Event.GetWorldTM(self.shotHeard):GetTranslation();
		elseif (isAI == true) then
			-- Because events are processed immediately rather than queued I can expect that
			-- this A.I.'s suspicious location matches the other A.I.'s the moment this next
			-- line finishes.
			GameplayNotificationBus.Event.OnEventBegin(GameplayNotificationId(self.shotHeard, self.Properties.Events.RequestSuspiciousLoc), self.entityId);
		end
		
		self.shotHeard = EntityId();
		
		if (self.suspiciousLocation ~= nil) then
			self.suspiciousFromBeingShot = true;
			shouldReact = true;
		end
	end
	
	return shouldReact;
end

function aicontroller:UpdateSuspicions(deltaTime)
	if (self.justBecomeSuspicious == true) then
		self:TurnTowardsSuspiciousLocation();
		
		-- Perhaps move this to be later in the state so the A.I. will look at
		-- the location for a second or two before moving towards it.
		if (self.isTurningToFace == false) then
			self:TravelToNavMarker(self.suspiciousLocation);
		end
		
		self.justBecomeSuspicious = false;
	end
	
	-- If we just finished turning then we need to now start moving towards the location.
	if (self.justFinishedTurning == true) then
		self:TravelToNavMarker(self.suspiciousLocation);
		self.justFinishedTurning = false;
	elseif (not self:IsNavigating()) then
		if (self.isTurningToFace == true) then
			-- We're not moving because we're currently turning to look at the suspicious
			-- location.
		elseif (self.navCancelled) then
			-- If we can't navigate to the suspicious location, then choose a point mid-way
			-- between the suspicious location and the A.I.'s position.
			local pos = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
			local markerPos = TransformBus.Event.GetWorldTM(self.Properties.NavMarker):GetTranslation();
			local vec = markerPos - pos;
			local halfDist = vec:GetLength() * 0.5;
			
			-- Only move the marker if the distance is reasonble.
			if (halfDist >= 2.0) then
				local newPos = pos + (vec:GetNormalized() * halfDist);
				self:TravelToNavMarker(newPos);
			end
			
			-- Reset the cancellation signal.
			self.navCancelled = false;
		elseif (self.reachedWaypoint == true) then
			-- If the A.I. has reached the waypoint and is still in the suspicion state
			-- then it means it hasn't come close enough to the target to enter combat.
			-- Therefore we can now count down before we decide to return to patrolling.
			self.timeBeforeSuspicionReset = self.timeBeforeSuspicionReset - deltaTime;
		else
			-- I'm not sure what it means if the A.I. enters this case, but in this state
			-- the A.I. should always be attempting to travel to a suspicion location
			-- marked by the nav marker). If the A.I. isn't navigating (first 'if') and
			-- the navigation hasn't been cancelled or completed then they've stopped
			-- navigating for an undetected reason; so just tell them to start navigating
			-- again.
			self:TravelToNavMarker(self.suspiciousLocation);
		end
	else
		-- Don't count down until the A.I. reaches the suspicious location.
		self.timeBeforeSuspicionReset = self.Properties.StateMachines.AI.Suspicious.DurationOfSuspicion;
	end
	
end

function aicontroller:TurnTowardsSuspiciousLocation()
	if (self.suspiciousLocation == nil) then 
		return;
	end
	local dir = (self.suspiciousLocation - TransformBus.Event.GetWorldTM(self.entityId):GetTranslation()):GetNormalized();
	if (not self:IsFacing(dir)) then
		self.isTurningToFace = true;
		self:SetMovement(dir.x, dir.y);
	end
end

function aicontroller:IsNoLongerSuspicious()
	return self.timeBeforeSuspicionReset <= 0.0;
end

function aicontroller:WantsToFight(range)
	-- If the debug manager says no...
	if (not utilities.DebugManagerGetBool("EnableAICombat", true)) then
		return false;
	end
	
	-- Analyse any shots that we heard.
	if (self:ShouldReactToShot()) then
		-- Stop moving to where we were going and start moving towards the new threat.
		self:TravelToNavMarker(self.suspiciousLocation);
		return true;
	end
	
	-- Check if an enemy is nearby and in view.
	-- We know that the A.I. only target the player so I can specifically just get the
	-- player's entity ID and perform checks against that but if we wanted the A.I. to
	-- attack other things as well (wildlife, practice targets, other A.I.) then we'd
	-- need a more rebust system; and possible have it done in C++ rather than Lua.
	local wantsToFight = false;
	local playerPos = TransformBus.Event.GetWorldTM(self.playerId):GetTranslation();
	local aiPos = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
	local aiToPlayer = playerPos - aiPos;
	local distSq = aiToPlayer:GetLengthSq();
	
	-- If the player is in range then check if they're also in front of the A.I.
	if (distSq <= utilities.Sqr(range)) then
		local aiForward = TransformBus.Event.GetWorldTM(self.entityId):GetColumn(1);
		aiForward.z = 0.0;
		aiForward:Normalize();
		aiToPlayer.z = 0.0;
		aiToPlayer:Normalize();
		local dot = aiForward:Dot(aiToPlayer);
		local angle = Math.RadToDeg(Math.ArcCos(dot));
		
		-- If the player is in front of the A.I. and in aggro range then start attacking.
		if (angle < (self.Properties.StateMachines.AI.Suspicious.AIFieldOfView * 0.5)) then
			wantsToFight = true;
		end
	end
	
	return wantsToFight;
end

function aicontroller:UpdateCombat(deltaTime)
	-- Update the shooting.
	self.timeUntilNextShot = self.timeUntilNextShot - deltaTime;
	if (self.timeUntilNextShot <= 0.0) then
		GameplayNotificationBus.Event.OnEventBegin(self.weaponFirePressedEventId, 100);	-- unlimited energy!
		
		local variance = utilities.RandomPlusMinus(self.Properties.StateMachines.AI.Combat.DelayBetweenShotsVariance, 0.5);
		self.timeUntilNextShot = self.Properties.StateMachines.AI.Combat.DelayBetweenShots + variance;
		if (self.timeUntilNextShot < 0.0) then
			Debug.Warning("AIController: 'timeUntilNextShot' was calculated to be less than 0 (i.e. next frame).");
		end
	end
	
	-- If we just finished turning then start moving towards the nav marker.
	-- The nav marker should ALWAYS be what we're moving towards in this state.
	if (self.justFinishedTurning == true) then
		self:StartNavigation(self.Properties.NavMarker);
		self.justFinishedTurning = false;
	end
	
	-- If we're already inside the Goldilocks range then do some juking.
	if (self:UpdateGoldilocksPositioning(deltaTime)) then
		-- If we're already moving then don't do anything.
		-- If we AREN'T moving then wait for a randomised period of time before
		-- moving to a randomised position (ensuring that position is also within
		-- the Goldilocks range).
		if (not self:IsNavigating() and not self.isTurningToFace) then
			self.timeBeforeNextJuke = self.timeBeforeNextJuke - deltaTime;
			
			-- Perform a juke.
			-- This juking code isn't done based on any kind of behaviour; it just picks a
			-- valid location near the player and moves to it.
			if (self.timeBeforeNextJuke <= 0.0) then
				-- Calculate a position to juke to.
				-- 1. Choose left or right.
				local left = StarterGameUtility.randomF(0.0, 1.0) > 0.5;
				-- 2. Choose random distance.
				local variance = utilities.RandomPlusMinus(self.Properties.StateMachines.AI.Combat.Juking.JukeDistanceVariance, 0.5);
				local jukeDist = self.Properties.StateMachines.AI.Combat.Juking.JukeDistance + variance;
				-- 3. Calculate the juke position.
				local pos = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
				local playerPos = TransformBus.Event.GetWorldTM(self.playerId):GetTranslation();
				local forward = (playerPos - pos):GetNormalized();
				local up = TransformBus.Event.GetWorldTM(self.entityId):GetColumn(2);
				local jukeOffset;
				if (left) then
					jukeOffset = Vector3.Cross(up, forward);
				else
					jukeOffset = Vector3.Cross(forward, up);
				end
				local jukePos = pos + (jukeOffset * jukeDist);
				-- 4. Push/Pull that distance so it's within a comfortable range
				--		within the Goldilocks range.
				local jukePosToPlayer = (jukePos - playerPos):GetNormalized();
				local minRange, maxRange = self:GetGoldilocksMinMax();
				jukePos = playerPos + (jukePosToPlayer * StarterGameUtility.randomF(minRange, maxRange));
				
				-- 5. Move to it.
				self:TravelToNavMarker(jukePos);
				self.isJuking = true;
				
				-- Reset the timer.
				variance = utilities.RandomPlusMinus(self.Properties.StateMachines.AI.Combat.Juking.JukeDelayVariance, 0.5);
				self.timeBeforeNextJuke = self.Properties.StateMachines.AI.Combat.Juking.JukeDelay + variance;
			end
		end
	end
	
	-- TEMPORARILY REMOVED vvvvvvvvvvvvvvvvv
	-- While at a location (i.e. after juking) turn to look at the enemy.
	--if (false) then
	if (not self:IsNavigating() and not self.isTurningToFace) then
		local pos = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
		local toTarget = (self.suspiciousLocation - pos):GetNormalized();
		local forward = TransformBus.Event.GetWorldTM(self.entityId):GetColumn(1):GetNormalized();
		local angle = Math.ArcCos(forward:Dot(toTarget));
		if (angle >= self.Properties.StateMachines.AI.Combat.AngleBeforeReCentering) then
			self:TurnTowardsSuspiciousLocation();
		end
	end
	--end
	-- TEMPORARILY REMOVED ^^^^^^^^^^^^^^^^^
end

-- When in combat we want to stay within a certain range of the enemy so that
-- we don't lose sight but also so that the enemy can't get close.
--
--          (1)              (2) (3)
--           v                v   v
-- (A.I.) ------- (enemy) ---------
--
-- (1) minimum range
-- (2) maximum range
-- (3) sight range
--
-- When the enemy reaches (3) they will no longer be visible and the A.I. will
-- change state to 'Tracking'.
-- If the enemy gets closer than (1) then they're too close.
-- Ideally, the A.I. wants to keep the enemy at a distance between (1) and (2).
-- These ranges could be 25% and 75% of the A.I.'s sight range; therefore if the
-- A.I.'s sight range is 10 then the following rules apply:
--	- retreat at range 2.5
--	- move closer at range 7.5
-- The target destinations that the A.I. will move to will be 3.0 and 7.0 to
-- ensure the A.I. is comfortably within the 'Goldilocks range'.
function aicontroller:UpdateGoldilocksPositioning(deltaTime)
	local pos = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
	local playerPos = TransformBus.Event.GetWorldTM(self.playerId):GetTranslation();
	local dir = playerPos - pos;
	local dist = dir:GetLength();	-- I can't be bothered squaring everything else; just get sqr
	local minRange, maxRange = self:GetGoldilocksMinMax();
	
	-- If the enemy is within the Goldilocks range then do nothing.
	if (dist >= minRange and dist <= maxRange) then
		return true;
	end
	
	-- If we're not already moving somewhere then move.
	-- 'isJuking' means we're doing a pointless movement, so override that.
	-- TODO: 'self.navCancelled' needs to be handled in a separate case as it means
	-- the nav system failed to find a path to our desired destination. As a result,
	-- we'll need to run to the side or behind the player to get away from them if
	-- they're too close. If they're too far away then do nothing as it means they're
	-- outside the nav area.
	if (self.isJuking == true or self.requestId == 0 or self.reachedWaypoint == true or self.navCancelled == true) then
		-- Push the max and min ranges in so that the A.I. will move to a point
		-- COMFORTABLY within the Goldilocks range.
		-- The reason we have to make sure is because the navigation system has a
		-- "close enough" value. So if we get the A.I. to move TO the min or max range
		-- then there's a good chance they'll stop before actually getting inside the
		-- Goldilocks range.
		local margin = (maxRange - minRange) * 0.25;
		minRange = minRange + margin;
		maxRange = maxRange - margin;
		
		local offsetDist = 0.0;
		-- Retreat!
		if (dist < minRange) then
			offsetDist = (dist - minRange);
		-- Chase!
		elseif (dist > maxRange) then
			offsetDist = (dist - maxRange);
		end
		local offset = dir:GetNormalized() * offsetDist;
		local targetPos = pos + offset;
		
		self:TravelToNavMarker(targetPos);
		self.isJuking = false;
	end
	
	return false;
end

function aicontroller:GetGoldilocksMinMax()
	local minRange = self.Properties.StateMachines.AI.Combat.Goldilocks.MinRange;
	local maxRange = self.Properties.StateMachines.AI.Combat.Goldilocks.MaxRange;
	return minRange, maxRange;
end

function aicontroller:HasLostSightOfTarget()
	local isBlind = true;
	local playerPos = TransformBus.Event.GetWorldTM(self.playerId):GetTranslation();
	playerPos.z = playerPos.z + self.PlayerHeight;	-- the player's position is at his feet
	local aiPos = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
	aiPos.z = aiPos.z + self.PlayerHeight;	-- the A.I.'s position is at his feet
	local aiToPlayer = playerPos - aiPos;
	local distSq = aiToPlayer:GetLengthSq();
	
	-- If the player has moved out of sight range then we've lost them.
	local sr = self.Properties.StateMachines.AI.Combat.SightRange;
	if (distSq <= utilities.Sqr(2.0)) then
		isBlind = false;
	elseif (distSq <= utilities.Sqr(sr)) then
		-- Check that the the A.I. still has a clear LoS to the player.
		-- This is a very simple check and could easily be blocked by a bit of terrain.
		-- A more comprehensive check would be to raycast against multiple character
		-- capsules for each of the player's body parts (e.g. chest, head, upper arm,
		-- leg, etc.).
		local mask = PhysicalEntityTypes.Static + PhysicalEntityTypes.Dynamic + PhysicalEntityTypes.Living;
		local dir = aiToPlayer:GetNormalized();
		-- TODO: Remove the "+ (dir * 2.0)" from the equation. This has been added because
		-- otherwise the raycast will hit the A.I. before it reaches the target.
		
		local rayCastConfig = RayCastConfiguration();
		rayCastConfig.origin = aiPos + (dir * 2.0);
		rayCastConfig.direction =  dir:GetNormalized();
		rayCastConfig.maxDistance = sr;
		rayCastConfig.maxHits = 10;
		rayCastConfig.physicalEntityTypes = mask;
		rayCastConfig.piercesSurfacesGreaterThan = 13;
		local hits = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfig);
		if (hits:HasBlockingHit()) then
			-- Make sure that it was the player the raycast hit...
			if (hits:GetBlockingHit().entityId == self.playerId) then
				-- Store this as the new 'suspiciousLocation' in case we lose track of
				-- the player next frame (as this will be the location we'll attempt to
				-- path to when trying to track them down).
				self.suspiciousLocation = playerPos;
				isBlind = false;
			end
		end
	end
	
	return isBlind;
end

--------------------------------------------------------
--------------------------------------------------------

function aicontroller:SetMoveSpeed(speed)
	NavigationComponentRequestBus.Event.SetAgentSpeed(self.entityId, speed);
	self.moveSpeed = speed;
end

function aicontroller:OnPathFoundFirstPoint(navRequestId, firstPos)
	--Debug.Log("Navigation Path Found: First pos = " .. tostring(firstPos));
	self.searchingForPath = false;
	-- If we're already moving then we can turn while continuing to move towards the destination.
	if (self:IsMoving()) then
		return true;
	end
	
	-- If we're not already moving then we need to stop it and perform an idle turn first.
	local dir = firstPos - TransformBus.Event.GetWorldTM(self.entityId):GetTranslation();
	local isFacing = self:IsFacing(dir);
	if (not isFacing) then
		--Debug.Log("Navigation path found: not close enough: " .. tostring(firstPos) .. ". Turning to: " .. tostring(dir));
		self.isTurningToFace = true;
		self:SetMovement(dir.x, dir.y);
	end
	return isFacing;
end

function aicontroller:OnTraversalStarted(navRequestId)
	--Debug.Log("Navigation Started");
end

function aicontroller:OnTraversalInProgress(navRequestId, distance)
	--Debug.Log("Navigation Progress " .. tostring(distance));
end

function aicontroller:OnTraversalComplete(navRequestId)
	--Debug.Log("Navigation Complete " .. tostring(navRequestId));
	self.requestId = 0;
	self.reachedWaypoint = true;
	self:SetMovement(0.0, 0.0);
end

function aicontroller:OnTraversalCancelled(navRequestId)
	--Debug.Log("Navigation Cancelled " .. tostring(self.requestId));
	
	self.searchingForPath = false;
	self.navCancelled = true;
	if (self.isTurningToFace == false) then
		self:SetMovement(0.0, 0.0);
	end
	
	-- If the request ID is 0 then we cancelled it on purpose. Doing this
	-- stops the navigation system from moving the entity to new points but
	-- it still continues along it's previous vector, so we need to kill its
	-- velocity.
	if (self.requestId == 0) then
		PhysicsComponentRequestBus.Event.SetVelocity(self.entityId, Vector3(0.0, 0.0, 0.0));
	end
end

function aicontroller:TravelToFirstWaypoint()
	self.currentWaypoint = WaypointsComponentRequestsBus.Event.GetFirstWaypoint(self.entityId);
	self:StartNavigation(self.currentWaypoint);
end

function aicontroller:TravelToCurrentWaypoint()
	--Debug.Log("Travel to current");
	if (self.currentWaypoint == nil or not self.currentWaypoint:IsValid()) then
		self.currentWaypoint = WaypointsComponentRequestsBus.Event.GetFirstWaypoint(self.entityId);
	end
	self:StartNavigation(self.currentWaypoint);
end

function aicontroller:TravelToNextWaypoint()
	--Debug.Log("Travel to next");
	self.currentWaypoint = WaypointsComponentRequestsBus.Event.GetNextWaypoint(self.entityId);
	self:StartNavigation(self.currentWaypoint);
end

function aicontroller:TravelToNavMarker(pos)
	self:MoveNavMarkerTo(pos);
	self:StartNavigation(self.Properties.NavMarker);
end

function aicontroller:MoveNavMarkerTo(pos)
	local tm = TransformBus.Event.GetWorldTM(self.Properties.NavMarker);
	tm:SetTranslation(pos);
	TransformBus.Event.SetWorldTM(self.Properties.NavMarker, tm);
end

function aicontroller:StartNavigation(dest)
	if (dest ~= nil and dest:IsValid()) then
		self.requestId = NavigationComponentRequestBus.Event.FindPathToEntity(self.entityId, dest);
		self.searchingForPath = true;
		self.reachedWaypoint = false;
		self.navCancelled = false;
		self.isTurningToFace = false;
		self.justFinishedTurning = false;
		--Debug.Log("Navigating to: " .. tostring(TransformBus.Event.GetWorldTM(dest):GetTranslation()) .. " (with ID: " .. tostring(self.requestId) .. ")");
	else
		Debug.Assert(tostring(self.entityId) .. " tried navigating to a waypoint that doesn't exist.");
	end
end

function aicontroller:IsNavigating()
	return self.requestId ~= 0 and self.navCancelled == false;
end

function aicontroller:SetMovement(fb, lr)
	-- Scale the movement values by the movement speed.
	-- If we don't do this then the A.I. will always start moving as though they're trying to sprint.
	-- TODO: change the multiplier so that the A.I. gradually gets up to speed?
	local speedMultiplier = self.moveSpeed * 0.2;
	self.InputValues.NavForwardBack = fb * speedMultiplier;
	self.InputValues.NavLeftRight = lr * speedMultiplier;
end

return aicontroller;
