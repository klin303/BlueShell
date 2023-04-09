#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

/* execvp_helper
Purpose: Forks and calls execvp on the path and arguments, interfacing with the Blue Shell codegen.
Arguments: char* representing path, char* array representing arguments
*/
int execvp_helper(char *path, char *arguments[]) {
        // printf("%s\n", path);
        int i = 0;
        while ((arguments[i]) != NULL) {
            i += 1;
        }
        char **args = malloc(sizeof(char*) + (i + 1));
        args[0] = path;
        for (int j = 0; j < i; j++) {
            args[j + 1] = arguments[j];
        }
        int rc = fork();
        int status = 0;

        // in child process
        if (rc == 0) {
            int err = execvp(path, args);
            printf("%d", err);
        }
        int wpid = wait(&status);
        // printf("exit code: %d\n", WEXITSTATUS(status));

    return status;
}