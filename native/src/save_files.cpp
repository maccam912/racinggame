#include "save_files.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <cerrno>
#include <filesystem>
#include <map>
#include <mutex>
#include <string>
#if defined(_WIN32)
#define NOMINMAX
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

namespace godot {
namespace fs = std::filesystem;
struct PacificProfileLease {
    fs::path folder;
#if defined(_WIN32)
    HANDLE handle = INVALID_HANDLE_VALUE;
    ~PacificProfileLease() { if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle); }
#else
    int descriptor = -1;
    ~PacificProfileLease() { if (descriptor >= 0) close(descriptor); }
#endif
};
namespace {
std::mutex registry_mutex;
std::map<fs::path, std::weak_ptr<PacificProfileLease>> registry;
Dictionary result(bool ok, const char *state, int64_t error = 0) {
    Dictionary value;
    value["ok"] = ok;
    value["state"] = state;
    if (error) value["os_error"] = error;
    return value;
}
bool basename(const String &name) {
    if (name.is_empty() || name.length() > 240 || name == "." || name == "..") return false;
    for (int i = 0; i < name.length(); ++i) {
        char32_t c = name[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '_')) return false;
    }
    return !name.to_lower().begins_with(".pacific-");
}
fs::path child(const PacificProfileLease &lease, const String &name) {
    return lease.folder / fs::u8path(name.utf8().get_data());
}
#if defined(_WIN32)
std::wstring windows_path(const fs::path &path) {
    auto name = path.wstring();
    for (auto &c : name) if (c == L'/') c = L'\\';
    if (name.rfind(L"\\\\?\\",0) == 0) return name;
    return name.rfind(L"\\\\",0) == 0 ? L"\\\\?\\UNC\\"+name.substr(2) : L"\\\\?\\"+name;
}
#endif
bool confined(const PacificProfileLease &lease, const String &name) {
    if (name.is_empty() || name.length() > 2048) return false;
    for (int i = 0; i < name.get_slice_count("/"); ++i)
        if (!basename(name.get_slice("/", i))) return false;
    std::error_code error;
    auto parent = fs::canonical(child(lease, name).parent_path(), error);
    if (error) return false;
    auto relative = parent.lexically_relative(lease.folder);
    return parent == lease.folder || (!relative.empty() && *relative.begin() != "..");
}
#if !defined(_WIN32)
int synchronize(int descriptor, bool directory = false) {
    int status;
    do { status = fsync(descriptor); } while (status < 0 && errno == EINTR);
#if defined(__APPLE__)
    if (status == 0 && !directory) {
        do { status = fcntl(descriptor, F_FULLFSYNC); } while (status < 0 && errno == EINTR);
        // Some filesystems do not implement full device flush; report that
        // limitation rather than claiming the stronger barrier succeeded.
    }
#endif
    return status;
}
#endif
Dictionary sync_parents(const PacificProfileLease &lease, fs::path parent) {
#if defined(_WIN32)
    return result(true, "write_through_move");
#else
    const auto end = lease.folder.parent_path(); // Persist a newly created profile directory too.
    while (true) {
        int directory = open(parent.c_str(), O_RDONLY | O_CLOEXEC | O_DIRECTORY);
        if (directory < 0) return result(false, "directory_sync_failed", errno);
        bool ok = synchronize(directory, true) == 0;
        auto code = ok ? 0 : errno;
        close(directory);
        if (!ok) return result(false, "directory_sync_failed", code);
        if (parent == end || parent == parent.parent_path()) break;
        parent = parent.parent_path();
    }
    return result(true, "directory_synced");
#endif
}
}
PacificSaveFiles::PacificSaveFiles() = default;
PacificSaveFiles::~PacificSaveFiles() = default;
void PacificSaveFiles::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open_profile", "folder"), &PacificSaveFiles::open_profile);
    ClassDB::bind_method(D_METHOD("owned"), &PacificSaveFiles::owned);
    ClassDB::bind_method(D_METHOD("release"), &PacificSaveFiles::release);
    ClassDB::bind_method(D_METHOD("sync_file", "name"), &PacificSaveFiles::sync_file);
    ClassDB::bind_method(D_METHOD("replace_file", "source", "target"), &PacificSaveFiles::replace_file);
    ClassDB::bind_method(D_METHOD("remove_file", "name"), &PacificSaveFiles::remove_file);
    ClassDB::bind_method(D_METHOD("sync_directory"), &PacificSaveFiles::sync_directory);
}
bool PacificSaveFiles::owned() const { return bool(lease); }
void PacificSaveFiles::release() { lease.reset(); }
Dictionary PacificSaveFiles::open_profile(const String &folder) {
    if (lease) return result(false, "already_open");
    std::error_code error;
    auto path = fs::canonical(fs::u8path(folder.utf8().get_data()), error);
    if (error || !fs::is_directory(path, error)) return result(false, "unavailable", error.value());
    std::lock_guard<std::mutex> guard(registry_mutex);
    auto existing = registry.find(path);
    if (existing != registry.end()) lease = existing->second.lock();
    if (lease) return result(true, "shared_process_lease");
    auto candidate = std::make_shared<PacificProfileLease>();
    candidate->folder = path;
    auto filename = path / ".pacific-save.lock";
#if defined(_WIN32)
    candidate->handle = CreateFileW(windows_path(filename).c_str(), GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_ALWAYS,
        FILE_ATTRIBUTE_HIDDEN, nullptr);
    if (candidate->handle == INVALID_HANDLE_VALUE) return result(false, "unavailable", GetLastError());
    OVERLAPPED overlap{};
    if (!LockFileEx(candidate->handle, LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &overlap)) {
        auto code = GetLastError();
        return result(false, code == ERROR_LOCK_VIOLATION ? "busy" : "unavailable", code);
    }
#else
    candidate->descriptor = open(filename.c_str(), O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (candidate->descriptor < 0) return result(false, "unavailable", errno);
    if (flock(candidate->descriptor, LOCK_EX | LOCK_NB) < 0) {
        auto code = errno;
        return result(false, code == EWOULDBLOCK || code == EAGAIN ? "busy" : "unavailable", code);
    }
#endif
    lease = candidate;
    registry[path] = candidate;
    return result(true, "owned");
}
Dictionary PacificSaveFiles::sync_file(const String &name) const {
    if (!lease || !confined(*lease,name)) return result(false, "invalid");
    auto filename = child(*lease, name);
#if defined(_WIN32)
    HANDLE file = CreateFileW(windows_path(filename).c_str(), GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return result(false, "sync_failed", GetLastError());
    bool ok = FlushFileBuffers(file);
    auto code = ok ? 0 : GetLastError();
    CloseHandle(file);
#else
    int file = open(filename.c_str(), O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (file < 0) return result(false, "sync_failed", errno);
    bool ok = synchronize(file) == 0;
    auto code = ok ? 0 : errno;
    close(file);
#endif
    return result(ok, ok ? "synced" : "sync_failed", code);
}
Dictionary PacificSaveFiles::replace_file(const String &source, const String &target) const {
    if (!lease || !confined(*lease,source) || !confined(*lease,target) || source == target) return result(false, "invalid");
    auto from = child(*lease, source), to = child(*lease, target);
    if (from.parent_path() != to.parent_path()) return result(false, "invalid");
#if defined(_WIN32)
    if (!MoveFileExW(windows_path(from).c_str(), windows_path(to).c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
        return result(false, "replace_failed", GetLastError());
#else
    if (rename(from.c_str(), to.c_str()) < 0) return result(false, "replace_failed", errno);
#endif
    return sync_parents(*lease,to.parent_path());
}
Dictionary PacificSaveFiles::remove_file(const String &name) const {
    if (!lease || !confined(*lease,name)) return result(false, "invalid");
    auto filename = child(*lease, name);
#if defined(_WIN32)
    if (!DeleteFileW(windows_path(filename).c_str()) && GetLastError() != ERROR_FILE_NOT_FOUND)
        return result(false, "remove_failed", GetLastError());
#else
    if (unlink(filename.c_str()) < 0 && errno != ENOENT) return result(false, "remove_failed", errno);
#endif
    return sync_parents(*lease,filename.parent_path());
}
Dictionary PacificSaveFiles::sync_directory() const {
    if (!lease) return result(false, "invalid");
#if defined(_WIN32)
    // Windows exposes file flushing and a write-through move, but does not
    // document a portable directory-fsync guarantee. Keep that boundary explicit.
    return result(true, "write_through_move");
#else
    return sync_parents(*lease,lease->folder);
#endif
}
}
