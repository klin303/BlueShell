#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include "string.h"
#include "assert.h"
#include <fcntl.h>

// amount of output allowed by an executable
const int BUF_SIZE = 16384;

// all temp files to store executable outputs for pipes will start with "temp"
// for example, if a line in BlueShell has 1 pipe, then a file named "temp1.txt" will be used
char* TEMP_FILE = "temp";

// permissions for temp files
const int PERMISSIONS = 0644;

// count for number of temps (to avoid nested pipes colliding with the same temp file)
int num_temps = 0;

// struct to represent a list node (linked list under the hood)
struct list {
    void **val;
    struct list* next;

    // type to cast arguments to (see Type enum below)
    int typ;
};

// struct to represent a simple executable
struct simple_exec {
    char **path;
    struct list* args;
};

// struct to represent a complex executable
struct complex_exec {
    // 1 means simple, 0 means complex
    int is_simple;

    // void pointers may point to simple OR complex executables
    void *e1;
    void *e2;

    // operation (see Opcode enum below)
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

// this is called directly by the LLVM code
char* recurse_exec(struct complex_exec *e) {
    char *final_str = recurse_helper(e);
    fprintf(stdout, "%s", final_str); // DON'T REMOVE THIS, IT'S TO OUTPUT
    return final_str;
}

// this is called once we've seen a pipe
char* pipe_helper(struct complex_exec *e, int is_left) {
    char *final_str;

    // handle simple executables
    if (e->is_simple == 1) {
      struct simple_exec* simple = (struct simple_exec*)(e->e1);
      char *simple_path = *(char **)simple->path;

      struct list *orig_args = simple->args;
      // if it's the leftmost simple executable, read from the pipe
      if (is_left) {
        char **args = organize_args(simple_path, orig_args);

        // pipe to read the output of execvp back to this program
        int get_output_fds[2];
        pipe(get_output_fds);

        // open file containing cached result of left side of pipe
        char *int_string = calloc(32, 1);
        sprintf(int_string, "%d", num_temps);
        char * temp = calloc(8, 1);
        strcpy(temp, TEMP_FILE);
        char * file = strcat(temp, int_string);
        file = strcat(file, ".txt");

        int file_fd = open(file, O_RDWR | O_CREAT, PERMISSIONS);

        // fork
        int exec_rc = fork();
        int status = 0;
        if (exec_rc == 0) {
          // attach the file to the next executable as stdin
          close(0);
          dup2(file_fd, 0);

          // attach the pipe back to this program as stdout
          close(get_output_fds[0]);
          dup2(get_output_fds[1], 1);
          close(get_output_fds[1]);
          int err = execvp(simple_path, args);
          exit(1);
        }

        // wait until the forked process finishes
        int still_waiting = wait(&status);
        while (still_waiting > 0) {
            still_waiting = wait(&status);
        }

        // read the output of the process and save it
        char *buf = calloc(BUF_SIZE, 1);

        read(get_output_fds[0], buf, BUF_SIZE);
        close(file_fd);
        remove(file);
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
          if (complex1->is_simple == 1) {
            result1 = pipe_helper(complex1, 1);
          }
          else {
            result1 = pipe_helper(complex1, 0);
          }
          result2 = recurse_helper(complex2);

          // concatenates the results of the two executables
          final_str = strcat(result1, result2);
          break;

        case SEQ:
          if (complex1->is_simple == 1) {
            result1 = pipe_helper(complex1, 1);
          }
          else {
            result1 = pipe_helper(complex1, 0);
          }
          result2 = recurse_helper(complex2);

          // only returns the right executable
          final_str = result2;
          break;

        case PIPE:
          num_temps++;
          if (complex1->is_simple == 1) {
            result1 = pipe_helper(complex1, 1);
          }
          else {
            result1 = pipe_helper(complex1, 0);
          }

          // create a file to cache the result of the left executable
          char *int_string = calloc(32, 1);
          sprintf(int_string, "%d", num_temps);
          char* temp = calloc(8, 1);
          strcpy(temp, TEMP_FILE);
          char* file = strcat(temp, int_string);
          file = strcat(file, ".txt");
          int file_fd = open(file, O_RDWR | O_CREAT, PERMISSIONS);
          write(file_fd, result1, BUF_SIZE);

          // checks if there is a need to recurse further on the right executable
          if (complex2->is_simple == 1) {
            result2 = pipe_helper(complex2, 1);
          }
          else {
            result2 = pipe_helper(complex2, 0);
          }
          final_str = result2;

          // delete the cached file
          close(file_fd);
          remove(file);
          break;
      }
    }
    return final_str;
}

// regular recursive case (doesn't handle the stdin end of a pipe)
char* recurse_helper(struct complex_exec *e) {
    char *final_str;

    // if simple, just execute normally
    if (e->is_simple == 1) {
      struct simple_exec* simple = (struct simple_exec*)(e->e1);
      char *simple_path = *(char **)simple->path;

      struct list *orig_args = simple->args;
      char *final_str = execvp_execute(simple_path, orig_args);
      return final_str;
    }
    else {
      struct complex_exec* complex1 = (struct complex_exec*)(e->e1);
      struct complex_exec* complex2 = (struct complex_exec*)(e->e2);
      char *result1;
      char *result2;
      switch (e->op) {
        // concat executes both ends and returns the concatenated result
        case CONCAT:
          result1 = recurse_helper(complex1);
          result2 = recurse_helper(complex2);
          final_str = strcat(result1, result2);
          break;

        // sequence executes both ends and only returns the right result
        case SEQ:
          result1 = recurse_helper(complex1);
          result2 = recurse_helper(complex2);
          final_str = result2;
          break;

        // pipe caches the result of the left side in a file and calls pipe_helper
        // pipe_helper looks for the appropriate executable to read the cached file as stdin
        case PIPE:
          num_temps++;
          result1 = recurse_helper(complex1);

          char *int_string = calloc(32, 1);
          sprintf(int_string, "%d", num_temps);
          char *temp = calloc(8, 1);
          strcpy(temp, TEMP_FILE);
          char* file = strcat(temp, int_string);
          file = strcat(file, ".txt");
          int file_fd = open(file, O_RDWR | O_CREAT, PERMISSIONS);
          write(file_fd, result1, BUF_SIZE);

          int fds[2];
          pipe(fds);
          if (complex2->is_simple == 1) {
            result2 = pipe_helper(complex2, 1);
          }
          else {
            result2 = pipe_helper(complex2, 0);
          }

          final_str = result2;
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

// move args from linked list into array for execvp to use
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
          str = calloc(BUF_SIZE, 1);
          int typ = orig_args->typ;

          // cast differently depending on type
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

        // last argument to execvp must be NULL
        args[i + 1] = NULL;
        return args;
}

// fork and run the executable, saving the result in this program
char *execvp_execute(char *path, struct list *orig_args) {
        char **args = organize_args(path, orig_args);

        // fork and run the executable
        int fds[2];
        pipe(fds);

        int rc = fork();
        int status = 0;
        if (rc == 0) {
            // pipe stdout of the executable back to this program
            close(fds[0]);
            dup2(fds[1], 1);
            close(fds[1]);
            int err = execvp(path, args);
            exit(1);
        }
        int still_waiting = wait(&status);
        while (still_waiting > 0) {
            still_waiting = wait(&status);
        }

        char *buf = calloc(BUF_SIZE, 1);
        read(fds[0], buf, BUF_SIZE);
        return buf;
}