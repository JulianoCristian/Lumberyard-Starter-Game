local utilities = require "scripts/common/utilities"

local aispawntrigger = {
	Properties = {
		AISpawnGroup = { default = "", description = "The spawn group to be triggered when the player enters the trigger." }, 		
	},
}

function aispawntrigger:OnActivate()
	self.triggerHandler = TriggerAreaNotificationBus.Connect(self, self.entityId);
	self.enteredAreaId = GameplayNotificationId(EntityId(), "EnteredAITrigger");
	self.exitedAreaId = GameplayNotificationId(EntityId(),"ExitedAITrigger");
end

function aispawntrigger:OnDeactivate()
	self.triggerHandler:Disconnect();
end

function aispawntrigger:OnTriggerAreaEntered(entityId)
	if (not utilities.DebugManagerGetBool("PreventAIDisabling", false)) then
		GameplayNotificationBus.Event.OnEventBegin(self.enteredAreaId, self.Properties.AISpawnGroup);
	end
end

function aispawntrigger:OnTriggerAreaExited(entityId)
	if (not utilities.DebugManagerGetBool("PreventAIDisabling", false)) then
		GameplayNotificationBus.Event.OnEventBegin(self.exitedAreaId, self.Properties.AISpawnGroup);
	end
end

return aispawntrigger;