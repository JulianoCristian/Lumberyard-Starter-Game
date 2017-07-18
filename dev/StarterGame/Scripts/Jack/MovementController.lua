local utilities = require "scripts/common/utilities"
local StateMachine = require "scripts/common/StateMachine"
		
local movementcontroller = 
{
    Properties = 
    {
        MoveSpeed = { default = 5.6, description = "How fast the chicken moves.", suffix = " m/s" },
        RotationSpeed = { default = 155.0, description = "How fast (in degrees per second) the chicken can turn.", suffix = " deg/sec"},
		Camera = {default = EntityId()},
        InitialState = "Idle",
        DebugStateMachine = false,
		Move2IdleThreshold = { default = 0.8, description = "Character must be moving faster than this normalised speed when they stop to use a move to idle transition animation." },

		
		UIMessages = 
		{
			SetHideUIMessage = { default = "HideUIEvent", description = "The event used to set the whole UI visible / invisible" },
			SetMapValueMessage = { default = "SetMapValueEvent", description = "The event used to set the position of the Map" },
			SetCrosshairMessage = { default = "SetCrosshairEvent", description = "set the visible crosshair" },
			SetCrosshairTargetMessage = { default = "SetCrosshairTargetEvent", description = "set the visible crosshair type" },
			ObjectiveCollectedMessage = { default = "ObjectiveCollectedEvent", description = "set the vobjective Collected" },
			
			ShowMissionFailedMessage = { default = "ShowMissionFailedEvent", description = "Show the screen for failure" },
			ShowMissionSuccessMessage = { default = "ShowMissionSuccessEvent", description = "Show the screen for Success" },
		},
		

		Events =
		{
			DiedMessage = { default = "HealthEmpty", description = "The event recieved when you have died" }, 
						
			ControlsEnabled = { default = "EnableControlsEvent", description = "If passed '1.0' it will enable controls, otherwise it will disable them." },
			ControlsEnabledToggle = { default = "EnableControlsToggleEvent", description = "Enables/Disables controls." },
			
			CollectedObjectiveMessage = { default = "ObjectivePickupEvent", description = "incomming message for objective collection" },
					
			GotShot = { default = "GotShotEvent", description = "Indicates we were shot by something and will likely get hurt." },
		},
    },
    
    InputValues = 
    {
        NavForwardBack = 0.0,
        NavLeftRight = 0.0,
    },

	--------------------------------------------------
	-- Animation State Machine Definition
	-- States:
	--		Idle
	--		Idle2Move
	--		IdleTurn
	--		Move2Idle
	--		Moving
	--		Dead
	--
	-- Transitions:
	--		Idle		<-> Idle2Move
	--					<-> IdleTurn
	--					<-  Move2Idle
	--					<-  Moving
	--		Idle2Move	<-> Idle
	--					<-  IdleTurn
	--					 -> Move2Idle
	--					 -> Moving
	--		IdleTurn	<-> Idle
	--					 -> Idle2Move
	--		Move2Idle	 -> Idle
	--					<-  Idle2Move
	--					<-  Moving
	--		Moving		 -> Idle
	--					<-  IdleToMove
	--					 -> Move2Idle
	--		Dead
	--------------------------------------------------
    States = 
    {
        -- Idle is the base state. All other states should transition back to idle
        -- when complete.
        Idle = 
        {      
            OnEnter = function(self, sm)
			--Debug.Log("entering idle")
                -- Trigger idle animation as "persistent". Even if the state isn't running, this guarantees we never t-pose.
                sm.UserData.Fragments.Idle  = sm:EnsureFragmentPlaying(sm.UserData.Fragments.Idle, 1, "Idle", "", true);
				CharacterAnimationRequestBus.Event.SetAnimationDrivenMotion(sm.EntityId, false);
            end,
            OnExit = function(self, sm)
                sm.UserData.Fragments.Idle = sm:EnsureFragmentStopped(sm.UserData.Fragments.Idle);
                CryCharacterPhysicsRequestBus.Event.RequestVelocity(sm.EntityId, Vector3(0,0,0), 0);
            end,            
            OnUpdate = function(self, sm, deltaTime)
                -- Count down to fidget.
                --sm.UserData.timeIdle = sm.UserData.timeIdle + deltaTime;
            end,
            
            Transitions =
            {
                -- Transition to navigation if we start moving.
				-- Uncomment next line to enable turn idle
				Idle2Move =
                {
                    Evaluate = function(state, sm)
                        return sm.UserData:IsMoving() and sm.UserData:IsFacingTarget();
                    end					
                },
                IdleTurn =
                {
                    Evaluate = function(state, sm)
                        return sm.UserData:IsMoving();
                    end					
                },
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
				if (sm.UserData.shouldImmediatelyRagdoll) then
					RagdollPhysicsRequestBus.Event.EnterRagdoll(sm.EntityId);
				else
				local deathTag = "DeathFront";
				if ((sm.UserData.hitParam > 0.25) and (sm.UserData.hitParam < 0.75)) then
					deathTag = "DeathBack";
				end
				sm.UserData.Fragments.Dead = sm:EnsureFragmentPlaying(sm.UserData.Fragments.Dead, 2, "Dead", deathTag, true);
				end
				
				CharacterAnimationRequestBus.Event.SetAnimationDrivenMotion(sm.EntityId, true);
				sm.UserData:SetControlsEnabled(false);
				self.switchRagdoll = false;
				
				-- Announce to the entity that it's died.
				GameplayNotificationBus.Event.OnEventBegin(GameplayNotificationId(sm.EntityId, "OnDeath"), 1.0);
			end,
            OnUpdate = function(self, sm, deltaTime)
				if(self.switchRagdoll == true) then
					RagdollPhysicsRequestBus.Event.EnterRagdoll(sm.EntityId);
					self.switchRagdoll = false;
				end
            end,
            Transitions =
            {
            },
		},
        Idle2Move = 
        {      
			OnAnimationEvent = function(self, evName)
				if(evName == "Transition") then
					self.transitionReached = true;
				end
			end,
			-- Get the angle of the slope the character is standing on in their facing direction
            OnEnter = function(self, sm)
                sm.UserData.Fragments.Idle2Move  = sm:EnsureFragmentPlaying(sm.UserData.Fragments.Idle2Move, 1, "Idle2Move", "", false);
				CharacterAnimationRequestBus.Event.SetAnimationDrivenMotion(sm.EntityId, true);
				self.prevFrameMoveSpeedParam = utilities.GetMoveSpeed(sm.UserData.movementDirection);
				utilities.SetBlendParam(sm, self.prevFrameMoveSpeedParam, self.MoveSpeedParamID);
				utilities.SetBlendParam(sm, utilities.GetSlopeAngle(sm.UserData), self.TravelSlopeParamID);
				self.transitionReached = false;
		    end,
            OnExit = function(self, sm)
				sm.UserData.Fragments.Idle2Move = sm:EnsureFragmentStopped(sm.UserData.Fragments.Idle2Move);
                CryCharacterPhysicsRequestBus.Event.RequestVelocity(sm.EntityId, Vector3(0,0,0), 0);
            end,            
            OnUpdate = function(self, sm, deltaTime)
				self.prevFrameMoveSpeedParam = utilities.GetMoveSpeed(sm.UserData.movementDirection);
				utilities.SetBlendParam(sm, self.prevFrameMoveSpeedParam, self.MoveSpeedParamID);
				utilities.SetBlendParam(sm, utilities.GetSlopeAngle(sm.UserData), self.TravelSlopeParamID);
            end,
	
            Transitions =
            {
                Idle =
                {
                    Evaluate = function(state, sm)
                        return (state.prevFrameMoveSpeedParam <= sm.UserData.Properties.Move2IdleThreshold) and not sm.UserData:IsMoving();
                    end
                },            
                Move2Idle =
                {
                    Evaluate = function(state, sm)
                        return not sm.UserData:IsMoving();
                    end
                },
                Moving =
                {
                   Evaluate = function(state, sm)
						return state.transitionReached == true;
					end
                },
            },
			MoveSpeedParamID = eMotionParamID_BlendWeight,
			TravelSlopeParamID = eMotionParamID_BlendWeight3,
        },	
        Move2Idle = 
        {      
            OnEnter = function(self, sm)
				sm.UserData.Fragments.Move2Idle = sm:EnsureFragmentPlaying(sm.UserData.Fragments.Move2Idle, 1, "Move2Idle", "", false);
				sm.UserData.Fragments.Idle = sm:EnsureFragmentPlaying(sm.UserData.Fragments.Idle, 1, "Idle", "", false);
				utilities.SetBlendParam(sm, utilities.GetSlopeAngle(sm.UserData), self.TravelSlopeParamID);
				CharacterAnimationRequestBus.Event.SetAnimationDrivenMotion(sm.EntityId, true);
		    end,
            OnExit = function(self, sm)
				sm.UserData.Fragments.Move2Idle = sm:EnsureFragmentStopped(sm.UserData.Fragments.Move2Idle);
            end,            
            OnUpdate = function(self, sm, deltaTime)
				utilities.SetBlendParam(sm, utilities.GetSlopeAngle(sm.UserData), self.TravelSlopeParamID);
            end,
            Transitions =
            {
                Idle =
                {
                    Evaluate = function(state, sm)
						return utilities.CheckFragmentPlaying(sm.EntityId, sm.UserData.Fragments.Move2Idle) == false;
                    end
                },
            },
			TravelSlopeParamID = eMotionParamID_BlendWeight,
        },	
        -- Navigation is the movement state
        Moving = 
        {
            OnEnter = function(self, sm)
                sm.UserData.Fragments.Moving = sm:EnsureFragmentPlaying(sm.UserData.Fragments.Moving, 1, "Moving", "", false);
				CharacterAnimationRequestBus.Event.SetAnimationDrivenMotion(sm.EntityId, false);
				self.firstUpdate = true;
				self.prevFrameMoveMag = 0.0;
            end,

            OnExit = function(self, sm)
                sm.UserData.Fragments.Moving = sm:EnsureFragmentStopped(sm.UserData.Fragments.Moving);
                CryCharacterPhysicsRequestBus.Event.RequestVelocity(sm.EntityId, Vector3(0,0,0), 0);
            end,

            -- Update movement logic while in navigation state.
            OnUpdate = function(self, sm, deltaTime)
				-- Store the speed of the character. Smooth in case the player took their finger off the stick this frame.
				self.prevFrameMoveMag = 0.8 * self.prevFrameMoveMag + 0.2 * sm.UserData:UpdateMovement(deltaTime);
            end,
            
            Transitions = 
            {
                -- Transition to idle as soon as we stop moving.
                Idle =
                {
                    Evaluate = function(state, sm)
                        return (state.prevFrameMoveMag <= sm.UserData.Properties.Move2IdleThreshold) and not sm.UserData:IsMoving();
                    end
                },            
                Move2Idle =
                {
                    Evaluate = function(state, sm)
                        return not sm.UserData:IsMoving();
                    end
                },
			},
        },
        -- Idle turn state transitioning to move
        IdleTurn = 
        {
			OnAnimationEvent = function(self, evName)
				if(evName == "Transition") then
					self.transitionReached = true;
				else 
					if(evName == "Complete") then
						self.turnComplete = true;
					end
				end
			end,
			SetBlendParam = function(sm, blendParam)
				CharacterAnimationRequestBus.Event.SetBlendParameter(sm.EntityId, 7, blendParam);
			end,
			CalculateBlendParam = function(angleDelta)
				local blendParam = (angleDelta + 3.14159265359) / 6.28318530718;
				return blendParam;
			end,
			GetFacing = function(sm)
				local tm = TransformBus.Event.GetWorldTM(sm.EntityId);
				return tm:GetColumn(1):GetNormalized();
			end,
            OnEnter = function(self, sm)
				CharacterAnimationRequestBus.Event.SetAnimationDrivenMotion(sm.EntityId, true);
				local blendParam = self.CalculateBlendParam(sm.UserData:GetAngleDelta());
				self.startAngleDelta = sm.UserData:GetAngleDelta();
				self.SetBlendParam(sm, self.CalculateBlendParam(self.startAngleDelta));
                sm.UserData.Fragments.IdleTurn = sm:EnsureFragmentPlaying(sm.UserData.Fragments.IdleTurn, 1, "IdleTurn", "", false);
				self.firstUpdate = true;
				self.transitionReached = false;
				self.turnComplete = false;
				self.startFacing = self.GetFacing(sm);
				
				-- Announce that we've started an IdleTurn.
				GameplayNotificationBus.Event.OnEventBegin(GameplayNotificationId(sm.EntityId, "EventIdleTurnStarted"), 1.0);
            end,
            OnExit = function(self, sm)
                sm.UserData.Fragments.IdleTurn = sm:EnsureFragmentStopped(sm.UserData.Fragments.IdleTurn);
                CryCharacterPhysicsRequestBus.Event.RequestVelocity(sm.EntityId, Vector3(0,0,0), 0);
				
				-- Announce that we've ended an IdleTurn.
				GameplayNotificationBus.Event.OnEventBegin(GameplayNotificationId(sm.EntityId, "EventIdleTurnEnded"), 1.0);
			end,

            -- Update movement logic while in navigation state.
            OnUpdate = function(self, sm, deltaTime)
				if(self.firstUpdate == true) then
					self.SetBlendParam(sm, self.CalculateBlendParam(self.startAngleDelta));
					self.firstUpdate = false;
				end				
            end,
            
            Transitions = 
            {
                -- Transition to idle as soon as we stop moving.
                Idle =
                {
                    Evaluate = function(state, sm)
						return state.turnComplete == true and ((not sm.UserData:IsMoving()) or (not sm.UserData:IsFacingTarget()));
                    end
                },
                Idle2Move =
                {
                   Evaluate = function(state, sm)
						return state.transitionReached == true and sm.UserData:IsMoving() and sm.UserData:IsFacingTarget();
                    end
                },
            },
        },
    },
	NoTurnIdleAngle = 0.78, -- The player won't play a turn idle animation if the move in a direction less than this angle from the facing direction
	HitBlendParam = eMotionParamID_BlendWeight5 -- Blend parameter index for when the player is hit
}

--------------------------------------------------
-- Component behavior
--------------------------------------------------

function movementcontroller:OnActivate()    
	-- Play the specified Audio Trigger (wwise event) on this component
	AudioTriggerComponentRequestBus.Event.Play(self.entityId);

    self.Properties.RotationSpeed = Math.DegToRad(self.Properties.RotationSpeed);
    self.Fragments = {};
	
	-- Enable and disable events
	self.enableEventId = GameplayNotificationId(self.entityId, "Enable");
	self.enableHandler = GameplayNotificationBus.Connect(self, self.enableEventId);
	self.disableEventId = GameplayNotificationId(self.entityId, "Disable");
	self.disableHandler = GameplayNotificationBus.Connect(self, self.disableEventId);
	
	-- Input listeners (events).
	self.CollectedObjectiveEventId = GameplayNotificationId(self.entityId, self.Properties.Events.CollectedObjectiveMessage);
	self.CollectedObjectiveHandler = GameplayNotificationBus.Connect(self, self.CollectedObjectiveEventId);

	self.getDiedEventId = GameplayNotificationId(self.entityId, self.Properties.Events.DiedMessage);
	self.getDiedHandler = GameplayNotificationBus.Connect(self, self.getDiedEventId);
	
	self.gotShotEventId = GameplayNotificationId(self.entityId, self.Properties.Events.GotShot);
	self.gotShotHandler = GameplayNotificationBus.Connect(self, self.gotShotEventId);

	-- Tick needed to detect aim timeout
    self.tickBusHandler = TickBus.Connect(self);
	self.performedFirstUpdate = false;

    -- Create and start our state machine.
    self.StateMachine = {}
    setmetatable(self.StateMachine, StateMachine);
    self.StateMachine:Start("Animation", self.entityId, self, self.States, self.Properties.InitialState, self.Properties.DebugStateMachine)

		
	self.controlsEnabled = true;
	self.controlsEnabledEventId = GameplayNotificationId(self.entityId, self.Properties.Events.ControlsEnabled);
	self.controlsEnabledHandler = GameplayNotificationBus.Connect(self, self.controlsEnabledEventId);
	self.controlsEnabledToggleEventId = GameplayNotificationId(self.entityId, self.Properties.Events.ControlsEnabledToggle);
	self.controlsEnabledToggleHandler = GameplayNotificationBus.Connect(self, self.controlsEnabledToggleEventId);	
	
	self.WalkEnabled = false;
	
	self.shouldImmediatelyRagdoll = false;
	
	-- Delay firing for a frame so gun comes up
	--self.fireTriggered = nil;
	--self.gunUpDelay = 0.0;
	
	-- Use this to get the camera information when firing. It saves making an entity property
	-- and linking the weapon to a specific camera entity.
	-- Note: this only returns the LAST entity with this tag, so make sure there's only one
	-- entity with the "PlayerCamera" tag otherwise weird stuff might happen.
	self.cameraTag = Crc32("PlayerCamera");
	self.wasHit = false;
	
	self.ObjectivesCollected = 0;
	
	self.setMovementDirectionId = GameplayNotificationId(self.entityId, "SetMovementDirection");
	self.setMovementDirectionHandler = GameplayNotificationBus.Connect(self, self.setMovementDirectionId);
	self.movementDirection = Vector3(0,0,0);
end

function movementcontroller:OnDeactivate()

    -- Terminate our state machine.
    self.StateMachine:Stop();
    self.tickBusHandler:Disconnect();
	self.tickBusHandler = nil;
		
	self.CollectedObjectiveHandler:Disconnect();
	self.CollectedObjectiveHandler = nil;

	self.getDiedHandler:Disconnect();
	self.getDiedHandler = nil;
	
	self.gotShotHandler:Disconnect();
	self.gotShotHandler = nil;
	
	if (self.enableHandler ~= nil) then
		self.enableHandler:Disconnect();
		self.enableHandler = nil;
	end
	if (self.disableHandler ~= nil) then
		self.disableHandler:Disconnect();
		self.disableHandler = nil;	
	end

end

function movementcontroller:IsMoving()
    return Vector3.GetLengthSq(self.movementDirection) > 0.01;
end

-- Returns true if the character is facing approximately in the direction of the controller
function movementcontroller:IsFacingTarget()
	local angleDelta = self:GetAngleDelta();
	if(angleDelta < 0) then
		angleDelta = -angleDelta;
	end
	return angleDelta < self.NoTurnIdleAngle;
end

function movementcontroller:Abs(value)
	return value * Math.Sign(value);
end

function movementcontroller:Clamp(_n, _min, _max)
	if (_n > _max) then _n = _max; end
	if (_n < _min) then _n = _min; end
	return _n;
end

function movementcontroller:UpdateMovement(deltaTime)
     -- Protect against no specified camera.
    --if (not self.Properties.Camera:IsValid()) then
    --    return
    --end
    local angleDelta, moveMag = self:GetAngleDelta();
	local tm = TransformBus.Event.GetWorldTM(self.entityId);
    if (angleDelta ~= 0.0) then    
        local rotationRate = self.Properties.RotationSpeed;
        local thisFrame = rotationRate * deltaTime;
		local absAngleDelta = self:Abs(angleDelta);
        if (absAngleDelta > FloatEpsilon) then
			thisFrame = self:Clamp(angleDelta, -thisFrame, thisFrame);
            local rotationTm = Transform.CreateRotationZ(thisFrame);
            tm = tm * rotationTm;
            tm:Orthogonalize();
            TransformBus.Event.SetWorldTM(self.entityId, tm);            
        end
    end  

	-- Request movement from character physics.
	local vel = (tm:GetColumn(1) * moveMag * self.Properties.MoveSpeed);
	CryCharacterPhysicsRequestBus.Event.RequestVelocity(self.entityId, vel, 0);    
	return moveMag;
end

-- Returns the angle to turn in the requested direction and the length of the input vector
function movementcontroller:GetAngleDelta()
	local movementDirectionMagnitude = self.movementDirection:GetLength();
    if (movementDirectionMagnitude > 0.01) then    
		local movementDirectionNormalised = self.movementDirection:GetNormalized();
		local tm = TransformBus.Event.GetWorldTM(self.entityId);
        local facing = tm:GetColumn(1):GetNormalized();
        local dot = facing:Dot(movementDirectionNormalised);
		local angleDelta = Math.ArcCos(dot);
        local side = Math.Sign(facing:Cross(movementDirectionNormalised).z);
        if (side < 0.0) then
            angleDelta = -angleDelta;
        end
        return angleDelta, movementDirectionMagnitude;
	else
		return 0.0, movementDirectionMagnitude;
	end
end

function movementcontroller:OnTick(deltaTime, timePoint)
	
	-- Doing anything that requires other entities here because they might not exist
	-- yet in the 'OnActivate()' function.
	
	-- Get Player Height for Audio Environment Sound
	local playerHeight = TransformBus.Event.GetWorldTM(self.entityId):GetTranslation().z;
	--Debug.Log("Player Height = : " .. tostring(playerHeight));
	
	-- Set RTPC "rtpc_playerHeight" to equal "playerHeight"
	AudioRtpcComponentRequestBus.Event.SetValue(self.entityId, playerHeight);
	

	if (not self.performedFirstUpdate) then
		-- add in hook messages for the UI

		self.playerId = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("PlayerCharacter"))
	
		if (self.entityId == self.playerId) then
			local uiElement = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("UIPlayer"));
			if (uiElement == nil or uiElement:IsValid() == false) then
				Debug.Log("UIElement not found");
			else
				--Debug.Log("UIElement ID: " .. tostring(uiElement));
			
				self.SetCrosshairEventId = GameplayNotificationId(uiElement, self.Properties.UIMessages.SetCrosshairMessage);
				self.SetCrosshairTargetEventId = GameplayNotificationId(uiElement, self.Properties.UIMessages.SetCrosshairTargetMessage);
					
				self.SetHideUIEventId = GameplayNotificationId(EntityId(), self.Properties.UIMessages.SetHideUIMessage);
				
				self.SetMapValueEventId = GameplayNotificationId(uiElement, self.Properties.UIMessages.SetMapValueMessage);
				
				self.ObjectiveCollectedEventId = GameplayNotificationId(uiElement, self.Properties.UIMessages.ObjectiveCollectedMessage);
			end
				
			local uiElementMissionFail = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("UIPlayerMissionFail"));
			if (uiElementMissionFail == nil or uiElementMissionFail:IsValid() == false) then
				Debug.Log("uiElementMissionFail not found");
			else
				--Debug.Log("uiElementMissionFail ID: " .. tostring(uiElementMissionFail));
				self.ShowMissionFailedEventId = GameplayNotificationId(uiElementMissionFail, self.Properties.UIMessages.ShowMissionFailedMessage);
			end
			
			local uiElementMissionSuccess = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("UIPlayerMissionSuccess"));
			if (uiElementMissionSuccess == nil or uiElementMissionSuccess:IsValid() == false) then
				Debug.Log("uiElementMissionSuccess not found");
			else
				--Debug.Log("uiElementMissionSuccess ID: " .. tostring(uiElementMissionSuccess));
				self.ShowMissionSuccessEventId = GameplayNotificationId(uiElementMissionSuccess, self.Properties.UIMessages.ShowMissionSuccessMessage);
			end		
		end
		
		-- Make sure we don't do this 'first update' again.
		self.performedFirstUpdate = true;
	end
	
	self:UpdateHit();
	
	-- update objectives
	if (self.SetMapValueEventId ~= nil and self.entityId == self.playerId) then
		local camTm = TransformBus.Event.GetWorldTM(TagGlobalRequestBus.Event.RequestTaggedEntities(self.cameraTag));
		local posCam = camTm:GetTranslation();
		local dirCam = camTm:GetColumn(1):GetNormalized();
		dirCam.z = 0;
		dirCam = dirCam:GetNormalized();
		local rightCam = camTm:GetColumn(0);
		rightCam.z = 0;
		rightCam = rightCam:GetNormalized();
		
		-- map start
		local mapValue = 0.5;
		
		local dirNorth = Vector3(0,1,0);
		
		local dirDot = dirCam:Dot(dirNorth);
		local rightDot = rightCam:Dot(dirNorth);
		local linearAngle = Math.ArcCos(dirDot) / 3.1415926535897932384626433832795;
		
		mapValue = (linearAngle + 1.0) * 0.5
		if(rightDot >= 0) then
		else
			mapValue = (mapValue * -1.0) + 1.0;
		end
		
		-- value is currenlty "0->1" for the full 360
		-- making it only show the foward 90
		--mapValue = self:Clamp(((mapValue - 0.5) * 4.0) + 0.5, 0.0, 1.0); 
			
		--Debug.Log("MapDirection: " .. tostring(mapValue));
		GameplayNotificationBus.Event.OnEventBegin(self.SetMapValueEventId, mapValue);	
		-- map end
	end
