
#pragma once

#include <AzCore/base.h>
#include <AzCore/Memory/SystemAllocator.h>

namespace AZ
{
	class ReflectContext;
}

namespace StarterGameGem
{
	/*!
	* Reflects globals for getting the current build config in Lua.
	*/
	class Config
	{
	public:
		AZ_TYPE_INFO(Config, "{513BEE61-8C95-4D67-9113-56A177435DC2}");
		AZ_CLASS_ALLOCATOR(Config, AZ::SystemAllocator, 0);

		Config() = default;
		~Config() = default;

		static void Reflect(AZ::ReflectContext* reflection);

	};

} // namespace StarterGameGem
