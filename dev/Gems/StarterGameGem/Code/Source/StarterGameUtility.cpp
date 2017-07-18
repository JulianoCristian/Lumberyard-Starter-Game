
#include "StdAfx.h"
#include "StarterGameUtility.h"
#include "CryAction.h"

#include <AzCore/RTTI/BehaviorContext.h>
#include <AzCore/Serialization/SerializeContext.h>
#include <AzCore/Component/ComponentApplicationBus.h>
#include <LyShine/Bus/UiCanvasBus.h>
#include <UiFaderComponent.h>
#include <UiScrollBarComponent.h>
#include <UiSliderComponent.h>

#include <LmbrCentral/Rendering/MeshComponentBus.h>

#include <IAISystem.h>
#include <INavigationSystem.h>

namespace StarterGameGem
{
	// This has been copied from PhysicsSystemComponent.cpp because they made it private but it's
	// needed here as well.
	unsigned int EntFromEntityTypes(AZ::u32 types)
	{
		// Shortcut when requesting all entities
		if (types == LmbrCentral::PhysicalEntityTypes::All)
		{
			return ent_all;
		}

		unsigned int result = 0;

		if (types & LmbrCentral::PhysicalEntityTypes::Static)
		{
			result |= ent_static | ent_terrain;
		}
		if (types & LmbrCentral::PhysicalEntityTypes::Dynamic)
		{
			result |= ent_rigid | ent_sleeping_rigid;
		}
		if (types & LmbrCentral::PhysicalEntityTypes::Living)
		{
			result |= ent_living;
		}
		if (types & LmbrCentral::PhysicalEntityTypes::Independent)
		{
			result |= ent_independent;
		}

		return result;
	}

	AZ::EntityId FindClosestFromTag(const LmbrCentral::Tag& tag)
	{
		AZ::EBusAggregateResults<AZ::EntityId> results;
		AZ::EntityId ret = AZ::EntityId();
		EBUS_EVENT_ID_RESULT(results, tag, LmbrCentral::TagGlobalRequestBus, RequestTaggedEntities);
		for (const AZ::EntityId& entity : results.values)
		{
			if (entity.IsValid())
			{
				ret = entity;
				break;
			}
		}

		return ret;
	}

	// Get a random float between a and b
	float randomF(float a, float b)
	{
		float randNum = (float)std::rand() / RAND_MAX;
		if (a > b)
			std::swap(a, b);
		float delta = b - a;
		return a + delta * randNum;
	}

	// Gets the surface type of the first thing that's hit.
	int GetSurfaceType(const AZ::Vector3& pos, const AZ::Vector3& direction)
	{
		AZ::u32 query = 15;			// hit everything
		AZ::u32 pierceability = 14;	// stop at the first thing
		float maxDistance = 1.1f;
		AZ::u32 maxHits = 1;		// only care about the first thing

		AZStd::vector<ray_hit> cryHits(maxHits);
		Vec3 start = AZVec3ToLYVec3(pos);
		Vec3 end = AZVec3ToLYVec3(direction.GetNormalized() * maxDistance);
		unsigned int flags = EntFromEntityTypes(query);

		int surfaceType = -1;

		// Perform raycast
		int hitCount = gEnv->pPhysicalWorld->RayWorldIntersection(start, end, flags, pierceability, cryHits.data(), aznumeric_caster(maxHits));

		if (hitCount != 0)
		{
			const ray_hit& cryHit = cryHits[0];

			if (cryHit.dist > 0.0f)
			{
				surfaceType = cryHit.surface_idx;
			}
		}

		return surfaceType;
	}

	int GetSurfaceIndexFromString(const AZStd::string surfaceName)
	{
		return gEnv->p3DEngine->GetMaterialManager()->GetSurfaceTypeIdByName(surfaceName.c_str());
	}

    AZStd::string GetSurfaceNameFromId(int surfaceId) 
    {
        ISurfaceType* surfaceType = gEnv->p3DEngine->GetMaterialManager()->GetSurfaceType(surfaceId);
        if (surfaceType == nullptr)
        {
            return "unknown";
        }

        return surfaceType->GetName();
    }

	AZ::EntityId GetParentEntity(const AZ::EntityId& entityId)
	{
		AZ::EntityId parentId;
		EBUS_EVENT_ID_RESULT(parentId, entityId, AZ::TransformBus, GetParentId);
		return parentId;
	}

