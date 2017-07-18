
#include "StdAfx.h"
#include "StarterGameGemModule.h"

#include "StarterGameCVars.h"

#include "StarterGameGemSystemComponent.h"
#include "LineRendererComponent.h"
#include "WaypointsComponent.h"
#include "ParticleManagerComponent.h"
#include "ObjectListerComponent.h"
#include "DebugManagerComponent.h"
#include "DecalSelectorComponent.h"
#include "StarterGameNavigationComponent.h"
#include "VisualiseRangeComponent.h"
#include "StatComponent.h"


namespace StarterGameGem
{

	StarterGameGemModule::StarterGameGemModule()
		: CryHooksModule()
	{
		// Push results of [MyComponent]::CreateDescriptor() into m_descriptors here.
		m_descriptors.insert(m_descriptors.end(), {
			StarterGameGemSystemComponent::CreateDescriptor(),
			LineRendererComponent::CreateDescriptor(),
			WaypointsComponent::CreateDescriptor(),
			ParticleManagerComponent::CreateDescriptor(),
			ObjectListerComponent::CreateDescriptor(),
			DebugManagerComponent::CreateDescriptor(),
			DecalSelectorComponent::CreateDescriptor(),
			VisualiseRangeComponent::CreateDescriptor(),
			StarterGameNavigationComponent::CreateDescriptor(),
			StatComponent::CreateDescriptor(),
		});
	}

	void StarterGameGemModule::OnSystemEvent(ESystemEvent e, UINT_PTR wparam, UINT_PTR lparam)
	{
		switch(e)
		{
			case ESYSTEM_EVENT_GAME_POST_INIT:
				PostSystemInit();
				break;

			case ESYSTEM_EVENT_FULL_SHUTDOWN:
			case ESYSTEM_EVENT_FAST_SHUTDOWN:
				Shutdown();
				break;
		}
	}

	void StarterGameGemModule::PostSystemInit()
	{
		StarterGameCVars::GetInstance();
	}

	void StarterGameGemModule::Shutdown()
	{
		StarterGameCVars::DeregisterCVars();
	}

	AZ::ComponentTypeList StarterGameGemModule::GetRequiredSystemComponents() const
	{
		return AZ::ComponentTypeList{
			azrtti_typeid<StarterGameGemSystemComponent>(),
		};
	}

}
