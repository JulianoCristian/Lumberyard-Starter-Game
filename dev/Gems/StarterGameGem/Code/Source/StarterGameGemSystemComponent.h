
#pragma once

#include <AzCore/Component/Component.h>

#include <StarterGameGem/StarterGameGemBus.h>

namespace StarterGameGem
{
    class StarterGameGemSystemComponent
        : public AZ::Component
        , protected StarterGameGemRequestBus::Handler
    {
    public:
        AZ_COMPONENT(StarterGameGemSystemComponent, "{97D0C797-07D3-4192-B4C6-87C2F6D0A4E5}");

        static void Reflect(AZ::ReflectContext* context);

        static void GetProvidedServices(AZ::ComponentDescriptor::DependencyArrayType& provided);
        static void GetIncompatibleServices(AZ::ComponentDescriptor::DependencyArrayType& incompatible);
        static void GetRequiredServices(AZ::ComponentDescriptor::DependencyArrayType& required);
        static void GetDependentServices(AZ::ComponentDescriptor::DependencyArrayType& dependent);

    protected:
        ////////////////////////////////////////////////////////////////////////
        // StarterGameGemRequestBus interface implementation

        ////////////////////////////////////////////////////////////////////////

        ////////////////////////////////////////////////////////////////////////
        // AZ::Component interface implementation
        void Init() override;
        void Activate() override;
        void Deactivate() override;
        ////////////////////////////////////////////////////////////////////////
    };
}
