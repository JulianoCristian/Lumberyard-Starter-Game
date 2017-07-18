
#pragma once

#include <AzCore/Component/Component.h>
#include <AzCore/Component/EntityId.h>
#include <AzCore/Memory/SystemAllocator.h>

#include <AzCore/Math/Transform.h>

namespace AZ
{
	class ReflectContext;
}

namespace StarterGameGem
{
	struct ParticleSpawnerParams
	{
		AZ_TYPE_INFO(ParticleSpawnerParams, "{E1E4BB32-1B51-4CB8-A351-9CEA7DD5EE8C}");
		AZ_CLASS_ALLOCATOR(ParticleSpawnerParams, AZ::SystemAllocator, 0);

		ParticleSpawnerParams()
			: m_attachToTargetEntity(false)
		{}

		AZStd::string m_eventName;
		AZ::Transform m_transform;
		AZ::EntityId m_owner;
		AZ::EntityId m_target;
		bool m_attachToTargetEntity;

		AZ::Vector3 m_impulse;

		// For decals.
		short m_surfaceType;

	};

	/*!
	* ParticleManagerComponentRequests
	* Messages serviced by the ParticleManagerComponent
	*/
	class ParticleManagerComponentRequests
		: public AZ::ComponentBus
	{
	public:
		virtual ~ParticleManagerComponentRequests() {}

		//! Spawns a particle.
		virtual void SpawnParticle(const ParticleSpawnerParams& params) = 0;

	};

	using ParticleManagerComponentRequestsBus = AZ::EBus<ParticleManagerComponentRequests>;


	class ParticleManagerComponent
		: public AZ::Component
		, private ParticleManagerComponentRequestsBus::Handler
	{
	public:
		AZ_COMPONENT(ParticleManagerComponent, "{35991A4D-69E8-4520-85DB-E8866225CAAE}");

		//////////////////////////////////////////////////////////////////////////
		// AZ::Component interface implementation
		void Init() override;
		void Activate() override;
		void Deactivate() override;
		//////////////////////////////////////////////////////////////////////////

		// Required Reflect function.
		static void Reflect(AZ::ReflectContext* context);

		//////////////////////////////////////////////////////////////////////////
		// ParticleManagerComponentRequestsBus::Handler
		void SpawnParticle(const ParticleSpawnerParams& params) override;

	private:


	};

} // namespace StarterGameGem
