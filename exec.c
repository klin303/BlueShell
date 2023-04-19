#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include "string.h"

/* execvp_helper
Purpose: Forks and calls execvp on the path and arguments, interfacing with the Blue Shell codegen.
Arguments: char* representing path, char* array representing arguments
*/

struct exec {
    void **val;
    struct exec* next;
    int typ;
};

enum Type { INT = 0, FLOAT = 1, BOOL = 2, CHAR = 3, STRING = 4, OTHER = 5};



int execvp_helper(char *path, struct exec *orig_args) {
        int i = 0;
        struct exec *args_copy = orig_args;

        char* str;
        char** temp;

        while (args_copy != NULL) {
            i += 1;
            args_copy = args_copy->next;
            // fprintf(stderr, "%s", *(char **)(orig_args->val));
        }
        char **args = malloc(sizeof(char*) + (i + 1));
        args_copy = orig_args;
        args[0] = path;
        for (int j = 0; j < i; j++) {
          str = malloc(32);
          int typ = orig_args->typ;
          switch (typ) {
            case INT:
              sprintf(str, "%d", **(int **)(args_copy->val));
              break;
            case FLOAT:
              sprintf(str, "%f", **(float **)(args_copy->val));
              break;
            case BOOL:
              if (**(int **)(args_copy->val) == 0) {
                strcpy(str, "false");
              } else {
                strcpy(str, "true");
              }
              break;
            case CHAR:
              temp = *(char ***)(args_copy->val);
              strcpy(str, *temp);
              break;
            case STRING:
              temp = *(char ***)(args_copy->val);
              strcpy(str, *temp);
              break;
            case OTHER:
                fprintf(stderr, "Can only have lists of ints, bools, floats, chars, or string in executable");
                exit(1);

            }
              // str = sprintf(stf, "%f", **(float **)(args_copy->val));
          // char** temp = *(char ***)(args_copy->val);
          args[j + 1] = str;
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