	AZStd::string GetEntityName(AZ::EntityId entityId)
	{
		AZStd::string entityName;
		AZ::ComponentApplicationBus::BroadcastResult(entityName, &AZ::ComponentApplicationRequests::GetEntityName, entityId);
		return entityName;
	}

	bool EntityHasTag(const AZ::EntityId& entityId, const AZStd::string& tag)
	{
		bool hasTag = false;
		LmbrCentral::TagComponentRequestBus::EventResult(hasTag, entityId, &LmbrCentral::TagComponentRequestBus::Events::HasTag, AZ::Crc32(tag.c_str()));
		return hasTag;
	}

	void RestartLevel(const bool& fade)
	{
		//CCryAction* pCryAction = CCryAction::GetCryAction();
		CCryAction* pCryAction = static_cast<CCryAction*>(gEnv->pGame->GetIGameFramework());
		pCryAction->ScheduleEndLevelNow(pCryAction->GetLevelName(), fade);
	}

	void UIFaderControl(const AZ::EntityId& canvasEntityID, const int& faderID, const float &fadeValue, const float& fadeTime)
	{
		if (!canvasEntityID.IsValid())
		{
			// CryWarning(VALIDATOR_MODULE_SYSTEM, VALIDATOR_WARNING, "StarterGameUtility::UIFaderControl: %s Component: is not valid\n", canvasEntityID.ToString());
			return;
		}

		AZ::Entity* element = nullptr;
		EBUS_EVENT_ID_RESULT(element, canvasEntityID, UiCanvasBus, FindElementById, faderID);
		if (element)
		{
			const AZ::Entity::ComponentArrayType& components = element->GetComponents();
			UiFaderComponent* faderComp = NULL;
			for (int count = 0; count < components.size(); ++count)
			{
				faderComp = azdynamic_cast<UiFaderComponent*>(element->GetComponents()[count]);

				if (faderComp != NULL)
				{
					break;
				}
			}

			if (faderComp)
			{
				faderComp->Fade(fadeValue, fadeTime);
			}
			else
			{
				//CryWarning(VALIDATOR_MODULE_SYSTEM, VALIDATOR_WARNING, "StarterGameUtility::UIFaderControl: %s Component: couldn't find a fader component on UI element with ID: %d\n", canvasEntityID.ToString(), faderID);
			}
		}
		else
		{
			//CryWarning(VALIDATOR_MODULE_SYSTEM, VALIDATOR_WARNING, "StarterGameUtility::UIFaderControl: %s Component: couldn't find an image component with ID: %d\n", canvasEntityID.ToString(), faderID);
		}
	}

	void UIScrollControl(const AZ::EntityId& canvasEntityID, const int& scrollID, const float &value)
	{
		if (!canvasEntityID.IsValid())
		{
			// CryWarning(VALIDATOR_MODULE_SYSTEM, VALIDATOR_WARNING, "StarterGameUtility::UIScrollControl: %s Component: is not valid\n", canvasEntityID.ToString());
			return;
		}

		AZ::Entity* element = nullptr;
		EBUS_EVENT_ID_RESULT(element, canvasEntityID, UiCanvasBus, FindElementById, scrollID);
		if (element)
		{
			const AZ::Entity::ComponentArrayType& components = element->GetComponents();
			UiScrollBarComponent* scrollComp = NULL;
			for (int count = 0; count < components.size(); ++count)
			{
				scrollComp = azdynamic_cast<UiScrollBarComponent*>(element->GetComponents()[count]);

				if (scrollComp != NULL)
				{
					break;
				}
			}

			if (scrollComp)
			{
				scrollComp->SetValue(value);
			}
			else
			{
				//CryWarning(VALIDATOR_MODULE_SYSTEM, VALIDATOR_WARNING, "StarterGameUtility::UIScrollControl: %s Component: couldn't find a scroll component on UI element with ID: %d\n", canvasEntityID.ToString(), faderID);
			}
		}
		else
		{
			//CryWarning(VALIDATOR_MODULE_SYSTEM, VALIDATOR_WARNING, "StarterGameUtility::UIScrollControl: %s Component: couldn't find an image component with ID: %d\n", canvasEntityID.ToString(), faderID);
		}
	}

