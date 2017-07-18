
local cameracontroller =
{
	Properties =
	{
		InputEntity = {default = EntityId()},

		CameraFollowDistanceBelow = {default = 2.0, description = "Distance (in meters) from which the camera follows the character when at the lowest angle."},
        CameraFollowDistance = {default = 5.0, description = "Distance (in meters) from which camera follows character."},
        CameraFollowHeight = {default = 1.0, description = "Height (in meters) from which camera follows character."},
		CameraFollowOffset = {default = -0.75, description = "Distance (in meters) from which the camera moves to the side of the character."},
		CameraPivotOffset =
		{
			Front = {default = 0.25, description = "Distance (in meters) that the front pivot is from the central pivot."},
			Back = {default = 0.25, description = "Distance (in meters) that the back pivot is from the central pivot."},
		},
		PlayerEntity = {default = EntityId()},

		MaxLookUpAngle = {default = 89.0, description = "The maximum angle (in degrees) that the player can look upwards."},
		MaxLookDownAngle = {default = -89.0, description = "The maximum angle (in degrees) that the player can look down."},
		
		CameraSensitivity =
		{
			Vertical = {default = 360.0, description = "The sensitivity of the vertical camera movement.", suffix = " deg/sec"},
			Horizontal = {default = 360.0, description = "The sensitivity of the horizontal camera movement.", suffix = " deg/sec"},
		},
		
		MinDistanceFromGeometry = {default = 0.1, description = "Distance (in meters) that the camera pushes itself away from geometry."},
		MouseLookSensitivity = { default = 1.0, description = "Multiplier for mouse movement.", },
		
		Events =
		{
			ControlsEnabled = { default = "EnableControlsEvent", description = "If passed '1.0' it will enable controls, otherwise it will disable them." },
		},
	},

    -- Values that have come from the input device.
    InputValues = 
    {
		LookLeftRight = 0.0,
		LookUpDown = 0.0,
    },

	-- The camera's rotation values.
	CamProps =
	{
		OrbitHorizontal = 0.0,
		OrbitVertical = 0.0,
	},
}

