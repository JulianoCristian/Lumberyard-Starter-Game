
#pragma once

#include <IGameRulesSystem.h>

namespace LYGame
{
    class StarterGameGameRules
        : public CGameObjectExtensionHelper < StarterGameGameRules, IGameRules >
    {
    public:
        StarterGameGameRules() {}
        virtual ~StarterGameGameRules();

        //////////////////////////////////////////////////////////////////////////
        //! IGameObjectExtension
        bool Init(IGameObject* pGameObject) override;
        void PostInit(IGameObject* pGameObject) override;
        void ProcessEvent(SEntityEvent& event) override { }
        //////////////////////////////////////////////////////////////////////////

        //////////////////////////////////////////////////////////////////////////
        // IGameRules
        bool OnClientConnect(ChannelId channelId, bool isReset) override;
        //////////////////////////////////////////////////////////////////////////
    };
} // namespace LYGame