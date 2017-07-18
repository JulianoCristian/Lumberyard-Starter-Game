
#include "StdAfx.h"

#include <AzCore/RTTI/BehaviorContext.h>
#include <AzCore/Serialization/SerializeContext.h>
#include <AzCore/Serialization/EditContext.h>

#include "StarterGameGemSystemComponent.h"

#include "Config.h"
#include "StarterGameUtility.h"

namespace StarterGameGem
{
    void StarterGameGemSystemComponent::Reflect(AZ::ReflectContext* context)
    {
        if (AZ::SerializeContext* serialize = azrtti_cast<AZ::SerializeContext*>(context))
        {
            serialize->Class<StarterGameGemSystemComponent, AZ::Component>()
                ->Version(0)
                ->SerializerForEmptyClass();

            if (AZ::EditContext* ec = serialize->GetEditContext())
            {
                ec->Class<StarterGameGemSystemComponent>("StarterGameGem", "[Description of functionality provided by this System Component]")
                    ->ClassElement(AZ::Edit::ClassElements::EditorData, "")
                        // ->Attribute(AZ::Edit::Attributes::Category, "") Set a category
                        ->Attribute(AZ::Edit::Attributes::AppearsInAddComponentMenu, AZ_CRC("System"))
                        ->Attribute(AZ::Edit::Attributes::AutoExpand, true)
                    ;
            }
        }

		if (AZ::BehaviorContext* behaviorContext = azrtti_cast<AZ::BehaviorContext*>(context))
		{
			Config::Reflect(behaviorContext);
			StarterGameUtility::Reflect(behaviorContext);
		}
    }

    void StarterGameGemSystemComponent::GetProvidedServices(AZ::ComponentDescriptor::DependencyArrayType& provided)
    {
        provided.push_back(AZ_CRC("StarterGameGemService"));
    }

    void StarterGameGemSystemComponent::GetIncompatibleServices(AZ::ComponentDescriptor::DependencyArrayType& incompatible)
    {
        incompatible.push_back(AZ_CRC("StarterGameGemService"));
    }

    void StarterGameGemSystemComponent::GetRequiredServices(AZ::ComponentDescriptor::DependencyArrayType& required)
    {
        (void)required;
    }

    void StarterGameGemSystemComponent::GetDependentServices(AZ::ComponentDescriptor::DependencyArrayType& dependent)
    {
        (void)dependent;
    }

    void StarterGameGemSystemComponent::Init()
    {
    }

    void StarterGameGemSystemComponent::Activate()
    {
        StarterGameGemRequestBus::Handler::BusConnect();
    }

    void StarterGameGemSystemComponent::Deactivate()
    {
        StarterGameGemRequestBus::Handler::BusDisconnect();
    }
}