function cameracontroller:OnActivate()

    self.lookLeftRightEventId = GameplayNotificationId(self.entityId, "LookLeftRight");
    self.lookLeftRightHandler = GameplayNotificationBus.Connect(self, self.lookLeftRightEventId);
    self.lookUpDownEventId = GameplayNotificationId(self.entityId, "LookUpDown");
    self.lookUpDownHandler = GameplayNotificationBus.Connect(self, self.lookUpDownEventId);
	
    self.lookLeftRightKMEventId = GameplayNotificationId(self.entityId, "LookLeftRightKM");
    self.lookLeftRightKMHandler = GameplayNotificationBus.Connect(self, self.lookLeftRightKMEventId);
    self.lookUpDownKMEventId = GameplayNotificationId(self.entityId, "LookUpDownKM");
    self.lookUpDownKMHandler = GameplayNotificationBus.Connect(self, self.lookUpDownKMEventId);

    self.lookLeftRightForcedEventId = GameplayNotificationId(self.entityId, "LookLeftRightForced");
    self.lookLeftRightForcedHandler = GameplayNotificationBus.Connect(self, self.lookLeftRightForcedEventId);
    self.lookUpDownForcedEventId = GameplayNotificationId(self.entityId, "LookUpDownForced");
    self.lookUpDownForcedHandler = GameplayNotificationBus.Connect(self, self.lookUpDownForcedEventId);
	
	self.controlsEnabled = true;
	self.controlsEnabledEventId = GameplayNotificationId(self.entityId, self.Properties.Events.ControlsEnabled);
	self.controlsEnabledHandler = GameplayNotificationBus.Connect(self, self.controlsEnabledEventId);

    self.debugNumPad1EventId = GameplayNotificationId(self.entityId, "NumPad1");
    self.debugNumPad1Handler = GameplayNotificationBus.Connect(self, self.debugNumPad1EventId);
    self.debugNumPad2EventId = GameplayNotificationId(self.entityId, "NumPad2");
    self.debugNumPad2Handler = GameplayNotificationBus.Connect(self, self.debugNumPad2EventId);
    self.debugNumPad3EventId = GameplayNotificationId(self.entityId, "NumPad3");
    self.debugNumPad3Handler = GameplayNotificationBus.Connect(self, self.debugNumPad3EventId);
    self.debugNumPad4EventId = GameplayNotificationId(self.entityId, "NumPad4");
    self.debugNumPad4Handler = GameplayNotificationBus.Connect(self, self.debugNumPad4EventId);
    self.debugNumPad5EventId = GameplayNotificationId(self.entityId, "NumPad5");
    self.debugNumPad5Handler = GameplayNotificationBus.Connect(self, self.debugNumPad5EventId);
    self.debugNumPad6EventId = GameplayNotificationId(self.entityId, "NumPad6");
    self.debugNumPad6Handler = GameplayNotificationBus.Connect(self, self.debugNumPad6EventId);
    self.debugNumPad7EventId = GameplayNotificationId(self.entityId, "NumPad7");
    self.debugNumPad7Handler = GameplayNotificationBus.Connect(self, self.debugNumPad7EventId);
    self.debugNumPad8EventId = GameplayNotificationId(self.entityId, "NumPad8");
    self.debugNumPad8Handler = GameplayNotificationBus.Connect(self, self.debugNumPad8EventId);
    self.debugNumPad9EventId = GameplayNotificationId(self.entityId, "NumPad9");
    self.debugNumPad9Handler = GameplayNotificationBus.Connect(self, self.debugNumPad9EventId);
	self.CameraFollowDistanceBelowOriginal = self.Properties.CameraFollowDistanceBelow;
	self.CameraFollowDistanceOriginal = self.Properties.CameraFollowDistance;
	self.CameraFollowHeightOriginal = self.Properties.CameraFollowHeight;
	self.CameraFollowOffsetOriginal = self.Properties.CameraFollowOffset;

	-- Take note of the camera's original rotation.
	-- TODO: do the same for the 'X' rotation.
	local tm = TransformBus.Event.GetWorldTM(self.entityId);
	local right = tm:GetColumn(0);
	local forward = tm:GetColumn(1);
	local up = tm:GetColumn(2);
	--Debug.Log("Cam Up     : " .. Math.RadToDeg(up.x) .. " : " .. Math.RadToDeg(up.y) .. " : " .. Math.RadToDeg(up.z));
	--Debug.Log("Cam Forward: " .. Math.RadToDeg(forward.x) .. " : " .. Math.RadToDeg(forward.y) .. " : " .. Math.RadToDeg(forward.z));
	--Debug.Log("Cam Right  : " .. Math.RadToDeg(right.x) .. " : " .. Math.RadToDeg(right.y) .. " : " .. Math.RadToDeg(right.z));
	self.CamProps.OrbitHorizontal = Math.RadToDeg(Math.ArcCos(forward:Dot(Vector3(0.0, 1.0, 0.0))));
	-- Invert it if it should be negative.
	if (forward.x >= 0.0) then
		self.CamProps.OrbitHorizontal = self.CamProps.OrbitHorizontal * -1.0;
	end
	--Debug.Log("Z Angle: " .. self.CamProps.OrbitHorizontal);

	self.tickBusHandler = TickBus.Connect(self);

end

function cameracontroller:OnDeactivate()

	self.lookLeftRightHandler:Disconnect();
	self.lookUpDownHandler:Disconnect();
	
	self.lookLeftRightKMHandler:Disconnect();
	self.lookUpDownKMHandler:Disconnect();
	
	self.lookLeftRightForcedHandler:Disconnect();
	self.lookUpDownForcedHandler:Disconnect();
	
	self.debugNumPad1Handler:Disconnect();
	self.debugNumPad2Handler:Disconnect();
	self.debugNumPad3Handler:Disconnect();
	self.debugNumPad4Handler:Disconnect();
	self.debugNumPad5Handler:Disconnect();
	self.debugNumPad6Handler:Disconnect();
	self.debugNumPad7Handler:Disconnect();
	self.debugNumPad8Handler:Disconnect();
	self.debugNumPad9Handler:Disconnect();

	self.tickBusHandler:Disconnect();

