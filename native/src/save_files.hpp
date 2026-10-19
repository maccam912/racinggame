#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <memory>

namespace godot {
struct PacificProfileLease;
class PacificSaveFiles : public RefCounted {
    GDCLASS(PacificSaveFiles, RefCounted)
    std::shared_ptr<PacificProfileLease> lease;
protected:
    static void _bind_methods();
public:
    PacificSaveFiles();
    ~PacificSaveFiles();
    Dictionary open_profile(const String &folder);
    bool owned() const;
    void release();
    Dictionary sync_file(const String &name) const;
    Dictionary replace_file(const String &source, const String &target) const;
    Dictionary remove_file(const String &name) const;
    Dictionary sync_directory() const;
};
}
