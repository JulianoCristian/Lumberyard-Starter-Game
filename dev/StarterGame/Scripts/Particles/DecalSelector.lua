local utilities = require "scripts/common/utilities"

local decalselector =
{
	Properties =
	{
		DecalSpawnEvent = { default = "SpawnDecalName", description = "The name of the event that will trigger the spawner." },
	},
}

function decalselector:OnActivate()

	self.eventId = GameplayNotificationId(self.entityId, self.Properties.DecalSpawnEvent);
	self.handler = GameplayNotificationBus.Connect(self, self.eventId);

end

function decalselector:OnDeactivate()

	self.handler:Disconnect();
	self.handler = nil;

end

function decalselector:OnEventBegin(value)

	local decalsEnabled = utilities.DebugManagerGetBool("EnableDynamicDecals", true);
	if (not decalsEnabled) then
		return;
	end

	if (GameplayNotificationBus.GetCurrentBusId() == self.eventId) then
		--Debug.Log("Passing on to children!");
		
		-- TODO: This is a temporary workaround for not rendering decals on movable objects.
		-- The engine doesn't render decals on objects that are moving and then they pop
		-- back in when the object stops moving. As a result, we'll just not spawn any decals
		-- onto component entities (it's a brute-force method, but covers most cases).
		if (value.attachToEntity == false) then
			DecalSelectorComponentRequestsBus.Event.SpawnDecal(self.entityId, value);
		end
	end

end

return decalselector;