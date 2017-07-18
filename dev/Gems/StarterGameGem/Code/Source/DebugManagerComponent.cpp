
#include "StdAfx.h"
#include "DebugManagerComponent.h"

#include <AzCore/RTTI/BehaviorContext.h>
#include <AzCore/Component/TransformBus.h>
#include <AzCore/Component/ComponentApplicationBus.h>
#include <AzCore/Serialization/EditContext.h>
#include <AzCore/Serialization/SerializeContext.h>
#include <AzCore/Component/Entity.h>

#include <GameplayEventBus.h>

namespace StarterGameGem
{

	//-------------------------------------------
	// DebugManagerComponent
	//-------------------------------------------
	void DebugManagerComponent::Init()
	{
	}

	void DebugManagerComponent::Activate()
	{
		DebugManagerComponentRequestsBus::Handler::BusConnect(GetEntityId());
	}

	void DebugManagerComponent::Deactivate()
	{
		DebugManagerComponentRequestsBus::Handler::BusDisconnect();
	}

	void DebugManagerComponent::Reflect(AZ::ReflectContext* context)
	{
		AZ::SerializeContext* serializeContext = azrtti_cast<AZ::SerializeContext*>(context);
		if (serializeContext)
		{
			serializeContext->Class<DebugManagerComponent>()
				->Version(1)
				->Field("Bools", &DebugManagerComponent::m_bools)
				->Field("Floats", &DebugManagerComponent::m_floats)
			;

			AZ::EditContext* editContext = serializeContext->GetEditContext();
			if (editContext)
			{
				editContext->Class<DebugManagerComponent>("Debug Manager", "Holds and distributes debug variables")
					->ClassElement(AZ::Edit::ClassElements::EditorData, "")
					->Attribute(AZ::Edit::Attributes::Category, "Game")
					->Attribute(AZ::Edit::Attributes::Icon, "Editor/Icons/Components/SG_Icon.png")
					->Attribute(AZ::Edit::Attributes::ViewportIcon, "Editor/Icons/Components/Viewport/SG_Icon.dds")
					->Attribute(AZ::Edit::Attributes::AppearsInAddComponentMenu, AZ_CRC("Game"))
					->Attribute(AZ::Edit::Attributes::Visibility, AZ_CRC("PropertyVisibility_ShowChildrenOnly", 0xef428f20))
					//->DataElement(0, &DebugManagerComponent::m_objects, "Objects", "Lists of objects.")
				;
			}
		}

		if (AZ::BehaviorContext* behaviorContext = azrtti_cast<AZ::BehaviorContext*>(context))
		{
			behaviorContext->EBus<DebugManagerComponentRequestsBus>("DebugManagerComponentRequestsBus")
				->Event("GetDebugBool", &DebugManagerComponentRequestsBus::Events::GetDebugBool)
				->Event("GetDebugFloat", &DebugManagerComponentRequestsBus::Events::GetDebugFloat)
				->Event("SetDebugBool", &DebugManagerComponentRequestsBus::Events::SetDebugBool)
				->Event("SetDebugFloat", &DebugManagerComponentRequestsBus::Events::SetDebugFloat)
				;
		}
	}

	void DebugManagerComponent::SetDebugBool(const AZStd::string& eventName, bool value)
	{
		int index = 0;
		for (index; index < m_bools.size(); ++index)
		{
			if (strcmp(m_bools[index].m_eventName.c_str(), eventName.c_str()) == 0)
			{
				break;
			}
		}

		if (index == m_bools.size())
		{
			// Add the variable.
			DebugVarBool newVar;
			newVar.m_eventName = eventName;
			newVar.m_value = value;
			m_bools.push_back(newVar);
		}
		else
		{
			// Set the variable.
			m_bools[index].m_value = value;
		}
	}

	void DebugManagerComponent::SetDebugFloat(const AZStd::string& eventName, float value)
	{
		int index = 0;
		for (index; index < m_floats.size(); ++index)
		{
			if (strcmp(m_floats[index].m_eventName.c_str(), eventName.c_str()) == 0)
			{
				break;
			}
		}

		if (index == m_floats.size())
		{
			// Add the variable.
			DebugVarFloat newVar;
			newVar.m_eventName = eventName;
			newVar.m_value = value;
			m_floats.push_back(newVar);
		}
		else
		{
			// Set the variable.
			m_floats[index].m_value = value;
		}
	}

	bool DebugManagerComponent::GetDebugBool(const AZStd::string& eventName)
	{
		int index = 0;
		for (index; index < m_bools.size(); ++index)
		{
			if (strcmp(m_bools[index].m_eventName.c_str(), eventName.c_str()) == 0)
			{
				break;
			}
		}

		bool res = false;
		if (index == m_bools.size())
		{
			// Couldn't find the variable.
			CryLog("Debug Manager: variable %s doesn't exist.", eventName.c_str());
		}
		else
		{
			// Get the variable.
			res = m_bools[index].m_value;
		}

		return res;
	}

	float DebugManagerComponent::GetDebugFloat(const AZStd::string& eventName)
	{
		int index = 0;
		for (index; index < m_floats.size(); ++index)
		{
			if (strcmp(m_floats[index].m_eventName.c_str(), eventName.c_str()) == 0)
			{
				break;
			}
		}

		float res = 0.0f;
		if (index == m_floats.size())
		{
			// Couldn't find the variable.
			CryLog("Debug Manager: variable %s doesn't exist.", eventName.c_str());
		}
		else
		{
			// Get the variable.
			res = m_floats[index].m_value;
		}

		return res;
	}

}
