#include "platform_store.hpp"
#include <godot_cpp/variant/vector2i.hpp>
#include <set>
#include <utility>

#if defined(__APPLE__)
#include <CoreGraphics/CoreGraphics.h>
extern "C" CFArrayRef pacific_screen_modes(int screen);
#elif defined(_WIN32)
#define NOMINMAX
#include <windows.h>
#elif defined(__linux__) && !defined(__ANDROID__)
#include <dlfcn.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>
#endif

namespace godot {
Array PacificPlatform::screen_modes(int screen, int x, int y, int width, int height) const {
    if (screen < 0 || screen >= 16 || width <= 0 || height <= 0 || width > 32768 || height > 32768) return {};
    std::set<std::pair<int, int>> sizes;
    auto add = [&sizes](int w, int h) {
        if (w >= 640 && h >= 360 && w <= 16384 && h <= 16384) sizes.emplace(w, h);
    };
#if defined(__APPLE__)
    CFArrayRef modes = pacific_screen_modes(screen);
    if (modes) {
        for (CFIndex i = 0; i < CFArrayGetCount(modes); ++i) {
            auto mode = (CGDisplayModeRef)CFArrayGetValueAtIndex(modes, i);
            add((int)CGDisplayModeGetPixelWidth(mode), (int)CGDisplayModeGetPixelHeight(mode));
        }
        CFRelease(modes);
    }
#elif defined(_WIN32)
    RECT rect{x, y, x + width, y + height};
    HMONITOR monitor = MonitorFromRect(&rect, MONITOR_DEFAULTTONEAREST);
    MONITORINFOEXW info{};
    info.cbSize = sizeof(info);
    if (GetMonitorInfoW(monitor, reinterpret_cast<MONITORINFO *>(&info))) {
        DEVMODEW mode{};
        mode.dmSize = sizeof(mode);
        for (DWORD index = 0; index < 4096 && EnumDisplaySettingsW(info.szDevice, index, &mode); ++index) {
            if (mode.dmBitsPerPel >= 24) add((int)mode.dmPelsWidth, (int)mode.dmPelsHeight);
        }
    }
#elif defined(__linux__) && !defined(__ANDROID__)
    // Read-only and optional at runtime. Wayland callers deliberately use Native.
    void *x11 = dlopen("libX11.so.6", RTLD_LOCAL | RTLD_NOW);
    void *randr = dlopen("libXrandr.so.2", RTLD_LOCAL | RTLD_NOW);
    if (x11 && randr) {
        auto open = (decltype(&XOpenDisplay))dlsym(x11, "XOpenDisplay");
        auto close = (decltype(&XCloseDisplay))dlsym(x11, "XCloseDisplay");
        auto resources = (decltype(&XRRGetScreenResourcesCurrent))dlsym(randr, "XRRGetScreenResourcesCurrent");
        auto free_resources = (decltype(&XRRFreeScreenResources))dlsym(randr, "XRRFreeScreenResources");
        auto output_info = (decltype(&XRRGetOutputInfo))dlsym(randr, "XRRGetOutputInfo");
        auto free_output = (decltype(&XRRFreeOutputInfo))dlsym(randr, "XRRFreeOutputInfo");
        auto crtc_info = (decltype(&XRRGetCrtcInfo))dlsym(randr, "XRRGetCrtcInfo");
        auto free_crtc = (decltype(&XRRFreeCrtcInfo))dlsym(randr, "XRRFreeCrtcInfo");
        auto query_version = (decltype(&XRRQueryVersion))dlsym(randr, "XRRQueryVersion");
        if (open && close && resources && free_resources && output_info && free_output && crtc_info && free_crtc && query_version) {
            Display *display = open(nullptr);
            if (display) {
                int major = 1, minor = 3;
                if (query_version(display, &major, &minor) && (major > 1 || (major == 1 && minor >= 3))) {
                    XRRScreenResources *res = resources(display, DefaultRootWindow(display));
                    if (res) {
                        for (int i = 0; i < res->noutput; ++i) {
                            XRROutputInfo *out = output_info(display, res, res->outputs[i]);
                            if (!out) continue;
                            if (out->connection == RR_Connected && out->crtc) {
                                XRRCrtcInfo *crtc = crtc_info(display, res, out->crtc);
                                if (crtc) {
                                    if (crtc->x == x && crtc->y == y && (int)crtc->width == width && (int)crtc->height == height) {
                                        bool rotated = (crtc->rotation & (RR_Rotate_90 | RR_Rotate_270)) != 0;
                                        for (int j = 0; j < out->nmode; ++j) {
                                            for (int k = 0; k < res->nmode; ++k) if (out->modes[j] == res->modes[k].id) {
                                                const auto &m = res->modes[k];
                                                add(rotated ? m.height : m.width, rotated ? m.width : m.height);
                                                break;
                                            }
                                        }
                                    }
                                    free_crtc(crtc);
                                }
                            }
                            free_output(out);
                        }
                        free_resources(res);
                    }
                }
                close(display);
            }
        }
    }
    if (randr) dlclose(randr);
    if (x11) dlclose(x11);
#endif
    Array result;
    for (const auto &size : sizes) result.append(Vector2i(size.first, size.second));
    return result;
}
}
