#include "platform_store.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <cstring>

#if defined(__APPLE__)
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
extern "C" CFTypeRef pacific_no_ui_auth_context();
#endif
#if defined(_WIN32)
#define NOMINMAX
#include <windows.h>
#include <wincrypt.h>
#endif
#if defined(__linux__) && !defined(__ANDROID__)
#include <dlfcn.h>
#include <libsecret/secret.h>
#endif

namespace godot {
namespace {
constexpr int MAX_SECRET = 4096;
Dictionary response(bool ok, const char *state, const PackedByteArray &value = {}) {
    Dictionary result;
    result["ok"] = ok;
    result["state"] = state;
    if (ok) result["value"] = value;
    return result;
}
bool valid_scope(const String &scope) {
    if (scope.length() < 1 || scope.length() > 96) return false;
    for (int i = 0; i < scope.length(); ++i) {
        const char32_t c = scope[i];
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '_' || c == ':')) return false;
    }
    return true;
}
#if defined(__APPLE__)
struct CFHandle {
    CFTypeRef value;
    explicit CFHandle(CFTypeRef input) : value(input) {}
    ~CFHandle() { if (value) CFRelease(value); }
    CFHandle(const CFHandle &) = delete;
    CFHandle &operator=(const CFHandle &) = delete;
};
CFMutableDictionaryRef keychain_query(const String &scope) {
    auto query = CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    const auto text = scope.utf8();
    CFHandle account(CFStringCreateWithCString(nullptr, text.get_data(), kCFStringEncodingUTF8));
    CFDictionarySetValue(query, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(query, kSecAttrService, CFSTR("dev.pacificrush.game.guest"));
    CFDictionarySetValue(query, kSecAttrAccount, account.value);
    CFHandle context(pacific_no_ui_auth_context());
    CFDictionarySetValue(query, kSecUseAuthenticationContext, context.value);
    return query;
}
Dictionary keychain_status(OSStatus status, bool missing_ok = false) {
    if (status == errSecSuccess || (missing_ok && status == errSecItemNotFound)) return response(true, "ok");
    if (status == errSecItemNotFound) return response(false, "missing");
    if (status == errSecInteractionNotAllowed || status == errSecAuthFailed) return response(false, "locked");
    return response(false, "unavailable");
}
#endif
#if defined(__linux__) && !defined(__ANDROID__)
struct SecretAPI {
    using Lookup = gchar *(*)(const SecretSchema *, GCancellable *, GError **, ...);
    using Store = gboolean (*)(const SecretSchema *, const gchar *, const gchar *, const gchar *, GCancellable *, GError **, ...);
    using Clear = gboolean (*)(const SecretSchema *, GCancellable *, GError **, ...);
    using PasswordFree = void (*)(gchar *);
    using ErrorFree = void (*)(GError *);
    void *handle = nullptr;
    Lookup lookup = nullptr;
    Store store = nullptr;
    Clear clear = nullptr;
    PasswordFree password_free = nullptr;
    ErrorFree error_free = nullptr;
    SecretSchema schema{};
    SecretAPI() {
        schema.name = "dev.pacificrush.Guest";
        schema.flags = SECRET_SCHEMA_NONE;
        schema.attributes[0] = {"scope", SECRET_SCHEMA_ATTRIBUTE_STRING};
        // Optional at runtime: a headless/minimal Linux install may have no
        // Secret Service. Keep the game loadable and report that boundary.
        handle = dlopen("libsecret-1.so.0", RTLD_LOCAL | RTLD_NOW);
        if (!handle) return;
        lookup = (Lookup)dlsym(handle, "secret_password_lookup_sync");
        store = (Store)dlsym(handle, "secret_password_store_sync");
        clear = (Clear)dlsym(handle, "secret_password_clear_sync");
        password_free = (PasswordFree)dlsym(handle, "secret_password_free");
        error_free = (ErrorFree)dlsym(handle, "g_error_free");
    }
    bool ready() const { return lookup && store && clear && password_free && error_free; }
};
SecretAPI &secret_api() { static SecretAPI api; return api; }
#endif
#if defined(_WIN32)
Dictionary dpapi(const String &scope, const PackedByteArray &value, bool encrypt) {
    auto text = (String("PacificRushGuest:") + scope).utf8();
    DATA_BLOB input{(DWORD)value.size(), (BYTE *)value.ptr()};
    DATA_BLOB entropy{(DWORD)text.length(), (BYTE *)text.get_data()};
    DATA_BLOB output{};
    BOOL ok = encrypt
        ? CryptProtectData(&input, L"Pacific Rush guest", &entropy, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)
        : CryptUnprotectData(&input, nullptr, &entropy, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output);
    if (!ok) return response(false, "unavailable");
    PackedByteArray bytes;
    if (output.cbData > 0 && output.cbData <= (encrypt ? 16384 : MAX_SECRET)) {
        bytes.resize(output.cbData);
        std::memcpy(bytes.ptrw(), output.pbData, output.cbData);
    }
    LocalFree(output.pbData);
    return bytes.is_empty() ? response(false, "invalid") : response(true, "ok", bytes);
}
#endif
} // namespace

