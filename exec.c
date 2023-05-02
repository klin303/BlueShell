#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include "string.h"
#include "assert.h"

struct list {
    void **val;
    struct list* next;
    int typ;
};

struct simple_exec {
    char **path; 
    struct list* args;
};

struct complex_exec {
    int is_simple; // 1 means simple, 0 means complex
    void *e1;
    void *e2;
    int op;
};

char* recurse_exec(struct complex_exec *e);
char* execvp_helper(char *path, struct list *orig_args);

enum Type { INT = 0, FLOAT = 1, BOOL = 2, CHAR = 3, STRING = 4, OTHER = 5};
enum Opcode { CONCAT = 0, SEQ = 1, PIPE = 2};


char* recurse_exec(struct complex_exec *e) {
    if (e->is_simple == 1) {
      struct simple_exec* simple = (struct simple_exec*)(e->e1);
      char *simple_path = *(char **)simple->path;

      struct list *orig_args = simple->args;
      return execvp_helper(simple_path, orig_args);
    }
    else {
      struct complex_exec* complex1 = (struct complex_exec*)(e->e1);
      struct complex_exec* complex2 = (struct complex_exec*)(e->e2);
      char *result1 = recurse_exec(complex1);
      char *result2 = recurse_exec(complex2);
      switch (e->op) {
        case CONCAT:
          return strcat(result1, result2);

        case SEQ:
          return result2;
          
        case PIPE:
          fprintf(stderr, "in pipe\n");
          break;
      }
    }
    return NULL;
}


/* execvp_helper
Purpose: Forks and calls execvp on the path and arguments, interfacing with the Blue Shell codegen.
Arguments: char* representing path, char* array representing arguments
*/
char* execvp_helper(char *path, struct list *orig_args) {
        int i = 0;
        struct list *args_copy = orig_args;

        char* str;
        char** temp;

        // count the number of args
        while (args_copy != NULL) {
            char **temp1 = *(char***)(args_copy->val);
            i += 1;
            args_copy = args_copy->next;
        }

        // move args from linked list into array for execvp to use
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

        // fork and run the executable
        int fds[2];
        pipe(fds);

        int rc = fork();
        int status = 0;
        if (rc == 0) {
            close(fds[0]);
            dup2(fds[1], 1);
            close(fds[1]);
            int err = execvp(path, args);
            exit(1);
        }
        int wpid = wait(&status);
        // printf("exit code: %d\n", WEXITSTATUS(status));

        // close(fds[1]);
        // off_t size = lseek(fds[0], 0, SEEK_END);
        // fprintf(stderr, "file size: %lld\n", size);
        char *buf = malloc(1024);
        read(fds[0], buf, 1024);

        fprintf(stdout, "%s", buf); // DON'T REMOVE THIS, IT'S NOT A DEBUG STATEMENT

        return buf;
}

