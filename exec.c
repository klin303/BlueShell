#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include "string.h"
#include "assert.h"

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
            char **temp1 = *(char***)(args_copy->val);
            // fprintf(stderr, "ARGSCOPY %d: %s\n", i, *temp1);
            i += 1;
            args_copy = args_copy->next;
            // fprintf(stderr, "%s", *(char **)(args_copy));
        }
        // fprintf(stderr, "i is: %d\n", i);
        char **args = malloc(sizeof(char*) * (i + 2));
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
              sprintf(str, "%lf", **(double **)(args_copy->val));
              break;
            case BOOL:
              if ((**(int **)(args_copy->val) & 1) == 0) {
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

          args[j + 1] = str;
          args_copy = args_copy->next;
        }

        args[i + 1] = NULL;

        int rc = fork();
        int status = 0;
        // for (int x = 0; x < i + 2; x++) {
        //   fprintf(stderr, "ARGS %d: %s\n", x, args[x]);
        // }

        if (rc == 0) {
            int err = execvp(path, args);
            printf("%d", err);
        }
        int wpid = wait(&status);
        // printf("exit code: %d\n", WEXITSTATUS(status));

    return status;
}