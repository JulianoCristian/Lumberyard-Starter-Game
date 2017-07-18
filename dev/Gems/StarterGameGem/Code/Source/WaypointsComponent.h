
#pragma once

#include <AzCore/Component/Component.h>
#include <AzCore/Component/EntityId.h>
#include <AzCore/Memory/SystemAllocator.h>
#include <MathConversion.h>

#include <AzCore/Component/ComponentBus.h>
#include <AzCore/Component/TickBus.h>
#include <AzCore/EBus/EBus.h>
#include <LmbrCentral/Physics/PhysicsSystemComponentBus.h>

namespace AZ
{
	class ReflectContext;
}

namespace StarterGameGem
{

	typedef AZStd::vector<AZ::EntityId> VecOfEntityIds;

	/*!
	* WaypointsComponentRequests
	* Messages serviced by the WaypointsComponent
	*/
	class WaypointsComponentRequests
		: public AZ::ComponentBus
	{
	public:
		virtual ~WaypointsComponentRequests() {}

		//! Gets the first waypoint in the list.
		virtual AZ::EntityId GetFirstWaypoint() = 0;
		//! Gets the current waypoint in the list.
		virtual AZ::EntityId GetCurrentWaypoint() { return AZ::EntityId(0); }
		//! Gets the next waypoint in the list.
		virtual AZ::EntityId GetNextWaypoint() = 0;

		//! Gets the number of waypoints in the list.
		virtual int GetWaypointCount() = 0;

		//! Clones the waypoints from the specified entity into this component.
		virtual void CloneWaypoints(const AZ::EntityId& srcEntityId) = 0;
		//! Get the waypoint component.
		virtual VecOfEntityIds* GetWaypoints() { return nullptr; }

	};

	using WaypointsComponentRequestsBus = AZ::EBus<WaypointsComponentRequests>;


	class WaypointsComponent
		: public AZ::Component
		, private AZ::TickBus::Handler
		, private WaypointsComponentRequestsBus::Handler
	{
	public:
		AZ_COMPONENT(WaypointsComponent, "{3259A366-D177-4B5B-B047-2DD3CE93F984}");

		//////////////////////////////////////////////////////////////////////////
		// AZ::Component interface implementation
		void Init() override;
		void Activate() override;
		void Deactivate() override;
		//////////////////////////////////////////////////////////////////////////

		// Required Reflect function.
		static void Reflect(AZ::ReflectContext* context);

		//////////////////////////////////////////////////////////////////////////
		// AZ::TickBus interface implementation
		void OnTick(float deltaTime, AZ::ScriptTimePoint time) override;
		//////////////////////////////////////////////////////////////////////////

		//////////////////////////////////////////////////////////////////////////
		// WaypointsComponentRequestsBus::Handler
		AZ::EntityId GetFirstWaypoint() override;
		AZ::EntityId GetCurrentWaypoint() override;
		AZ::EntityId GetNextWaypoint() override;
		int GetWaypointCount() override;

		void CloneWaypoints(const AZ::EntityId& srcEntityId) override;
		VecOfEntityIds* GetWaypoints() override;

	private:
		VecOfEntityIds m_waypoints;
		AZ::u32 m_currentWaypoint;

	};

} // namespace StarterGameGem