end
   

function movementcontroller:Die()
	--Debug.Log("Player killed message");

	if (self.entityId == self.playerId) then
		GameplayNotificationBus.Event.OnEventBegin(self.ShowMissionFailedEventId, true);
	end

	--GameplayNotificationBus.Event.OnEventBegin(self.ShowMissionFailedEventId, true);
	self.StateMachine:GotoState("Dead");
end

function movementcontroller:IsDead()
	local isDead = self.StateMachine.CurrentState == self.States.Dead;
	return isDead;
end

function movementcontroller:UpdateHit()
	if(self.wasHit == true) then
		CharacterAnimationRequestBus.Event.SetBlendParameter(self.entityId, self.HitBlendParam, self.hitParam);	
		self.wasHit = utilities.CheckFragmentPlaying(self.entityId, self.Fragments.Hit);
	end
end

function movementcontroller:Hit(value)
	if(self:IsDead() == false) then
    	local tm = TransformBus.Event.GetWorldTM(self.entityId);
    	local facing = tm:GetColumn(1):GetNormalized();
		local direction = -value.direction;
    	local dot = facing:Dot(direction);
		local angle = Math.ArcCos(dot);
    	local side = Math.Sign(facing:Cross(direction).z);
		local PI_2 = 6.28318530718;
    	if (side < 0.0) then
        	angle = -angle;
    	end
		if (self.wasHit) then
			MannequinRequestsBus.Event.ForceFinishRequest(self.entityId, self.Fragments.Hit);
		end
		self.wasHit = true;
		if(angle > 0) then
			self.hitParam = (angle / PI_2);
		else
			self.hitParam = (angle / PI_2) + 1.0;
		end
		self.Fragments.Hit = MannequinRequestsBus.Event.QueueFragment(self.entityId, 1, "Hit", "", false);
	end
