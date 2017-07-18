
#include "StdAfx.h"
#include "StarterGameCVars.h"

namespace StarterGameGem
{

	StarterGameCVars::StarterGameCVars()
	{
		REGISTER_CVAR2("ai_debugDrawSightRange", &m_viewAISightRange, 0, VF_NULL, "Enable drawing of A.I. sight and aggro ranges.");
		REGISTER_CVAR2("ai_debugDrawSuspicionRange", &m_viewAISuspicionRange, 0, VF_NULL, "Enable drawing of A.I. suspicion ranges.");

		REGISTER_CVAR2("ai_debugDrawWaypoints", &m_viewWaypoints, 0, VF_NULL, "Enable drawing of A.I. waypoints.");
	}

	void StarterGameCVars::DeregisterCVars()
	{
		UNREGISTER_CVAR("ai_debugDrawSightRange");
		UNREGISTER_CVAR("ai_debugDrawSuspicionRange");
		
		UNREGISTER_CVAR("ai_debugDrawWaypoints");
	}

}
