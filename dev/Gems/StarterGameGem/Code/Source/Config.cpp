
#include "StdAfx.h"
#include "Config.h"

#include <AzCore/RTTI/BehaviorContext.h>

namespace StarterGameGem
{

	enum BuildConfig
	{
		Unknown = 0,
		Debug = 1,
		Profile,
		Performance,
		Release,
	};

	BuildConfig Build()
	{
#ifdef _DEBUG
		return BuildConfig::Debug;
#elif _PROFILE
		return BuildConfig::Profile;
#elif PERFORMANCE_BUILD
		return BuildConfig::Performance;
#elif _RELEASE
		return BuildConfig::Release;
#else
		return BuildConfig::Unknown;
#endif
	}

	void Config::Reflect(AZ::ReflectContext* reflection)
	{
		if (AZ::BehaviorContext* behaviorContext = azrtti_cast<AZ::BehaviorContext*>(reflection))
		{
			behaviorContext->Class<Config>("Config")
				->Property("Build",         &Build, nullptr)
				->Property("Unknown",       BehaviorConstant(BuildConfig::Unknown), nullptr)
				->Property("Debug",         BehaviorConstant(BuildConfig::Debug), nullptr)
				->Property("Profile",       BehaviorConstant(BuildConfig::Profile), nullptr)
				->Property("Performance",   BehaviorConstant(BuildConfig::Performance), nullptr)
				->Property("Release",       BehaviorConstant(BuildConfig::Release), nullptr)
			;
		}
	}

}
