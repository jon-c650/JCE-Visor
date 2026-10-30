#ifndef PTY_SHIM_H
#define PTY_SHIM_H

#include <sys/types.h>
#include <sys/ioctl.h>

int visor_spawn_pty(
    const char *executable,
    char *const argv[],
    char *const envp[],
    int *master_fd,
    pid_t *child_pid,
    struct winsize *size
);

#endif
