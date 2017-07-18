#pragma once

#include <AzCore/Component/Component.h>
#include <AzCore/Math/Transform.h>
#include <AzCore/Prefab/PrefabAsset.h>
#include <AzFramework/Entity/EntityContextBus.h>
#include <AzCore/Component/TickBus.h>

namespace StarterGameGem
{
	/*!
	* LineRendererRequests
	* Messages serviced by the LineRendererComponent.
	*/
	class LineRendererRequests
		: public AZ::ComponentBus
	{
	public:
		virtual ~LineRendererRequests() {}

		//! Set the start position of the line.
		virtual void SetStartAndEnd(const AZ::Vector3& start, const AZ::Vector3& end, const AZ::Vector3& camPos) = 0;
		virtual void SetVisible(bool visible) = 0;
	};

	using LineRendererRequestBus = AZ::EBus<LineRendererRequests>;

	class LineRendererComponent
		: public AZ::Component
		, private LineRendererRequestBus::Handler
		, private AZ::TickBus::Handler
	{
	public:
		AZ_COMPONENT(LineRendererComponent, "{59C88668-7F2E-4D4D-98A3-A3C1743F0D11}");

		LineRendererComponent();

		//////////////////////////////////////////////////////////////////////////
		// AZ::Component interface implementation
		void Init() override		{}
		void Activate() override;
		void Deactivate() override;
		//////////////////////////////////////////////////////////////////////////

		//////////////////////////////////////////////////////////////////////////
		// AZ::TickBus interface implementation
		void OnTick(float deltaTime, AZ::ScriptTimePoint time) override;
		//////////////////////////////////////////////////////////////////////////

		// Required Reflect function.
		static void Reflect(AZ::ReflectContext* context);

		// Optional functions for defining provided and dependent services.
		static void GetRequiredServices(AZ::ComponentDescriptor::DependencyArrayType& required)
		{
			required.push_back(AZ_CRC("TransformService"));
		}

		//////////////////////////////////////////////////////////////////////////
		// LineRendererComponentRequestBus::Handler
		void SetStartAndEnd(const AZ::Vector3& start, const AZ::Vector3& end, const AZ::Vector3& camPos) override;
		void SetVisible(bool visible) override;

	protected:
		void SetMaterialVars(float age);
		bool SetShaderVar(IMaterial* mat, const char* paramName, float var);

		AZ::EntityId m_lineId;

		float m_radius;
		bool m_fade;
		bool m_age;
		float m_duration;

		bool m_visible;

		float m_timeToVanish;
		float m_scale;

		bool m_firstUpdate;

		_smart_ptr<IMaterial> m_originalMaterial;
		_smart_ptr<IMaterial> m_clonedMaterial;

	};

}
