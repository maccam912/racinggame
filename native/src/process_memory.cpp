#include "platform_store.hpp"
#include <cstdint>
#include <cstdio>
#include <limits>
#include <initializer_list>
#if defined(__APPLE__)
#include <mach/mach.h>
#elif defined(_WIN32)
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#endif

namespace godot {
int64_t PacificPlatform::resident_memory_bytes() const {
#if defined(__APPLE__)
    mach_task_basic_info_data_t info{};
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
            reinterpret_cast<task_info_t>(&info), &count) == KERN_SUCCESS)
        return static_cast<int64_t>(info.resident_size);
#elif defined(_WIN32)
    PROCESS_MEMORY_COUNTERS info{};
    info.cb = sizeof(info);
    if (GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info)))
        return static_cast<int64_t>(info.WorkingSetSize);
#elif defined(__linux__)
    // statm/status RSS may be inaccurate due to kernel accounting optimizations.
    // Read accurate rollup (or sum mappings on older kernels), outside physics.
    for (const char *path : {"/proc/self/smaps_rollup", "/proc/self/smaps"}) {
        FILE *file = std::fopen(path, "r");
        if (!file) continue;
        char line[512];
        unsigned long long total_kb = 0;
        bool valid = true;
        while (std::fgets(line, sizeof(line), file)) {
            unsigned long long resident_kb = 0;
            if (std::sscanf(line, "Rss: %llu kB", &resident_kb) == 1) {
                const auto maximum = static_cast<unsigned long long>(std::numeric_limits<int64_t>::max() / 1024);
                if (resident_kb > maximum - total_kb) { valid = false; break; }
                total_kb += resident_kb;
            }
        }
        valid = valid && !std::ferror(file);
        std::fclose(file);
        if (valid && total_kb > 0) return static_cast<int64_t>(total_kb * 1024);
    }
#endif
    return 0; // Explicitly unavailable, never substituted with heap/peak data.
}
}
