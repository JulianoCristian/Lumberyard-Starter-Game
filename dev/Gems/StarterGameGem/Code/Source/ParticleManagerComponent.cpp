
#include "StdAfx.h"
#include "ParticleManagerComponent.h"

#include <AzCore/RTTI/BehaviorContext.h>
#include <AzCore/Serialization/SerializeContext.h>
#include <AzCore/Component/TransformBus.h>
#include <AzCore/Serialization/EditContext.h>
#include <AzCore/Component/ComponentApplicationBus.h>

#include <AzCore/Serialization/EditContext.h>
#include <AzCore/Serialization/SerializeContext.h>
#include <AzCore/Component/ComponentApplicationBus.h>
#include <AzCore/Component/Entity.h>

#include <GameplayEventBus.h>

namespace StarterGameGem
{
	void ParticleManagerComponent::Init()
	{
	}

	void ParticleManagerComponent::Activate()
	{
		ParticleManagerComponentRequestsBus::Handler::BusConnect(GetEntityId());
	}

	void ParticleManagerComponent::Deactivate()
	{
		ParticleManagerComponentRequestsBus::Handler::BusDisconnect();
	}

	void ParticleManagerComponent::Reflect(AZ::ReflectContext* reflection)
	{
		AZ::SerializeContext* serializeContext = azrtti_cast<AZ::SerializeContext*>(reflection);
		if (serializeContext)
		{
			serializeContext->Class<ParticleManagerComponent>()
				->Version(1)
				//->Field("Waypoints", &ParticleManagerComponent::m_waypoints)
				//->Field("CurrentWaypoint", &ParticleManagerComponent::m_currentWaypoint)
			;

			AZ::EditContext* editContext = serializeContext->GetEditContext();
			if (editContext)
			{
				editContext->Class<ParticleManagerComponent>("Particle Manager", "Provides an interface to spawn particles")
					->ClassElement(AZ::Edit::ClassElements::EditorData, "")
					->Attribute(AZ::Edit::Attributes::Category, "Rendering")
					->Attribute(AZ::Edit::Attributes::Icon, "Editor/Icons/Components/SG_Icon.png")
					->Attribute(AZ::Edit::Attributes::ViewportIcon, "Editor/Icons/Components/Viewport/SG_Icon.dds")
					->Attribute(AZ::Edit::Attributes::AppearsInAddComponentMenu, AZ_CRC("Game"))
					//->DataElement(0, &ParticleManagerComponent::m_waypoints, "Waypoints", "A list of waypoints.")
				;
			}
		}

		if (AZ::BehaviorContext* behavior = azrtti_cast<AZ::BehaviorContext*>(reflection))
		{
			// ParticleSpawner return type
			behavior->Class<ParticleSpawnerParams>("ParticleSpawnerParams")
				->Attribute(AZ::Script::Attributes::Storage, AZ::Script::Attributes::StorageType::Value)
				->Property("transform", BehaviorValueProperty(&ParticleSpawnerParams::m_transform))
				->Property("event", BehaviorValueProperty(&ParticleSpawnerParams::m_eventName))
				->Property("ownerId", BehaviorValueProperty(&ParticleSpawnerParams::m_owner))
				->Property("targetId", BehaviorValueProperty(&ParticleSpawnerParams::m_target))
                ->Property("attachToEntity", BehaviorValueProperty(&ParticleSpawnerParams::m_attachToTargetEntity))
				->Property("impulse", BehaviorValueProperty(&ParticleSpawnerParams::m_impulse))
				->Property("surfaceType", BehaviorValueProperty(&ParticleSpawnerParams::m_surfaceType))
				;

			behavior->EBus<ParticleManagerComponentRequestsBus>("ParticleManagerComponentRequestsBus")
				->Event("SpawnParticle", &ParticleManagerComponentRequestsBus::Events::SpawnParticle)
				;
		}
	}

	void ParticleManagerComponent::SpawnParticle(const ParticleSpawnerParams& params)
	{
		AZ::EntityId id = GetEntityId();
		AZStd::vector<AZ::EntityId> children;
		EBUS_EVENT_ID_RESULT(children, id, AZ::TransformBus, GetAllDescendants);

		AZStd::any paramToBus(params);

		for (int i = 0; i < children.size(); ++i)
		{
			// Broadcast this message to all of the particle manager's children.
			// One of them should be able to match the event name and the one that does spawns
			// their particle.
			AZ::GameplayNotificationId gameplayId = AZ::GameplayNotificationId(children[i], params.m_eventName.c_str());
			AZ::GameplayNotificationBus::Event(gameplayId, &AZ::GameplayNotificationBus::Events::OnEventBegin, paramToBus);
		}
	}

}
