#include "GBABridge.h"

#include <stdatomic.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libretro.h"

#define FRAME_MAX_W 256
#define FRAME_MAX_H 224
#define AUDIO_CAP 8192 /* quadros de audio; precisa ser potencia de 2 */

static uint32_t g_frame[FRAME_MAX_W * FRAME_MAX_H];
static int g_w = 240;
static int g_h = 160;
static enum retro_pixel_format g_fmt = RETRO_PIXEL_FORMAT_RGB565;
static volatile uint32_t g_keys = 0;
static int g_turbo = 0;
static int g_loaded = 0;
static void *g_rom = NULL;
static double g_fps = 59.7275;

static int16_t g_audio[AUDIO_CAP * 2];
static _Atomic uint32_t g_head = 0;
static _Atomic uint32_t g_tail = 0;

static bool env_cb(unsigned cmd, void *data) {
    switch (cmd) {
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
        enum retro_pixel_format f = *(const enum retro_pixel_format *)data;
        if (f == RETRO_PIXEL_FORMAT_RGB565 || f == RETRO_PIXEL_FORMAT_XRGB8888 ||
            f == RETRO_PIXEL_FORMAT_0RGB1555) {
            g_fmt = f;
            return true;
        }
        return false;
    }
    case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
        return true;
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
        if (data) {
            *(bool *)data = false;
        }
        return true;
    case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
        return true;
    default:
        return false;
    }
}

static void video_cb(const void *data, unsigned w, unsigned h, size_t pitch) {
    if (!data || w == 0 || h == 0 || w > FRAME_MAX_W || h > FRAME_MAX_H) {
        return;
    }
    g_w = (int)w;
    g_h = (int)h;
    for (unsigned y = 0; y < h; y++) {
        uint32_t *dst = &g_frame[y * w];
        const uint8_t *row = (const uint8_t *)data + y * pitch;
        if (g_fmt == RETRO_PIXEL_FORMAT_RGB565) {
            const uint16_t *src = (const uint16_t *)row;
            for (unsigned x = 0; x < w; x++) {
                uint32_t p = src[x];
                uint32_t r = (p >> 11) & 31u;
                uint32_t g = (p >> 5) & 63u;
                uint32_t b = p & 31u;
                uint32_t r8 = (r << 3) | (r >> 2);
                uint32_t g8 = (g << 2) | (g >> 4);
                uint32_t b8 = (b << 3) | (b >> 2);
                dst[x] = 0xFF000000u | (r8 << 16) | (g8 << 8) | b8;
            }
        } else if (g_fmt == RETRO_PIXEL_FORMAT_0RGB1555) {
            const uint16_t *src = (const uint16_t *)row;
            for (unsigned x = 0; x < w; x++) {
                uint32_t p = src[x];
                uint32_t r = (p >> 10) & 31u;
                uint32_t g = (p >> 5) & 31u;
                uint32_t b = p & 31u;
                uint32_t r8 = (r << 3) | (r >> 2);
                uint32_t g8 = (g << 3) | (g >> 2);
                uint32_t b8 = (b << 3) | (b >> 2);
                dst[x] = 0xFF000000u | (r8 << 16) | (g8 << 8) | b8;
            }
        } else {
            const uint32_t *src = (const uint32_t *)row;
            for (unsigned x = 0; x < w; x++) {
                dst[x] = src[x] | 0xFF000000u;
            }
        }
    }
}

static size_t audio_push(const int16_t *data, size_t frames) {
    if (g_turbo) {
        return frames;
    }
    uint32_t head = atomic_load_explicit(&g_head, memory_order_relaxed);
    uint32_t tail = atomic_load_explicit(&g_tail, memory_order_acquire);
    uint32_t used = head - tail;
    uint32_t space = (used >= AUDIO_CAP) ? 0u : (AUDIO_CAP - used);
    size_t n = frames < space ? frames : space;
    for (size_t i = 0; i < n; i++) {
        uint32_t idx = (head + (uint32_t)i) & (AUDIO_CAP - 1);
        g_audio[idx * 2] = data[i * 2];
        g_audio[idx * 2 + 1] = data[i * 2 + 1];
    }
    atomic_store_explicit(&g_head, head + (uint32_t)n, memory_order_release);
    return frames;
}

