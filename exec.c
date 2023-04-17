#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

/* execvp_helper
Purpose: Forks and calls execvp on the path and arguments, interfacing with the Blue Shell codegen.
Arguments: char* representing path, char* array representing arguments
*/

struct exec {
    void *val;
    struct exec* next;
};

int execvp_helper(char *path, struct exec *orig_args) {
        int i = 0;
        struct exec *args_copy = orig_args;

        while (args_copy != NULL) {
            i += 1;
            args_copy = args_copy->next;
            // fprintf(stderr, "%s", *(char **)(orig_args->val));
        }
        char **args = malloc(sizeof(char*) + (i + 1));
        args_copy = orig_args;
        args[0] = path;
        for (int j = 0; j < i; j++) {
            args[j + 1] = *(char **)(args_copy->val);
            args_copy = args_copy->next;
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