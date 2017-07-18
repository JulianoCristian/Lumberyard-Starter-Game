
local cameramanager =
{
	Properties =
	{
		InitialCamera = { default = EntityId(), },
		InitialCameraTag = { default = "PlayerCamera" },
		
		ActiveCamTag = { default = "ActiveCamera", description = "The tag that's used and applied at runtime to identify the active camera." },
	},
}

function cameramanager:OnActivate()

	self.activateEventId = GameplayNotificationId(self.entityId, "ActivateCameraEvent");
	self.activateHandler = GameplayNotificationBus.Connect(self, self.activateEventId);
	
	-- We can't set the initial camera here because there's no gaurantee that a camera won't
	-- be initialised AFTER the camera manager and override what we've set here. As a result
	-- we need to join the tick bus so we can set the initial camera on the first tick and
	-- then disconnect from the tick bus (since there shouldn't be anything that we need to
	-- do every frame).
	self.tickHandler = TickBus.Connect(self);
end
	
function cameramanager:OnTick(deltaTime, timePoint)
	
	local startingCam = self.Properties.InitialCamera;
	if (not startingCam:IsValid()) then
		-- TODO: Change this to a 'Warning()'.
		Debug.Log("Camera Manager: No initial camera has been set - finding and using the camera tagged with " .. self.Properties.InitialCameraTag .. " instead.");
		startingCam = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32(self.Properties.InitialCameraTag));
		
		-- If we couldn't find a camera with the fallback tag then we can't reliably assume
		-- which camera became the active one.
		if ((startingCam == nil) or not (startingCam:IsValid())) then
			-- TODO: Change this to an 'Assert()'.
			Debug.Log("Camera Manager: No initial camera could be found.");
		end
	end
	self:ActivateCam(startingCam);
	
	-- This function is a work-around because we can't disconnect the tick handler directly
	-- inside the 'OnTick()' function, but we can inside another function; apparently, even
	-- if that function is called FROM the 'OnTick()' function.
	self:StopTicking();

end

function cameramanager:StopTicking()

	self.tickHandler:Disconnect();
	self.tickHandler = nil;
	
end

function cameramanager:OnDeactivate()

	self.activateHandler:Disconnect();
	self.activateHandler = nil;

end

function cameramanager:ActivateCam(camToActivate)

	local crcTag = Crc32(self.Properties.ActiveCamTag);
	local c1Tags = TagComponentRequestBus.Event.AddTag(camToActivate, crcTag);

	local camToDeactivate = TagGlobalRequestBus.Event.RequestTaggedEntities(crcTag);
	if ((camToDeactivate ~= nil) and (camToDeactivate:IsValid())) then
		local c2Tags = TagComponentRequestBus.Event.RemoveTag(camToDeactivate, crcTag);
	end
	
	--Debug.Log("Activating camera: " .. tostring(camToActivate));
	CameraRequestBus.Event.MakeActiveView(camToActivate);

end

function cameramanager:OnEventBegin(value)

	if (GameplayNotificationBus.GetCurrentBusId() == self.activateEventId) then
		self:ActivateCam(value);
	end

end

return cameramanager;