void PacificPlatform::_bind_methods() {
    ClassDB::bind_method(D_METHOD("resident_memory_bytes"), &PacificPlatform::resident_memory_bytes);
    ClassDB::bind_method(D_METHOD("screen_modes", "screen", "x", "y", "width", "height"), &PacificPlatform::screen_modes);
    ClassDB::bind_method(D_METHOD("backend_name"), &PacificPlatform::backend_name);
    ClassDB::bind_method(D_METHOD("secret_read", "scope"), &PacificPlatform::secret_read);
    ClassDB::bind_method(D_METHOD("secret_write", "scope", "value"), &PacificPlatform::secret_write);
    ClassDB::bind_method(D_METHOD("secret_erase", "scope"), &PacificPlatform::secret_erase);
    ClassDB::bind_method(D_METHOD("protect", "scope", "value"), &PacificPlatform::protect);
    ClassDB::bind_method(D_METHOD("unprotect", "scope", "value"), &PacificPlatform::unprotect);
}
String PacificPlatform::backend_name() const {
#if defined(__APPLE__)
    return "Keychain";
#elif defined(_WIN32)
    return "DPAPI";
#elif defined(__ANDROID__)
    return "AndroidKeyStore";
#elif defined(__linux__)
    return "SecretService";
#else
    return "Unavailable";
#endif
}
Dictionary PacificPlatform::secret_read(const String &scope) const {
    if (!valid_scope(scope)) return response(false, "invalid");
#if defined(__APPLE__)
    CFHandle query(keychain_query(scope));
    CFDictionarySetValue((CFMutableDictionaryRef)query.value, kSecReturnData, kCFBooleanTrue);
    CFDictionarySetValue((CFMutableDictionaryRef)query.value, kSecMatchLimit, kSecMatchLimitOne);
    CFTypeRef found = nullptr;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query.value, &found);
    CFHandle data(found);
    if (status != errSecSuccess) return keychain_status(status);
    if (!found || CFGetTypeID(found) != CFDataGetTypeID()) return response(false, "invalid");
    const auto length = CFDataGetLength((CFDataRef)found);
    if (length < 1 || length > MAX_SECRET) return response(false, "invalid");
    PackedByteArray bytes;
    bytes.resize(length);
    std::memcpy(bytes.ptrw(), CFDataGetBytePtr((CFDataRef)found), length);
    return response(true, "ok", bytes);
