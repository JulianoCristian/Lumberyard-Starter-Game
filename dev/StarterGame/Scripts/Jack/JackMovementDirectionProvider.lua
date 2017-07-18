local jackmovementdirectionprovider = 
{
    Properties = 
    {
		Camera = {default = EntityId()},
		WalkSpeedMutiplier = { default = 0.25, description = "Multiplier for speed while walking.", },		
		Events =
		{
			ControlsEnabled = { default = "EnableControlsEvent", description = "If passed '1.0' it will enable controls, oherwise it will disable them." },
			ControlsEnabledToggle = { default = "EnableControlsToggleEvent", description = "Enables/Disables controls." },
		},
    },
    InputValues = 
    {
        NavForwardBack = 0.0,
        NavLeftRight = 0.0,
    }
}

function jackmovementdirectionprovider:OnActivate() 

	-- Input listeners (movement).
    self.navForwardBackEventId = GameplayNotificationId(self.entityId, "NavForwardBack");
    self.navForwardBackHandler = GameplayNotificationBus.Connect(self, self.navForwardBackEventId);
    self.navLeftRightEventId = GameplayNotificationId(self.entityId, "NavLeftRight");
    self.navLeftRightHandler = GameplayNotificationBus.Connect(self, self.navLeftRightEventId);

    self.navForwardBackKMEventId = GameplayNotificationId(self.entityId, "NavForwardBackKM");
    self.navForwardBackKMHandler = GameplayNotificationBus.Connect(self, self.navForwardBackKMEventId);
    self.navLeftRightKMEventId = GameplayNotificationId(self.entityId, "NavLeftRightKM");
    self.navLeftRightKMHandler = GameplayNotificationBus.Connect(self, self.navLeftRightKMEventId);
    
	self.navWalkPressedEventId = GameplayNotificationId(self.entityId, "NavWalkPressed");
    self.navWalkPressedHandler = GameplayNotificationBus.Connect(self, self.navWalkPressedEventId);
    self.navWalkReleasedEventId = GameplayNotificationId(self.entityId, "NavWalkReleased");
    self.navWalkReleasedHandler = GameplayNotificationBus.Connect(self, self.navWalkReleasedEventId);

	-- Tick needed to detect aim timeout
    self.tickBusHandler = TickBus.Connect(self);

	self.controlsEnabled = true;
	self.controlsEnabledEventId = GameplayNotificationId(self.entityId, self.Properties.Events.ControlsEnabled);
	self.controlsEnabledHandler = GameplayNotificationBus.Connect(self, self.controlsEnabledEventId);
	self.controlsEnabledToggleEventId = GameplayNotificationId(self.entityId, self.Properties.Events.ControlsEnabledToggle);
	self.controlsEnabledToggleHandler = GameplayNotificationBus.Connect(self, self.controlsEnabledToggleEventId);	
	
	self.WalkEnabled = false;

end   

function jackmovementdirectionprovider:OnDeactivate()

    self.navForwardBackHandler:Disconnect();
	self.navForwardBackHandler = nil;
    self.navLeftRightHandler:Disconnect();
	self.navLeftRightHandler = nil;
	
	self.navForwardBackKMHandler:Disconnect();
	self.navForwardBackKMHandler = nil;
    self.navLeftRightKMHandler:Disconnect();
	self.navLeftRightKMHandler = nil;
	
	self.navWalkPressedHandler:Disconnect();
	self.navWalkPressedHandler = nil;
    self.navWalkReleasedHandler:Disconnect();
	self.navWalkReleasedHandler = nil;
    self.tickBusHandler:Disconnect();
	self.tickBusHandler = nil;
	self.controlsEnabledHandler:Disconnect();
	self.controlsEnabledHandler = nil; 
	self.controlsEnabledToggleHandler:Disconnect();
	self.controlsEnabledToggleHandler = nil;
end
	
function jackmovementdirectionprovider:SetControlsEnabled(newControlsEnabled)
	self.controlsEnabled = newControlsEnabled;
end

