#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {
class PacificPlatform : public RefCounted {
    GDCLASS(PacificPlatform, RefCounted)
protected:
    static void _bind_methods();
public:
    String backend_name() const;
    Array screen_modes(int screen, int x, int y, int width, int height) const;
    Dictionary secret_read(const String &scope) const;
    Dictionary secret_write(const String &scope, const PackedByteArray &value) const;
    Dictionary secret_erase(const String &scope) const;
    Dictionary protect(const String &scope, const PackedByteArray &value) const;
    Dictionary unprotect(const String &scope, const PackedByteArray &value) const;
};
}
