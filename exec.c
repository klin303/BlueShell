#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>


int execvp_helper(char *path, char *arguments[]) {
        printf("%s\n", path);
        int i = 0;
        while ((arguments[i]) != NULL) {
            i += 1;
        }
        // for (int i = 0; *arguments[i] != NULL; i++)
        char **args = malloc(sizeof(char*) + (i + 1));
        args[0] = path;
        for (int j = 0; j < i; j++) {
            args[j + 1] = arguments[j];
        }
        int rc = fork();
        int status = 0;
        // in child process
        if (rc == 0) {
            // parse commands within pipe

            int err = execvp(path, args);
            printf("%d", err);
        }
        int wpid = wait(&status);
        // printf("exit code: %d\n", WEXITSTATUS(status));

    return rc;
}