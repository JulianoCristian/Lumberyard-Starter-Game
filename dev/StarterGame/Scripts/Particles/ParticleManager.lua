
local particlemanager =
{
	Properties =
	{
		
	},
}

function particlemanager:OnActivate()

	self.eventId = GameplayNotificationId(self.entityId, "SpawnParticleEvent");
	self.handler = GameplayNotificationBus.Connect(self, self.eventId);

end

function particlemanager:OnDeactivate()

	self.handler:Disconnect();
	self.handler = nil;

end

function particlemanager:OnEventBegin(value)

	--Debug.Log("Something");
	if (GameplayNotificationBus.GetCurrentBusId() == self.eventId) then
		--Debug.Log("Passing on to children!");
		ParticleManagerComponentRequestsBus.Event.SpawnParticle(self.entityId, value);
	end

end

return particlemanager;