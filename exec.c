#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>


int execvp_helper(char *path, char **arguments) {
        printf("%p\n", arguments);
        int rc = fork();
        int status = 0;
        // in child process
        if (rc == 0) {
            // parse commands within pipe

            int err = execvp(path, arguments);
            printf("%d", err);
        }
        int wpid = wait(&status);
        printf("exit code: %d\n", WEXITSTATUS(status));

    return rc;
}