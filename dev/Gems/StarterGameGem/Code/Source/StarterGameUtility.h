
#pragma once

#include <AzCore/Component/EntityId.h>
#include <AzCore/Memory/SystemAllocator.h>
#include <MathConversion.h>

#include <AzCore/Component/ComponentBus.h>
#include <AzCore/EBus/EBus.h>
#include <LmbrCentral/Physics/PhysicsSystemComponentBus.h>
#include <LmbrCentral/Physics/PhysicsComponentBus.h>
#include <AZCore/Component/TransformBus.h>
#include <LmbrCentral/Scripting/TagComponentBus.h>

#include <AzCore/Casting/numeric_cast.h>
#include <IPhysics.h>
#include <physinterface.h>

namespace AZ
{
	class ReflectContext;
}

namespace StarterGameGem
{
	struct GotShotParams
	{
		AZ_TYPE_INFO(GotShotParams, "{BC1EA56B-4099-41E7-BCE3-2163BBE26D04}");
		AZ_CLASS_ALLOCATOR(GotShotParams, AZ::SystemAllocator, 0);

		GotShotParams()
			: m_damage(0.0f)
			, m_immediatelyRagdoll(false)
		{}

		float m_damage;
		AZ::Vector3 m_direction;
		AZ::EntityId m_assailant;
		bool m_immediatelyRagdoll;

	};

	/*!
	* Wrapper for utility functions exposed to Lua for StarterGame.
	*/
	class StarterGameUtility
	{
	public:
		AZ_TYPE_INFO(StarterGameUtility, "{E8AD1E8A-A67D-44EB-8A08-B6881FD72F2F}");
		AZ_CLASS_ALLOCATOR(StarterGameUtility, AZ::SystemAllocator, 0);

		static void Reflect(AZ::ReflectContext* reflection);

		static bool SetShaderFloat(AZ::EntityId entityId, const AZStd::string& paramName, float var);
		static bool SetShaderVec3(AZ::EntityId entityId, const AZStd::string& paramName, const AZ::Vector3& var);
		static void ReplaceMaterialWithClone(AZ::EntityId entityId);
		static void RestoreOriginalMaterial(AZ::EntityId entityId);

	};

} // namespace StarterGameGem