#elif defined(__linux__) && !defined(__ANDROID__)
    auto &api = secret_api();
    if (!api.ready()) return response(false, "unavailable");
    auto key = scope.utf8();
    GError *error = nullptr;
    gchar *password = api.lookup(&api.schema, nullptr, &error, "scope", key.get_data(), nullptr);
    if (error) {
        api.error_free(error);
        if (password) api.password_free(password);
        return response(false, "unavailable");
    }
    if (!password) return response(false, "missing");
    const size_t length = strnlen(password, MAX_SECRET * 2 + 1);
    bool valid = length > 0 && length <= MAX_SECRET * 2 && length % 2 == 0;
    for (size_t i = 0; valid && i < length; ++i) {
        const char c = password[i];
        valid = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
    }
    PackedByteArray bytes;
    if (valid) bytes = String::utf8(password, length).hex_decode();
    api.password_free(password);
    return valid ? response(true, "ok", bytes) : response(false, "invalid");
#else
    return response(false, "unavailable");
#endif
}
Dictionary PacificPlatform::secret_write(const String &scope, const PackedByteArray &value) const {
    if (!valid_scope(scope) || value.is_empty() || value.size() > MAX_SECRET) return response(false, "invalid");
#if defined(__APPLE__)
    CFHandle query(keychain_query(scope));
    CFHandle data(CFDataCreate(nullptr, value.ptr(), value.size()));
    auto attributes = CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFHandle attributes_owner(attributes);
    CFDictionarySetValue(attributes, kSecValueData, data.value);
    OSStatus status = SecItemUpdate((CFDictionaryRef)query.value, attributes);
    if (status == errSecItemNotFound) {
        CFDictionarySetValue((CFMutableDictionaryRef)query.value, kSecValueData, data.value);
        CFDictionarySetValue((CFMutableDictionaryRef)query.value, kSecAttrLabel, CFSTR("Pacific Rush guest"));
        status = SecItemAdd((CFDictionaryRef)query.value, nullptr);
    }
    return keychain_status(status);
#elif defined(__linux__) && !defined(__ANDROID__)
    auto &api = secret_api();
    if (!api.ready()) return response(false, "unavailable");
    auto key = scope.utf8();
    auto password = value.hex_encode().utf8();
    GError *error = nullptr;
    gboolean ok = api.store(&api.schema, SECRET_COLLECTION_DEFAULT, "Pacific Rush guest", password.get_data(), nullptr, &error, "scope", key.get_data(), nullptr);
    const bool failed = error != nullptr;
    if (error) api.error_free(error);
    return response(ok && !failed, ok && !failed ? "ok" : "unavailable");
#else
    return response(false, "unavailable");
#endif
}
Dictionary PacificPlatform::secret_erase(const String &scope) const {
    if (!valid_scope(scope)) return response(false, "invalid");
#if defined(__APPLE__)
    CFHandle query(keychain_query(scope));
    return keychain_status(SecItemDelete((CFDictionaryRef)query.value), true);
#elif defined(__linux__) && !defined(__ANDROID__)
    auto &api = secret_api();
    if (!api.ready()) return response(false, "unavailable");
    auto key = scope.utf8();
    GError *error = nullptr;
    api.clear(&api.schema, nullptr, &error, "scope", key.get_data(), nullptr);
    if (error) { api.error_free(error); return response(false, "unavailable"); }
    return response(true, "ok");
#else
    return response(false, "unavailable");
#endif
}
Dictionary PacificPlatform::protect(const String &scope, const PackedByteArray &value) const {
    if (!valid_scope(scope) || value.is_empty() || value.size() > MAX_SECRET) return response(false, "invalid");
#if defined(_WIN32)
    return dpapi(scope, value, true);
#else
    return response(false, "unavailable");
#endif
}
Dictionary PacificPlatform::unprotect(const String &scope, const PackedByteArray &value) const {
    if (!valid_scope(scope) || value.is_empty() || value.size() > 16384) return response(false, "invalid");
#if defined(_WIN32)
    return dpapi(scope, value, false);
#else
    return response(false, "unavailable");
#endif
}
} // namespace godot
