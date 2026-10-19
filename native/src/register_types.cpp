#include "platform_store.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;
void initialize_platform(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) GDREGISTER_CLASS(PacificPlatform);
}
void uninitialize_platform(ModuleInitializationLevel) {}
extern "C" {
GDExtensionBool GDE_EXPORT pacific_platform_library_init(GDExtensionInterfaceGetProcAddress address,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject binding(address, library, initialization);
    binding.register_initializer(initialize_platform);
    binding.register_terminator(uninitialize_platform);
    binding.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return binding.init();
}
}
