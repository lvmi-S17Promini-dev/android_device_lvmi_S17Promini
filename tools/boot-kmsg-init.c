#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/statfs.h>
#include <sys/sysmacros.h>
#include <time.h>
#include <unistd.h>

static long milliseconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

/* Diagnostic PID 1 wrapper. The original init remains PID 1 after exec. */
static void collect(int kmsg) {
    int major = 0, minor = 0, ready = 0;
    for (int n = 0; n < 300; n++) {
        struct statfs fs;
        FILE *dev = fopen("/sys/class/block/mmcblk0p34/dev", "r");
        if (dev) {
            ready = fscanf(dev, "%d:%d", &major, &minor) == 2;
            fclose(dev);
        }
        if (ready && statfs("/mnt", &fs) == 0 && fs.f_type == 0x01021994)
            break;
        ready = 0;
        usleep(10000);
    }
    if (!ready) _exit(2);
    mkdir("/mnt/s17-bootlog", 0700);
    mknod("/dev/s17-boot-cache", S_IFBLK | 0600, makedev(major, minor));
    if (mount("/dev/s17-boot-cache", "/mnt/s17-bootlog", "ext4", MS_NOATIME, NULL))
        _exit(3);
    int out = open("/mnt/s17-bootlog/s17-early-kmsg.log",
                   O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (out < 0) _exit(4);
    const char *tag = "S17 early kmsg collector; original init is PID 1\n";
    write(out, tag, strlen(tag));
    fsync(out);
    lseek(kmsg, 0, SEEK_SET);
    long last_sync = milliseconds();
    long end = last_sync + 30000;
    char buffer[16384];
    while (milliseconds() < end) {
        struct pollfd fd = {.fd = kmsg, .events = POLLIN};
        int result = poll(&fd, 1, 100);
        if (result < 0 && errno != EINTR) break;
        if (result == 0) continue;
        ssize_t count = read(kmsg, buffer, sizeof(buffer) - 1);
        if (count > 0) {
            buffer[count] = '\0';
            ssize_t done = 0;
            while (done < count) {
                ssize_t n = write(out, buffer + done, count - done);
                if (n <= 0) goto finish;
                done += n;
            }
            long now = milliseconds();
            if (now - last_sync >= 250 || strstr(buffer, "init:") || strstr(buffer, "FATAL")) {
                fsync(out);
                last_sync = now;
            }
        } else if (count < 0 && errno == EPIPE) {
            continue;
        } else if (count < 0 && errno != EAGAIN && errno != EINTR) {
            break;
        }
    }
finish:
    fsync(out);
    close(out);
    /* No persistent changes outside the cache log. */
    umount2("/mnt/s17-bootlog", MNT_DETACH);
    _exit(0);
}

int main(int argc, char **argv, char **envp) {
    if (getpid() != 1) return 1;
    mknod("/s17-kmsg", S_IFCHR | 0600, makedev(1, 11));
    int fd = open("/s17-kmsg", O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd >= 0) {
        pid_t pid = fork();
        if (pid == 0) collect(fd);
        close(fd);
    }
    (void)argc;
    argv[0] = "/init";
    execve("/init.stock", argv, envp);
    int error = errno;
    int console = open("/s17-kmsg", O_WRONLY);
    if (console >= 0) dprintf(console, "<3>S17 wrapper: exec original init failed: %d\n", error);
    for (;;) pause();
}
