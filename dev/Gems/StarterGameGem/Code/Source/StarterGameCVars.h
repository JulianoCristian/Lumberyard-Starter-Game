
#pragma once


namespace StarterGameGem
{

	class StarterGameCVars
	{
	public:
		StarterGameCVars();

		static const StarterGameCVars& GetInstance()
		{
			static StarterGameCVars instance;
			return instance;
		}

		int m_viewAISightRange;
		int m_viewAISuspicionRange;

		float m_viewWaypoints;

	private:
		// Only the gem component should unregister the CVars (to ensure it's only done once).
		friend class StarterGameGemModule;
		static void DeregisterCVars();

	};

} // namespace StarterGameGem
