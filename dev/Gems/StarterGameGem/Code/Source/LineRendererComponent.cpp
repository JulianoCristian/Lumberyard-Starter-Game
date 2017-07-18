
#include "stdafx.h"
#include "LineRendererComponent.h"

#include <AzCore/Serialization/EditContext.h>
#include <AzCore/RTTI/BehaviorContext.h>
#include <AzCore/Component/ComponentApplicationBus.h>
#include <AzCore/Component/Entity.h>
#include <AzCore/Component/TransformBus.h>
#include <LmbrCentral/Rendering/MeshComponentBus.h>


namespace StarterGameGem
{
	LineRendererComponent::LineRendererComponent()
		: m_lineId()
		, m_radius(1.0f)
		, m_fade(true)
		, m_age(true)
		, m_duration(0.1f)
		, m_visible(true)
		, m_firstUpdate(true)
		, m_originalMaterial(0)
		, m_clonedMaterial(0)
	{}

	void LineRendererComponent::Reflect(AZ::ReflectContext* reflection)
	{
		AZ::SerializeContext* serializeContext = azrtti_cast<AZ::SerializeContext*>(reflection);
		if (serializeContext)
		{
			serializeContext->Class<LineRendererComponent, AZ::Component>()
				->Version(1)
				->Field("LineEntity", &LineRendererComponent::m_lineId)
				->Field("Radius", &LineRendererComponent::m_radius)
				->Field("Fade", &LineRendererComponent::m_fade)
				->Field("Age", &LineRendererComponent::m_age)
				->Field("Duration", &LineRendererComponent::m_duration)
				->Field("Visible", &LineRendererComponent::m_visible)
				->Field("TimeToVanish", &LineRendererComponent::m_timeToVanish)
				->Field("Scale", &LineRendererComponent::m_scale)
			;

			AZ::EditContext* editContext = serializeContext->GetEditContext();
			if (editContext)
			{
				editContext->Class<LineRendererComponent>("Line Renderer Component", "Renders a line")
					->ClassElement(AZ::Edit::ClassElements::EditorData, "")
						->Attribute(AZ::Edit::Attributes::Category, "Rendering")
						->Attribute(AZ::Edit::Attributes::Icon, "Editor/Icons/Components/SG_Icon.png")
						->Attribute(AZ::Edit::Attributes::ViewportIcon, "Editor/Icons/Components/Viewport/SG_Icon.dds")
						->Attribute(AZ::Edit::Attributes::AppearsInAddComponentMenu, AZ_CRC("Game"))
						//->ClassElement(AZ::Edit::ClassElements::Group, "General")
						->DataElement(0, &LineRendererComponent::m_lineId, "Line Entity", "The entity that will be used as the line.")
							//->Attribute(AZ::Edit::Attributes::ChangeNotify, &TransformComponent::ParentChanged
							//->Attribute(AZ::Edit::Attributes::SliceCreationFlags, AZ::Edit::SliceCreationFlags::DontGatherReference)
						->DataElement(0, &LineRendererComponent::m_radius, "Radius", "The radius of the line.")
						->DataElement(0, &LineRendererComponent::m_age, "Age?", "Will age if ticked.")
						->ClassElement(AZ::Edit::ClassElements::Group, "Fade Out")
							->DataElement(0, &LineRendererComponent::m_fade, "Fade?", "Will fade out if ticked.")
							->DataElement(0, &LineRendererComponent::m_duration, "Duration", "The time the line will be visible for (in seconds).")
				;
			}
		}

		if (AZ::BehaviorContext* behaviorContext = azrtti_cast<AZ::BehaviorContext*>(reflection))
		{
			behaviorContext->EBus<LineRendererRequestBus>("LineRendererRequestBus")
				->Event("SetStartAndEnd", &LineRendererRequestBus::Events::SetStartAndEnd)
				->Event("SetVisible", &LineRendererRequestBus::Events::SetVisible)
				;
		}
	}

	void LineRendererComponent::Activate()
	{
		LineRendererRequestBus::Handler::BusConnect(GetEntityId());
		AZ::TickBus::Handler::BusConnect();
	}

	void LineRendererComponent::Deactivate()
	{
		if (m_originalMaterial)
		{
			// setting material to null restores the original material on the mesh
			LmbrCentral::MaterialRequestBus::Event(m_lineId, &LmbrCentral::MaterialRequestBus::Events::SetMaterial, nullptr);
			m_originalMaterial = 0;
		}
		if (m_clonedMaterial)
		{
			m_clonedMaterial = 0;
		}
		LineRendererRequestBus::Handler::BusDisconnect();
		AZ::TickBus::Handler::BusDisconnect();
	}