end

function movementcontroller:CollectObjective(value)
	--Debug.Log("Collected Objective: " .. tostring(value));
	
	GameplayNotificationBus.Event.OnEventBegin(self.ObjectiveCollectedEventId, value);
	--self.ObjectiveCollectedEventSender:OnGameplayEventAction(value);

	self.ObjectivesCollected = self.ObjectivesCollected + 1;
	if (self.ObjectivesCollected == 3) then
		-- i have collected all the objectives, success!
		GameplayNotificationBus.Event.OnEventBegin(self.ShowMissionSuccessEventId, true);
	end
end
	
function movementcontroller:SetControlsEnabled(newControlsEnabled)
	if ((newControlsEnabled ~= self.controlsEnabled) and (self.SetHideUIEventId ~= nil)) then
		self.controlsEnabled = newControlsEnabled;
		--Debug.Log("controls chaned to: " .. tostring(self.controlsEnabled));
		if(newControlsEnabled) then
			--Debug.Log("ShowUI");
			GameplayNotificationBus.Event.OnEventBegin(self.SetHideUIEventId, 0);
		else
			--Debug.Log("HideUI");
			GameplayNotificationBus.Event.OnEventBegin(self.SetHideUIEventId, 1);
		end
	end 
end

function movementcontroller:OnEnable()
	self.StateMachine:Resume();
	self.tickBusHandler = TickBus.Connect(self);
