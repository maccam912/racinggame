/* Instrumentation only: does not write profile values or unlink the lock. */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/file.h>
#include <unistd.h>
int main(int count, char **arguments) {
    if (count != 2) return 2;
    int file = open(arguments[1], O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (file < 0) return 3;
    int locked = flock(file, LOCK_EX | LOCK_NB);
    int code = errno;
    close(file);
    if (locked == 0) { puts("NATIVE_EXTERNAL_LOCK_FREE"); return 0; }
    if (code == EWOULDBLOCK || code == EAGAIN) { puts("NATIVE_EXTERNAL_LOCK_BUSY"); return 0; }
    return 4;
}
