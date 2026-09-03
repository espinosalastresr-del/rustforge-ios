// WAMRBridge.c - stub implementation
#include "WAMRBridge.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>

static bool g_initialized = false;
static char g_last_error[512] = {0};

static void set_error(const char *msg) {
    if (msg) {
        strncpy(g_last_error, msg, sizeof(g_last_error) - 1);
        g_last_error[sizeof(g_last_error) - 1] = '\0';
    } else {
        g_last_error[0] = '\0';
    }
}

bool wamr_init(void) {
    if (g_initialized) return true;
    g_initialized = true;
    set_error(NULL);
    return true;
}

void wamr_destroy(void) {
    g_initialized = false;
}

bool wamr_is_initialized(void) {
    return g_initialized;
}

wamr_module_t *wamr_load_module(const uint8_t *data, size_t size, const char *name) {
    if (!g_initialized) { set_error("Runtime not initialized"); return NULL; }
    if (!data || size == 0) { set_error("Invalid module data"); return NULL; }
    wamr_module_t *mod = calloc(1, sizeof(wamr_module_t));
    if (!mod) { set_error("Out of memory"); return NULL; }
    mod->name = name ? strdup(name) : strdup("unnamed");
    mod->module = (void *)0x1;
    mod->module_inst = (void *)0x2;
    mod->exec_env = (void *)0x3;
    set_error(NULL);
    return mod;
}

wamr_module_t *wamr_load_module_from_file(const char *path, const char *name) {
    if (!path) { set_error("Invalid path"); return NULL; }
    FILE *f = fopen(path, "rb");
    if (!f) { set_error("Failed to open module file"); return NULL; }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0) { fclose(f); set_error("Empty or invalid module file"); return NULL; }
    uint8_t *data = malloc((size_t)size);
    if (!data) { fclose(f); set_error("Out of memory"); return NULL; }
    size_t nread = fread(data, 1, (size_t)size, f);
    fclose(f);
    if (nread != (size_t)size) { free(data); set_error("Failed to read module file"); return NULL; }
    wamr_module_t *mod = wamr_load_module(data, (size_t)size, name);
    free(data);
    return mod;
}

void wamr_unload_module(wamr_module_t *module) {
    if (!module) return;
    free(module->name);
    free(module);
}

wamr_result_t *wamr_run(wamr_module_t *module, const wamr_wasi_config_t *config) {
    if (!module || !module->module_inst) { set_error("Invalid module"); return NULL; }
    clock_t start = clock();
    wamr_result_t *result = calloc(1, sizeof(wamr_result_t));
    if (!result) { set_error("Out of memory"); return NULL; }
    const char *sim = "[WAMR Bridge] Module executed (stub)\n";
    result->stdout_data = strdup(sim);
    result->stdout_len = strlen(sim);
    result->exit_code = 0;
    result->duration_seconds = (double)(clock() - start) / CLOCKS_PER_SEC;
    set_error(NULL);
    return result;
}

void wamr_free_result(wamr_result_t *result) {
    if (!result) return;
    free(result->stdout_data);
    free(result->stderr_data);
    free(result);
}

void wamr_cancel(void) {}

const char *wamr_last_error(void) {
    return g_last_error;
}
