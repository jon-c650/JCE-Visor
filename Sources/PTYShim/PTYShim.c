#include "PTYShim.h"

#include <errno.h>
#include <unistd.h>
#include <util.h>

int visor_spawn_pty(
    const char *executable,
    char *const argv[],
    char *const envp[],
    int *master_fd,
    pid_t *child_pid,
    struct winsize *size
) {
    int master = -1;
    pid_t pid = forkpty(&master, NULL, NULL, size);
    if (pid < 0) {
        return errno;
    }

    if (pid == 0) {
        execve(executable, argv, envp);
        _exit(127);
    }

    *master_fd = master;
    *child_pid = pid;
    return 0;
}
