#ifndef WAMRBridge_h
#define WAMRBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

bool wamr_init(void);
void wamr_destroy(void);
bool wamr_is_initialized(void);

typedef struct {
    void *module;
    void *module_inst;
    void *exec_env;
    char *name;
} wamr_module_t;

wamr_module_t *wamr_load_module(const uint8_t *data, size_t size, const char *name);
wamr_module_t *wamr_load_module_from_file(const char *path, const char *name);
void wamr_unload_module(wamr_module_t *module);

typedef struct {
    const char **args;
    size_t args_count;
    const char **env;
    size_t env_count;
    const char **preopens_guest;
    const char **preopens_host;
    size_t preopens_count;
    const char *stdin_data;
    size_t stdin_len;
} wamr_wasi_config_t;

typedef struct {
    int32_t exit_code;
    char *stdout_data;
    size_t stdout_len;
    char *stderr_data;
    size_t stderr_len;
    double duration_seconds;
} wamr_result_t;

wamr_result_t *wamr_run(wamr_module_t *module, const wamr_wasi_config_t *config);
void wamr_free_result(wamr_result_t *result);
void wamr_cancel(void);
const char *wamr_last_error(void);

#ifdef __cplusplus
}
#endif

#endif /* WAMRBridge_h */