	void UISliderControl(const AZ::EntityId& canvasEntityID, const int& sliderID, const float &value)
	{
		if (!canvasEntityID.IsValid())
		{
			// CryWarning(VALIDATOR_MODULE_SYSTEM, VALIDATOR_WARNING, "StarterGameUtility::UISliderControl: %s Component: is not valid\n", canvasEntityID.ToString());
			return;
		}

		AZ::Entity* element = nullptr;
		EBUS_EVENT_ID_RESULT(element, canvasEntityID, UiCanvasBus, FindElementById, sliderID);
		if (element)
		{
			const AZ::Entity::ComponentArrayType& components = element->GetComponents();
			UiSliderComponent* sliderComp = NULL;
			for (int count = 0; count < components.size(); ++count)
			{
				sliderComp = azdynamic_cast<UiSliderComponent*>(element->GetComponents()[count]);

				if (sliderComp != NULL)
				{
					break;
				}
			}

			if (sliderComp)
			{
				sliderComp->SetValue(value);
			}
			else
			{
				//CryWarning(VALIDATOR_MODULE_SYSTEM, VALIDATOR_WARNING, "StarterGameUtility::UISliderControl: %s Component: couldn't find a slider component on UI element with ID: %d\n", canvasEntityID.ToString(), faderID);
			}
		}
		else
		{
			//CryWarning(VALIDATOR_MODULE_SYSTEM, VALIDATOR_WARNING, "StarterGameUtility::UISliderControl: %s Component: couldn't find an image component with ID: %d\n", canvasEntityID.ToString(), faderID);
		}
	}
	
	bool IsOnNavMesh(const AZ::Vector3& pos)
	{
		INavigationSystem* navSystem = gEnv->pAISystem->GetNavigationSystem();
		NavigationAgentTypeID agentType = navSystem->GetAgentTypeID("MediumSizedCharacters");
		bool isValid = false;
		if (agentType)
			isValid = navSystem->IsLocationValidInNavigationMesh(agentType, AZVec3ToLYVec3(pos));
		else
			CryLog("%s: Invalid agent type.", __FUNCTION__);

		return isValid;
	}

	IMaterial* GetMaterial(AZ::EntityId entityId)
	{
		IMaterial* mat = nullptr;
		LmbrCentral::MaterialRequestBus::EventResult(mat, entityId, &LmbrCentral::MaterialRequestBus::Events::GetMaterial);
		return mat;
	}

	bool SetMaterialParam(IMaterial* mat, const AZStd::string& paramName,  UParamVal var, EParamType type)
	{
		bool set = false;
		switch(type)
		{
			case eType_FLOAT:
				set = mat->SetGetMaterialParamFloat(paramName.c_str(), var.m_Float, false);
				break;
			case eType_VECTOR:
				Vec3 vecValue = Vec3(var.m_Vector[0], var.m_Vector[1], var.m_Vector[2]);
				set = mat->SetGetMaterialParamVec3(paramName.c_str(), vecValue, false);
				break;
		}

		return set;
	}