	void LineRendererComponent::OnTick(float deltaTime, AZ::ScriptTimePoint time)
	{
		if (m_firstUpdate)
		{
			// Create our own instance of the material.
			// If we don't do this then ALL lines will share the same material (and shader values).
			// Apparently I can't do this on the 'Init()' or 'Activate()' callbacks because the
			// material doesn't exist at those points.
			LmbrCentral::MaterialRequestBus::EventResult(m_originalMaterial, m_lineId, &LmbrCentral::MaterialRequestBus::Events::GetMaterial);
			if (m_originalMaterial)
			{
				m_clonedMaterial = gEnv->p3DEngine->GetMaterialManager()->CloneMaterial(m_originalMaterial);
				LmbrCentral::MaterialRequestBus::Event(m_lineId, &LmbrCentral::MaterialRequestBus::Events::SetMaterial, m_clonedMaterial);
			}
			m_firstUpdate = false;
		}

		if (m_visible)
		{
			m_timeToVanish -= deltaTime;
			if (m_timeToVanish <= 0.0f)
			{
				SetVisible(false);
			}
			else
			{
				// Gradually fade out the line.
				if (m_fade)
				{
					float age = 1.0f - (m_timeToVanish / m_duration);
					SetMaterialVars(age);
				}
			}
		}
	}

	void LineRendererComponent::SetStartAndEnd(const AZ::Vector3& start, const AZ::Vector3& end, const AZ::Vector3& camPos)
	{
		assert(m_lineId.IsValid());

		AZ::Vector3 distance = end - start;

		AZ::Vector3 forward =	distance.GetNormalized();
		AZ::Vector3 up =		camPos - start;
		AZ::Vector3 right =		forward.Cross(up).GetNormalized();
		up = right.Cross(forward);	// orthogonalize

		AZ::Transform transform = AZ::Transform::CreateIdentity();
		transform.SetColumn(0, right);
		transform.SetColumn(1, forward);
		transform.SetColumn(2, up);
		
		transform.SetTranslation(start + (forward * (distance.GetLength() / 2.0f)));

		// Scale it.
		m_scale = distance.GetLength();
		transform *= AZ::Transform::CreateScale(AZ::Vector3(m_radius, m_scale, 1.0f));

		AZ::TransformBus::Event(m_lineId, &AZ::TransformInterface::SetWorldTM, transform);

		m_timeToVanish = m_duration;
		SetVisible(true);
	}

	void LineRendererComponent::SetVisible(bool visible)
	{
		if (m_visible == visible)
		{
			return;
		}

		m_visible = visible;
		SetMaterialVars(m_visible ? 0.0f : 1.0f);
	}

	void LineRendererComponent::SetMaterialVars(float age)
	{
		//IMaterial* mat = nullptr;
		//LmbrCentral::MaterialRequestBus::EventResult(mat, m_lineId, &LmbrCentral::MaterialRequestBus::Events::GetMaterial);

		bool success = false;

		if (m_clonedMaterial)
		{
			// The V scale and age aren't default parameters; it's specific to the LineRenderer's
			// shader, so we have to use a different method to set it.
			success = SetShaderVar(m_clonedMaterial, "baseUVScaleV", m_scale);
			if (m_age)
			{
				success &= SetShaderVar(m_clonedMaterial, "age", age);
			}
		}

		if (!success)
		{
			CryLog("Failed to set the LineRendererComponent's shader variables.");
		}
	}

	bool LineRendererComponent::SetShaderVar(IMaterial* mat, const char* paramName, float var)
	{
		if (mat == nullptr)
			return false;

		bool set = false;
		SShaderItem shaderItem = mat->GetShaderItem();
		if (shaderItem.m_pShaderResources == nullptr)
			return false;

		DynArray<SShaderParam> params = shaderItem.m_pShaderResources->GetParameters();
		for (int i = 0; i < params.size(); ++i)
		{
			SShaderParam p = params[i];

			if (strcmp(paramName, p.m_Name) == 0)
			{
				UParamVal val;
				val.m_Float = var;
				
				p.SetParam(paramName, &params, val);

				SInputShaderResources res;
				shaderItem.m_pShaderResources->ConvertToInputResource(&res);
				res.m_ShaderParams = params;
				shaderItem.m_pShaderResources->SetShaderParams(&res, shaderItem.m_pShader);

				// We've just modified the shader params array, so we don't want to keep iterating
				// across it.
				set = true;
				break;
			}
		}

		return set;
	}
}

