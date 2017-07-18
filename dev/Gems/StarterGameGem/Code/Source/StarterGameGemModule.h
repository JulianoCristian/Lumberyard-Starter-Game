
#include "StdAfx.h"
#include <platform_impl.h>

#include <IGem.h>

namespace StarterGameGem
{
    class StarterGameGemModule
        : public CryHooksModule
    {
    public:
        AZ_RTTI(StarterGameGemModule, "{D151EC6D-A70E-4A81-9B43-FE20AC2D1C3A}", CryHooksModule);

        StarterGameGemModule();

		void OnSystemEvent(ESystemEvent e, UINT_PTR wparam, UINT_PTR lparam) override;
		void PostSystemInit();
		void Shutdown();

        /**
         * Add required SystemComponents to the SystemEntity.
         */
        AZ::ComponentTypeList GetRequiredSystemComponents() const override;

    };
}

// DO NOT MODIFY THIS LINE UNLESS YOU RENAME THE GEM
// The first parameter should be GemName_GemIdLower
// The second should be the fully qualified name of the class above
AZ_DECLARE_MODULE_CLASS(StarterGameGem_5c539192ddda40aaa2e92eb71f8e3170, StarterGameGem::StarterGameGemModule)
