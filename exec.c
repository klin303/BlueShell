#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include "string.h"
#include "assert.h"
#include <fcntl.h>

// amount of output allowed by an executable
const int BUF_SIZE = 16384;
char* TEMP_FILE = "temp";
const int PERMISSIONS = 0644;
int num_temps = 0;

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
char* pipe_helper(struct complex_exec *e, int is_left);
char* recurse_helper(struct complex_exec *e);
char* execvp_helper(char *path, struct list *orig_args);
char* execvp_execute(char *path, struct list *orig_args);
char** organize_args(char *path, struct list *orig_args);

enum Type { INT = 0, FLOAT = 1, BOOL = 2, CHAR = 3, STRING = 4, OTHER = 5 };
enum Opcode { CONCAT = 0, SEQ = 1, PIPE = 2 };

char* recurse_exec(struct complex_exec *e) {
    // fprintf(stderr, "in recurse exec\n");
    char *final_str = recurse_helper(e);
    fprintf(stdout, "%s", final_str); // DON'T REMOVE THIS, IT'S NOT A DEBUG STATEMENT
    return final_str;
}

char* pipe_helper(struct complex_exec *e, int is_left) {
    char *final_str;
    if (e->is_simple == 1) {
      struct simple_exec* simple = (struct simple_exec*)(e->e1);
      char *simple_path = *(char **)simple->path;

      struct list *orig_args = simple->args;
      if (is_left) {
        char **args = organize_args(simple_path, orig_args);

        int get_output_fds[2];
        pipe(get_output_fds);

        // fprintf(stderr, "past cat-ing\n");
        char *int_string = malloc(32);
        sprintf(int_string, "%d", num_temps);
        char * temp = malloc(8);
        strcpy(temp,TEMP_FILE);
        char * file = strcat(temp, int_string);
        int file_fd = open(file, O_RDWR | O_CREAT, PERMISSIONS);
        int exec_rc = fork();
        int status = 0;
        if (exec_rc == 0) {
          dup2(file_fd, 0);
          // close(0);
          // close(fds[1]);
          // dup2(fds[0], 0);
          // close(fds[0]);
          // get_output_fds[0] = fds[1];

          
          // close(1);
          close(get_output_fds[0]);
          dup2(get_output_fds[1], 1);
          close(get_output_fds[1]);
          // fprintf(stderr, "execvp-ing %s\n", args[1]);
          int err = execvp(simple_path, args);
          exit(1);
        }
        int wpid = wait(&status);
        // fprintf(stderr, "past execvp-ing\n");
        char *buf = malloc(BUF_SIZE);
        read(get_output_fds[0], buf, BUF_SIZE);

        return buf;
      }

      return execvp_execute(simple_path, orig_args);
    }
    else {
      struct complex_exec* complex1 = (struct complex_exec*)(e->e1);
      struct complex_exec* complex2 = (struct complex_exec*)(e->e2);
      char *result1;
      char *result2;
      switch (e->op) {
        case CONCAT:
          result1 = recurse_helper(complex1);
          result2 = recurse_helper(complex2);
          final_str = strcat(result1, result2);
          break;

        case SEQ:
          result1 = recurse_helper(complex1);
          result2 = recurse_helper(complex2);
          final_str = result2;
          break;
          
        case PIPE:
          num_temps++;
          // fprintf(stderr, "in pipe\n");
          result1 = recurse_helper(complex1);

          char *int_string = malloc(32);
          sprintf(int_string, "%d", num_temps);
          char * temp = malloc(8);
          strcpy(temp,TEMP_FILE);
          int file_fd = open(strcat(temp, int_string), O_RDWR | O_CREAT, PERMISSIONS);
          write(file_fd, result1, BUF_SIZE);

          if (complex2->is_simple == 1) {
            result2 = pipe_helper(complex2, 1);
          }
          else {
            result2 = pipe_helper(complex2, 0);
          }
          break;
      }
    }
    return final_str;
}

char* recurse_helper(struct complex_exec *e) {
    char *final_str;
    if (e->is_simple == 1) {
      // fprintf(stderr, "in simple\n");
      struct simple_exec* simple = (struct simple_exec*)(e->e1);
      char *simple_path = *(char **)simple->path;

      struct list *orig_args = simple->args;
      char *final_str = execvp_execute(simple_path, orig_args);
      // fprintf(stderr, "finished simple\n");
      return final_str;
    }
    else {
      struct complex_exec* complex1 = (struct complex_exec*)(e->e1);
      struct complex_exec* complex2 = (struct complex_exec*)(e->e2);
      char *result1;
      char *result2;
      switch (e->op) {
        case CONCAT:
        // fprintf(stderr, "in concat\n");
          result1 = recurse_helper(complex1);
          result2 = recurse_helper(complex2);
          final_str = strcat(result1, result2);
          break;

        case SEQ:
        // fprintf(stderr, "in seq\n");
          result1 = recurse_helper(complex1);
          result2 = recurse_helper(complex2);
          final_str = result2;
          break;
          
        case PIPE:
          num_temps++;
          // fprintf(stderr, "in pipe\n");
          result1 = recurse_helper(complex1);

          char *int_string = malloc(32);
          // sprintf(int_string, "%d", num_temps);
          char * temp = malloc(8);
          strcpy(temp,TEMP_FILE);
          // fprintf(stderr, "opening file %s\n", int_string);
          char * file = strcat(temp, int_string);
          // fprintf(stderr, "concating str %s\n", file);
          int file_fd = open(file, O_RDWR | O_CREAT, PERMISSIONS);
          write(file_fd, result1, BUF_SIZE);

          int fds[2];
          // fprintf(stderr, "piping\n");
          pipe(fds);
          if (complex2->is_simple == 1) {
            // fprintf(stderr, "Going to simple case\n");
            result2 = pipe_helper(complex2, 1);
          }
          else {
            result2 = pipe_helper(complex2, 0);
          }
          
          final_str = result2;
          /*
          1. run left side of executable
          2. write string into file 
          3. cat file and pipe into right side of executable
          4. return right side result
          */
          break;
      }
    }
    return final_str;
}


/* execvp_helper
Purpose: Forks and calls execvp on the path and arguments, interfacing with the Blue Shell codegen.
Arguments: char* representing path, char* array representing arguments
*/
char* execvp_helper(char *path, struct list *orig_args) {
    char *return_string = execvp_execute(path, orig_args);
    fprintf(stdout, "%s", return_string); // DON'T REMOVE THIS, IT'S NOT A DEBUG STATEMENT

    return return_string;
}

char **organize_args(char* path, struct list *orig_args) {
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

        return args;
}

char *execvp_execute(char *path, struct list *orig_args) {
        char **args = organize_args(path, orig_args);
        
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
        char *buf = malloc(BUF_SIZE);
        read(fds[0], buf, BUF_SIZE);

        return buf;
}