end

function cameracontroller:OnTick(deltaTime, timePoint)

	-- Store the camera rotations.
	local leftRight = self.Properties.CameraSensitivity.Horizontal * deltaTime * self.InputValues.LookLeftRight;
	local upDown = self.Properties.CameraSensitivity.Vertical * deltaTime * self.InputValues.LookUpDown;
	self.CamProps.OrbitHorizontal = self.CamProps.OrbitHorizontal - leftRight;
	self.CamProps.OrbitVertical = self.CamProps.OrbitVertical + upDown;

	-- Clamp the vertical look value (so the camera doesn't go up-side-down).
	if (self.CamProps.OrbitVertical > self.Properties.MaxLookUpAngle) then
		self.CamProps.OrbitVertical = self.Properties.MaxLookUpAngle;
	elseif (self.CamProps.OrbitVertical < self.Properties.MaxLookDownAngle) then
		self.CamProps.OrbitVertical = self.Properties.MaxLookDownAngle;
	end
	
	-- Find out the camera's follow distance.
	-- When above level we want to use the 'CameraFollowDistance'. When below level we want to
	-- interpolate between 'CameraFollowDistance' and 'CameraFollowDistanceBelow' so that when
	-- the player is looking directly up the distance is shorter (so the designer can pull the
	-- camera out of the ground cover and foliage).
	local camFollowDist = self.Properties.CameraFollowDistance;
	if (self.CamProps.OrbitVertical > 0) then
		local s = self.CamProps.OrbitVertical / self.Properties.MaxLookUpAngle;
		local a = self.Properties.CameraFollowDistance * (1.0 - s);
		local b = self.Properties.CameraFollowDistanceBelow * s;
		camFollowDist = a + b;
	end
	
	-- Use the camera's rotation to get the corrent vector we want to push away with.
	local rotZTm = Transform.CreateRotationZ(Math.DegToRad(self.CamProps.OrbitHorizontal));
	local rotXTm = Transform.CreateRotationX(Math.DegToRad(self.CamProps.OrbitVertical));
	local camOrientation = rotZTm * rotXTm;
	local camPushBack = camOrientation * Vector3(0.0, camFollowDist, 0.0);
	
	-- Find the pivot that we want to use based on the height of the camera (front or back).
	local pivotFrontOrBackOffset = Vector3(camPushBack.x, camPushBack.y, 0.0);
	pivotFrontOrBackOffset:Normalize();
	local pivotRange = self.Properties.CameraPivotOffset.Back;
	if (self.CamProps.OrbitVertical < 0) then
		pivotRange = self.Properties.CameraPivotOffset.Front;
	end
	pivotFrontOrBackOffset = pivotFrontOrBackOffset * pivotRange;
	local pivotOffsetLength = pivotFrontOrBackOffset:GetLength();
	if (self.CamProps.OrbitVertical < 0) then
		pivotFrontOrBackOffset = pivotFrontOrBackOffset * -1.0;
		pivotOffsetLength = pivotOffsetLength * -1.0;
	end

    -- Find the pivot point that the camera will be rotating about.
    local characterTm = TransformBus.Event.GetWorldTM(self.Properties.PlayerEntity);
	local pivotOffset = TransformBus.Event.GetWorldTM(self.entityId):GetColumn(0) * self.Properties.CameraFollowOffset;
    local pivotPoint = characterTm:GetTranslation() + Vector3(0.0, 0.0, self.Properties.CameraFollowHeight) + pivotOffset - pivotFrontOrBackOffset;

	-- Raycast from a point centered on the player to the offset pivot point to make sure the pivot point
	-- doesn't go to the other side of a wall when the player stands next to one.
	local pointInPlayer = characterTm:GetTranslation() + Vector3(0.0, 0.0, self.Properties.CameraFollowHeight);
	local playerToPivot = pivotPoint - pointInPlayer;
	local playerToPivotDist = playerToPivot:GetLength();
	playerToPivot = playerToPivot / playerToPivotDist; -- normalize
	local mask = PhysicalEntityTypes.Static + PhysicalEntityTypes.Dynamic + PhysicalEntityTypes.Independent;
	
	local rayCastConfig = RayCastConfiguration();
	rayCastConfig.origin = pointInPlayer;
	rayCastConfig.direction =  playerToPivot;
	rayCastConfig.maxDistance = playerToPivot:GetLength();
	rayCastConfig.maxHits = 10;
	rayCastConfig.physicalEntityTypes = mask;
	rayCastConfig.piercesSurfacesGreaterThan = 13;
	
	local offsetHits = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfig);
	local hasOffsetHit = offsetHits:HasBlockingHit();
	local offsetBlockingHit = offsetHits:GetBlockingHit();
	
	if (hasOffsetHit) then
		-- If there's something between the pivot point and the player then move the pivot point in.
		pivotPoint = offsetBlockingHit.position - (playerToPivot:GetNormalized() * self.Properties.MinDistanceFromGeometry);
	end

	-- Recalculate the pushback for the new length (as the pivot point's moved).
	camPushBack = camOrientation * Vector3(0.0, camFollowDist - pivotOffsetLength, 0.0);

	-- Push the camera back from the player's position based on the camera's rotation.
	local camPos = pivotPoint - camPushBack;
	
	-- Pull the camera back in so it doesn't go through geometry.
	local charToCam = camPos - pivotPoint;
	local charToCamDist = charToCam:GetLength();
	charToCam = charToCam / charToCamDist; -- normalize
	local length = charToCamDist + self.Properties.MinDistanceFromGeometry;
	rayCastConfig.origin = pivotPoint;
	rayCastConfig.direction =  charToCam;
	rayCastConfig.maxDistance = length;
	
	local hits = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfig);
	local hasHit = hits:HasBlockingHit();
	local blockingHit = hits:GetBlockingHit();
	
	-- If the distance to the collision is 0.0 then we hit nothing.
	-- If the entityID is valid then we hit a component entity; otherwise we hit a legacy entity (or terrain).
	if (hasHit) then
		camPos = blockingHit.position - (charToCam:GetNormalized() * self.Properties.MinDistanceFromGeometry);
		--camPos = camPos + (rch.normal * 0.05);	-- Push it off the surface.
	end

	-- Now apply the rotation.
    local cameraTm = TransformBus.Event.GetWorldTM(self.entityId);
	cameraTm = camOrientation;
	cameraTm:SetTranslation(camPos);
	cameraTm:Orthogonalize();

	-- Set the final transform.
    TransformBus.Event.SetWorldTM(self.entityId, cameraTm);