static void audio_one_cb(int16_t left, int16_t right) {
    int16_t pair[2] = { left, right };
    audio_push(pair, 1);
}

static size_t audio_batch_cb(const int16_t *data, size_t frames) {
    return audio_push(data, frames);
}

static void poll_cb(void) {}

static int16_t input_cb(unsigned port, unsigned device, unsigned index, unsigned id) {
    (void)index;
    if (port != 0 || device != RETRO_DEVICE_JOYPAD) {
        return 0;
    }
    if (id >= 32) {
        return 0;
    }
    return (int16_t)((g_keys >> id) & 1u);
}

int gba_load(const char *path) {
    if (g_loaded) {
        gba_unload();
    }
    FILE *f = fopen(path, "rb");
    if (!f) {
        return 1;
    }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (n <= 0) {
        fclose(f);
        return 2;
    }
    g_rom = malloc((size_t)n);
    if (!g_rom) {
        fclose(f);
        return 3;
    }
    if (fread(g_rom, 1, (size_t)n, f) != (size_t)n) {
        fclose(f);
        free(g_rom);
        g_rom = NULL;
        return 4;
    }
    fclose(f);

    retro_set_environment(env_cb);
    retro_init();
    retro_set_video_refresh(video_cb);
    retro_set_audio_sample(audio_one_cb);
    retro_set_audio_sample_batch(audio_batch_cb);
    retro_set_input_poll(poll_cb);
    retro_set_input_state(input_cb);

    struct retro_game_info info;
    memset(&info, 0, sizeof(info));
    info.path = path;
    info.data = g_rom;
    info.size = (size_t)n;
    if (!retro_load_game(&info)) {
        retro_deinit();
        free(g_rom);
        g_rom = NULL;
        return 5;
    }

    struct retro_system_av_info av;
    memset(&av, 0, sizeof(av));
    retro_get_system_av_info(&av);
    if (av.timing.fps > 1.0) {
        g_fps = av.timing.fps;
    }

    atomic_store(&g_head, 0);
    atomic_store(&g_tail, 0);
    g_keys = 0;
    g_loaded = 1;
    return 0;
}

void gba_unload(void) {
    if (!g_loaded) {
        return;
    }
    retro_unload_game();
    retro_deinit();
    free(g_rom);
    g_rom = NULL;
    g_loaded = 0;
}

void gba_run_frame(void) {
    if (g_loaded) {
        retro_run();
    }
}

void gba_set_keys(uint32_t mask) {
    g_keys = mask;
}

const uint32_t *gba_frame(int *width, int *height) {
    if (width) {
        *width = g_w;
    }
    if (height) {
        *height = g_h;
    }
    return g_frame;
}

int gba_audio_pull(float *left, float *right, int frames) {
    uint32_t tail = atomic_load_explicit(&g_tail, memory_order_relaxed);
    uint32_t head = atomic_load_explicit(&g_head, memory_order_acquire);
    uint32_t avail = head - tail;
    int n = (int)(avail < (uint32_t)frames ? avail : (uint32_t)frames);
    for (int i = 0; i < n; i++) {
        uint32_t idx = (tail + (uint32_t)i) & (AUDIO_CAP - 1);
        left[i] = (float)g_audio[idx * 2] / 32768.0f;
        right[i] = (float)g_audio[idx * 2 + 1] / 32768.0f;
    }
    for (int i = n; i < frames; i++) {
        left[i] = 0.0f;
        right[i] = 0.0f;
    }
    atomic_store_explicit(&g_tail, tail + (uint32_t)n, memory_order_release);
    return n;
}

int gba_audio_buffered(void) {
    uint32_t head = atomic_load_explicit(&g_head, memory_order_acquire);
    uint32_t tail = atomic_load_explicit(&g_tail, memory_order_acquire);
    return (int)(head - tail);
}

void gba_set_turbo(int on) {
    g_turbo = on ? 1 : 0;
}

void *gba_save_data(void) {
    if (!g_loaded) {
        return NULL;
    }
    return retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
}

size_t gba_save_size(void) {
    if (!g_loaded) {
        return 0;
    }
    return retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
}

double gba_fps(void) {
    return g_fps;
}