function jackmovementdirectionprovider:OnEventBegin(value)
	
	if (GameplayNotificationBus.GetCurrentBusId() == self.controlsEnabledEventId) then
		--Debug.Log("controlsEnabledEventId " .. tostring(value));
		if (value == 1.0) then
			self:SetControlsEnabled(true);
		else
			self:SetControlsEnabled(false);
		end
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.controlsEnabledToggleEventId) then
		--Debug.Log("controlsEnabledEventId " .. tostring(value));
		self:SetControlsEnabled(not self.controlsEnabled);
	end
	
	if (self.controlsEnabled) then
		if (GameplayNotificationBus.GetCurrentBusId() == self.navForwardBackEventId) then  
			self.InputValues.NavForwardBack = value;
		elseif (GameplayNotificationBus.GetCurrentBusId() == self.navLeftRightEventId) then
			self.InputValues.NavLeftRight = value;
		elseif (GameplayNotificationBus.GetCurrentBusId() == self.navForwardBackKMEventId) then  
			if(self.WalkEnabled) then
				self.InputValues.NavForwardBack = value * self.Properties.WalkSpeedMutiplier;
			else
				self.InputValues.NavForwardBack = value;
			end
		elseif (GameplayNotificationBus.GetCurrentBusId() == self.navLeftRightKMEventId) then
			if(self.WalkEnabled) then
				self.InputValues.NavLeftRight = value * self.Properties.WalkSpeedMutiplier;
			else
				self.InputValues.NavLeftRight = value;
			end
		elseif (GameplayNotificationBus.GetCurrentBusId() == self.navWalkPressedEventId) then  
			self.WalkEnabled = true;
		elseif (GameplayNotificationBus.GetCurrentBusId() == self.navWalkReleasedEventId) then
			self.WalkEnabled = false;
		end
	else
		self.InputValues.NavForwardBack = 0;		
		self.InputValues.NavLeftRight = 0;	
	end
	
end

function jackmovementdirectionprovider:OnEventUpdating(value)
	if (self.controlsEnabled == true) then
		if (GameplayNotificationBus.GetCurrentBusId() == self.navForwardBackEventId) then  
	    	self.InputValues.NavForwardBack = value;
	    elseif (GameplayNotificationBus.GetCurrentBusId() == self.navLeftRightEventId) then
	    	self.InputValues.NavLeftRight = value;
		elseif (GameplayNotificationBus.GetCurrentBusId() == self.navForwardBackKMEventId) then  
			if(self.WalkEnabled) then
				self.InputValues.NavForwardBack = value * self.Properties.WalkSpeedMutiplier;
			else
				self.InputValues.NavForwardBack = value;
			end
	  	elseif (GameplayNotificationBus.GetCurrentBusId() == self.navLeftRightKMEventId) then
	  		if(self.WalkEnabled) then
				self.InputValues.NavLeftRight = value * self.Properties.WalkSpeedMutiplier;
			else
				self.InputValues.NavLeftRight = value;
			end
		end
	else
		self.InputValues.NavForwardBack = 0;		
		self.InputValues.NavLeftRight = 0;
	end
end

function jackmovementdirectionprovider:GetInputVector()
	--Debug.Log("InputVector: "..self.InputValues.NavLeftRight..", "..self.InputValues.NavForwardBack);
	local v = Vector3(self.InputValues.NavLeftRight, self.InputValues.NavForwardBack, 0);
	return v
end

function jackmovementdirectionprovider:OnEventEnd()
    if (GameplayNotificationBus.GetCurrentBusId() == self.navForwardBackEventId) then
		--Debug.Log("ended forwardBack")
        self.InputValues.NavForwardBack = 0;
    elseif (GameplayNotificationBus.GetCurrentBusId() == self.navLeftRightEventId) then
        self.InputValues.NavLeftRight = 0;
    elseif (GameplayNotificationBus.GetCurrentBusId() == self.navForwardBackKMEventId) then
		--Debug.Log("ended forwardBack")
        self.InputValues.NavForwardBack = 0;
    elseif (GameplayNotificationBus.GetCurrentBusId() == self.navLeftRightKMEventId) then
        self.InputValues.NavLeftRight = 0;    
    end    
end

function jackmovementdirectionprovider:OnTick(deltaTime, timePoint)
    local moveLocal = self:GetInputVector();	
	local movementDirection = Vector3(0,0,0);
    if (moveLocal:GetLengthSq() > 0.01) then    
        local tm = TransformBus.Event.GetWorldTM(self.entityId);
        
        local cameraOrientation = TransformBus.Event.GetWorldTM(self.Properties.Camera);
        cameraOrientation:SetTranslation(Vector3(0,0,0));

		local camRight = cameraOrientation:GetColumn(0);		-- right
		local camForward = camRight:Cross(Vector3(0,0,-1));
      	local desiredFacing = (camForward * moveLocal.y) + (camRight * moveLocal.x);
		movementDirection = desiredFacing:GetNormalized();
	end
	local moveMag = moveLocal:GetLength();
    if (moveMag > 1.0) then 
        moveMag = 1.0 
    end
	movementDirection = movementDirection * moveMag;
	self.SetMovementDirectionId = GameplayNotificationId(self.entityId, "SetMovementDirection");
	GameplayNotificationBus.Event.OnEventBegin(self.SetMovementDirectionId, movementDirection);
	--Debug.Log("MDC: "..movementDirection.x..", "..movementDirection.y .. " to ID : " .. tostring(self.entityId));
end

return jackmovementdirectionprovider;