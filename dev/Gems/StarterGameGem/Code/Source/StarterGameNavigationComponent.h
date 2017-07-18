
#pragma once

#include <AzCore/Memory/SystemAllocator.h>

#include <AzCore/Component/Component.h>
#include <AzCore/Component/ComponentBus.h>
#include <AzCore/EBus/EBus.h>
#include <AZCore/Component/TransformBus.h>

#include <LmbrCentral/Ai/NavigationComponentBus.h>

namespace AZ
{
	class ReflectContext;
}

namespace StarterGameGem
{

	class StarterGameNavigationComponentNotifications
        : public AZ::ComponentBus
	{
	public:
        //////////////////////////////////////////////////////////////////////////
        // EBusTraits overrides (Configuring this Ebus)
        static const AZ::EBusHandlerPolicy HandlerPolicy = AZ::EBusHandlerPolicy::Multiple;


        virtual ~StarterGameNavigationComponentNotifications() {}

		/**
        * Indicates that a path has been found for the indicated request
        * @param requestId Id of the request for which path has been found
        * @param firstPoint The first point on the path that was calculated by the Pathfinder
        * @return boolean value indicating whether this path is to be traversed or not
        */
        virtual bool OnPathFoundFirstPoint(LmbrCentral::PathfindRequest::NavigationRequestId requestId, AZ::Vector3 firstPoint)
        {
            return true;
        };

	};

    using StarterGameNavigationComponentNotificationBus = AZ::EBus<StarterGameNavigationComponentNotifications>;


	/*!
	* Wrapper for performing Navigation.
	*/
	class StarterGameNavigationComponent
		: public AZ::Component
		, public LmbrCentral::NavigationComponentNotificationBus::Handler
	{
	public:
		AZ_COMPONENT(StarterGameNavigationComponent, "{5EB6DEEF-CB8C-4AC8-BEF6-DF8FAD216C17}");

		//////////////////////////////////////////////////////////////////////////
		// AZ::Component interface implementation
		void Init() override;
		void Activate() override;
		void Deactivate() override;

		//////////////////////////////////////////////////////////////////////////
		// LmbrCentral::NavigationComponentNofiticationBus::Handler overrides
		bool OnPathFound(LmbrCentral::PathfindRequest::NavigationRequestId requestId, AZStd::shared_ptr<const INavPath> currentPath) override;

		static void Reflect(AZ::ReflectContext* reflection);

		static void GetRequiredServices(AZ::ComponentDescriptor::DependencyArrayType& required)
		{
			required.push_back(AZ_CRC("TransformService", 0x8ee22c50));
			required.push_back(AZ_CRC("NavigationService", 0xf31e77fe));
		}

	};

} // namespace StarterGameGem