end

function movementcontroller:OnDisable()
	self.StateMachine:Stop();
	self.tickBusHandler:Disconnect();
end
	
function movementcontroller:OnEventBegin(value)
	--Debug.Log("movementcontroller:OnEventBegin( " .. tostring(value) .. " )");
	if (GameplayNotificationBus.GetCurrentBusId() == self.controlsEnabledEventId) then
		--Debug.Log("controlls set: " .. tostring(value));
		if (value == 1.0) then
			self:SetControlsEnabled(true);
		else
			self:SetControlsEnabled(false);
		end
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.controlsEnabledToggleEventId) then
		self:SetControlsEnabled(not self.controlsEnabled);
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.setMovementDirectionId) then
		--Debug.Log("setMovementDirectionId ( " .. tostring(value) .. " )");
		self.movementDirection = value;
	end

	if (GameplayNotificationBus.GetCurrentBusId() == self.getDiedEventId) then
		self:Die();
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.gotShotEventId) then
		-- React to being hit (if it wasn't done by themself).
		if (self.entityId ~= value.assailant) then
			self.shouldImmediatelyRagdoll = value.immediatelyRagdoll;
			self:Hit(value);
		end
    end
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.enableEventId) then
		self:OnEnable();
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.disableEventId) then
		self:OnDisable();
	end
	
	if (self.entityId == self.playerId) then
		if (GameplayNotificationBus.GetCurrentBusId() == self.CollectedObjectiveEventId) then
			self:CollectObjective(value);
		end
	end
end


return movementcontroller;