end

-- This function square a float while maintaining the original sign.
function cameracontroller:SquareWithSign(i)

	local res = i * i;
	if (i < 0) then
		res = res * -1.0;
	end
	
	return res;

end

function cameracontroller:OnEventBegin(value)

	if (GameplayNotificationBus.GetCurrentBusId() == self.controlsEnabledEventId) then
		if (value == 1.0) then
			self.controlsEnabled = true;
		else
			self.controlsEnabled = false;
		end
	end

	if (GameplayNotificationBus.GetCurrentBusId() == self.lookLeftRightForcedEventId) then
		--Debug.Log("lookLeftRightForcedEvent: " .. tostring(value));
		self.InputValues.LookLeftRight = value;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.lookUpDownForcedEventId) then
		--Debug.Log("lLookUpDownForcedEvent: " .. tostring(value));
		self.InputValues.LookUpDown = value;
	end

	
end

function cameracontroller:OnEventUpdating(value)

	local debugCamMovement = false;

	if (self.controlsEnabled == true) then
    	if (GameplayNotificationBus.GetCurrentBusId() == self.lookLeftRightEventId) then
    	    self.InputValues.LookLeftRight = self:SquareWithSign(value);
    	elseif (GameplayNotificationBus.GetCurrentBusId() == self.lookUpDownEventId) then
    	    self.InputValues.LookUpDown = self:SquareWithSign(value);
    	elseif (GameplayNotificationBus.GetCurrentBusId() == self.lookLeftRightKMEventId) then
    	    self.InputValues.LookLeftRight = value * self.Properties.MouseLookSensitivity;
    	elseif (GameplayNotificationBus.GetCurrentBusId() == self.lookUpDownKMEventId) then
    	    self.InputValues.LookUpDown = value * self.Properties.MouseLookSensitivity;
		end
    end
	
	-- Debug input for moving the camera.
	if (GameplayNotificationBus.GetCurrentBusId() == self.debugNumPad1EventId) then
		self.Properties.CameraFollowDistanceBelow = self.Properties.CameraFollowDistanceBelow - value;
		debugCamMovement = true;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.debugNumPad2EventId) then
		self.Properties.CameraFollowDistance = self.Properties.CameraFollowDistance + value;
		debugCamMovement = true;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.debugNumPad3EventId) then
		self.Properties.CameraFollowDistanceBelow = self.Properties.CameraFollowDistanceBelow + value;
		debugCamMovement = true;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.debugNumPad4EventId) then
		self.Properties.CameraFollowOffset = self.Properties.CameraFollowOffset - value;
		debugCamMovement = true;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.debugNumPad5EventId) then
		self.Properties.CameraFollowDistanceBelow = self.CameraFollowDistanceBelowOriginal;
		self.Properties.CameraFollowDistance = self.CameraFollowDistanceOriginal;
		self.Properties.CameraFollowHeight = self.CameraFollowHeightOriginal;
		self.Properties.CameraFollowOffset = self.CameraFollowOffsetOriginal;
		debugCamMovement = true;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.debugNumPad6EventId) then
		self.Properties.CameraFollowOffset = self.Properties.CameraFollowOffset + value;
		debugCamMovement = true;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.debugNumPad7EventId) then
		self.Properties.CameraFollowHeight = self.Properties.CameraFollowHeight + value;
		debugCamMovement = true;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.debugNumPad8EventId) then
		self.Properties.CameraFollowDistance = self.Properties.CameraFollowDistance - value;
		debugCamMovement = true;
	elseif (GameplayNotificationBus.GetCurrentBusId() == self.debugNumPad9EventId) then
		self.Properties.CameraFollowHeight = self.Properties.CameraFollowHeight - value;
		debugCamMovement = true;
	end
	
	if (debugCamMovement == true) then
		Debug.Log("CameraFollowDistanceBelow: " .. tostring(self.Properties.CameraFollowDistanceBelow) .. ", CameraFollowDistance: " .. tostring(self.Properties.CameraFollowDistance) .. ", CameraFollowHeight: " .. tostring(self.Properties.CameraFollowHeight) .. ", CameraFollowOffset: " .. tostring(self.Properties.CameraFollowOffset));
	end

end

function cameracontroller:OnEventEnd()

    if (GameplayNotificationBus.GetCurrentBusId() == self.lookLeftRightEventId) then
        self.InputValues.LookLeftRight = 0;
    elseif (GameplayNotificationBus.GetCurrentBusId() == self.lookUpDownEventId) then
        self.InputValues.LookUpDown = 0;
    elseif (GameplayNotificationBus.GetCurrentBusId() == self.lookLeftRightKMEventId) then
        self.InputValues.LookLeftRight = 0;
    elseif (GameplayNotificationBus.GetCurrentBusId() == self.lookUpDownKMEventId) then
        self.InputValues.LookUpDown = 0;
    elseif (GameplayNotificationBus.GetCurrentBusId() == self.lookLeftRightForcedEventId) then
        self.InputValues.LookLeftRight = 0;
    elseif (GameplayNotificationBus.GetCurrentBusId() == self.lookUpDownForcedEventId) then
        self.InputValues.LookUpDown = 0;
    end

end

return cameracontroller;