	bool SetShaderParam(AZ::EntityId entityId, IMaterial* mat, const AZStd::string& paramName, UParamVal var)
	{
		bool set = false;
		SShaderItem shaderItem = mat->GetShaderItem();
		if (shaderItem.m_pShaderResources != nullptr)
		{
			DynArray<SShaderParam> params = shaderItem.m_pShaderResources->GetParameters();
			if (params.size() == 0)
			{
				CryLog("%s found no shader parameters on %s (%llu)", __FUNCTION__, GetEntityName(entityId), (AZ::u64)entityId);
			}

			for (int i = 0; i < params.size(); ++i)
			{
				SShaderParam p = params[i];

				if (strcmp(paramName.c_str(), p.m_Name) == 0)
				{
					p.SetParam(paramName.c_str(), &params, var);

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
		}
		else
		{
			CryLog("%s found an invalid shader item on %s (%llu)", __FUNCTION__, GetEntityName(entityId), (AZ::u64)entityId);
		}

		return set;
	}
	
	// This is a static function so that it can be accessed from other C++ code instead of just
	// being available to Lua.
	bool StarterGameUtility::SetShaderFloat(AZ::EntityId entityId, const AZStd::string& paramName, float var)
	{
		bool set = false;
		IMaterial* mat = GetMaterial(entityId);

		if (mat == nullptr)
		{
			CryLog("%s couldn't find a material on %s (%llu)", __FUNCTION__, GetEntityName(entityId), (AZ::u64)entityId);
			return set;
		}

		UParamVal val;
		val.m_Float = var;

		// Check if it's a default parameter of the material.
		set = SetMaterialParam(mat, paramName, val, eType_FLOAT);
		if (set)
		{
			return set;
		}

		// If it's not a default parameter then we'll need to go deeper.
		set = SetShaderParam(entityId, mat, paramName, val);

		return set;
	}

	// This is a static function so that it can be accessed from other C++ code instead of just
	// being available to Lua.
	bool StarterGameUtility::SetShaderVec3(AZ::EntityId entityId, const AZStd::string& paramName, const AZ::Vector3& var)
	{
		bool set = false;
		IMaterial* mat = GetMaterial(entityId);

		if (mat == nullptr)
		{
			CryLog("%s couldn't find a material on %s (%llu)", __FUNCTION__, GetEntityName(entityId), (AZ::u64)entityId);
			return set;
		}

		UParamVal val;
		val.m_Vector[0] = var.GetX();
		val.m_Vector[1] = var.GetY();
		val.m_Vector[2] = var.GetZ();

		// Check if it's a default parameter of the material.
		set = SetMaterialParam(mat, paramName, val, eType_VECTOR);
		if (set)
		{
			return set;
		}

		// If it's not a default parameter then we'll need to go deeper.
		set = SetShaderParam(entityId, mat, paramName, val);

		return set;
	}

	void StarterGameUtility::ReplaceMaterialWithClone(AZ::EntityId entityId)
	{
		IMaterial* mat = nullptr;
		LmbrCentral::MaterialRequestBus::EventResult(mat, entityId, &LmbrCentral::MaterialRequestBus::Events::GetMaterial);
		if (mat)
		{
			mat = gEnv->p3DEngine->GetMaterialManager()->CloneMaterial(mat);
			LmbrCentral::MaterialRequestBus::Event(entityId, &LmbrCentral::MaterialRequestBus::Events::SetMaterial, mat);
		}
	}
	void StarterGameUtility::RestoreOriginalMaterial(AZ::EntityId entityId)
	{
		// setting material to null restores original material on the mesh
		LmbrCentral::MaterialRequestBus::Event(entityId, &LmbrCentral::MaterialRequestBus::Events::SetMaterial, nullptr);
	}

	void StarterGameUtility::Reflect(AZ::ReflectContext* reflection)
	{
		AZ::BehaviorContext* behaviorContext = azrtti_cast<AZ::BehaviorContext*>(reflection);
		if (behaviorContext)
		{
			behaviorContext->Class<StarterGameUtility>("StarterGameUtility")
				->Method("FindClosestFromTag", &FindClosestFromTag)
				->Method("randomF", &randomF)
				->Method("GetSurfaceType", &GetSurfaceType)
				->Method("GetSurfaceIndexFromString", &GetSurfaceIndexFromString)
				->Method("GetSurfaceNameFromId", &GetSurfaceNameFromId)
				->Method("GetParentEntity", &GetParentEntity)
				->Method("GetEntityName", &GetEntityName)
				->Method("EntityHasTag", &EntityHasTag)
				->Method("RestartLevel", &RestartLevel)
				->Method("UIFaderControl", &UIFaderControl)
				->Method("UIScrollControl", &UIScrollControl)
				->Method("UISliderControl", &UISliderControl)
				->Method("IsOnNavMesh", &IsOnNavMesh)
				->Method("SetShaderFloat", &SetShaderFloat)
				->Method("SetShaderVec3", &SetShaderVec3)
				->Method("ReplaceMaterialWithClone", &ReplaceMaterialWithClone)
				->Method("RestoreOriginalMaterial", &RestoreOriginalMaterial)
			;

			behaviorContext->Class<GotShotParams>("GotShotParams")
				->Attribute(AZ::Script::Attributes::Storage, AZ::Script::Attributes::StorageType::Value)
				->Property("damage", BehaviorValueProperty(&GotShotParams::m_damage))
				->Property("direction", BehaviorValueProperty(&GotShotParams::m_direction))
				->Property("assailant", BehaviorValueProperty(&GotShotParams::m_assailant))
				->Property("immediatelyRagdoll", BehaviorValueProperty(&GotShotParams::m_immediatelyRagdoll))
			;
		}

		//AZ::SerializeContext* serializeContext = azrtti_cast<AZ::SerializeContext*>(reflection);
		//if (serializeContext)
		//{
		//	serializeContext->Class<StarterGameUtility>()
		//		->Field("m_reason", &StarterGameUtility::m_reason)
		//	;
		//}
	}

}
