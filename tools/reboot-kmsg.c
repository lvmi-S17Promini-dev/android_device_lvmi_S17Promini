#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#ifdef __ANDROID__
#include <sys/system_properties.h>
#endif

#define MAX_MOUNTS 1024
#define LOG_PART_SIZE (4U * 1024U * 1024U)
#define LOG_PARTS 4U

static const char *diagnostic_paths[] = {
    "/proc/1/stack", "/proc/1/wchan", "/proc/1/syscall",
    "/sys/module/kernel/parameters/initcall_debug",
    "/sys/kernel/debug/s17_deferred_probe"
};

struct diagnostic_fds {
    int proc[sizeof(diagnostic_paths) / sizeof(diagnostic_paths[0])];
    int sysrq;
};

static volatile sig_atomic_t stopping;

static void stop_capture(int signal_number) {
    (void)signal_number;
    stopping = 1;
}

static int reboot_reason(const char *reason) {
    return !strncmp(reason, "reboot", 6) && (reason[6] == ',' || reason[6] == '\0') &&
           strcmp(reason, "reboot,userspace");
}

/* Do not retain a writable cache mount during a power-off fsck. */
static int wait_for_reboot(void) {
#ifdef __ANDROID__
    char reason[PROP_VALUE_MAX];
    while (!stopping) {
        __system_property_get("sys.powerctl", reason);
        if (reason[0]) return reboot_reason(reason) ? 1 : 0;
        poll(NULL, 0, 100);
    }
    return 0;
#else
    (void)reboot_reason;
    errno = ENOTSUP;
    return -1;
#endif
}

static int write_all(int fd, const void *data, size_t size) {
    const char *bytes = data;
    while (size) {
        ssize_t count = write(fd, bytes, size);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return -1;
        bytes += count;
        size -= (size_t)count;
    }
    return 0;
}

static int keep_mount(const char *path) {
    return !strcmp(path, "/") || !strcmp(path, "/cache") ||
           !strncmp(path, "/cache/", 7);
}

struct mount_path {
    char *path;
    size_t order;
};

struct mount_entry {
    char path[4096];
    char type[32];
    char options[512];
};

/* Bionic getmntent leaves octal escapes intact; parse/decode exactly once. */
static int read_mount(FILE *mounts, struct mount_entry *entry) {
    char line[8192];
    unsigned int dump, pass;
    if (!fgets(line, sizeof(line), mounts)) return ferror(mounts) ? -1 : 0;
    if (!strchr(line, '\n') && !feof(mounts)) { errno = E2BIG; return -1; }
    if (sscanf(line, "%*s %4095s %31s %511s %u %u", entry->path,
               entry->type, entry->options, &dump, &pass) != 5) {
        errno = EINVAL;
        return -1;
    }
    char *src = entry->path, *dst = entry->path;
    while (*src) {
        if (*src == '\\') {
            if (strlen(src) < 4 || src[1] < '0' || src[1] > '7' ||
                src[2] < '0' || src[2] > '7' || src[3] < '0' || src[3] > '7') {
                errno = EINVAL;
                return -1;
            }
            unsigned int value = ((src[1] - '0') << 6) | ((src[2] - '0') << 3) | (src[3] - '0');
            if (!value || value > 255) { errno = EINVAL; return -1; }
            *dst++ = (char)value;
            src += 4;
        } else *dst++ = *src++;
    }
    *dst = '\0';
    if (entry->path[0] != '/') { errno = EINVAL; return -1; }
    return 1;
}

static int deepest_first(const void *left, const void *right) {
    const struct mount_path *a = left, *b = right;
    size_t alen = strlen(a->path), blen = strlen(b->path);
    if (alen != blen) return alen < blen ? 1 : -1;
    return a->order < b->order ? 1 : a->order != b->order ? -1 : 0;
}

/* Only called after unshare and recursively disabling mount propagation. */
static int detach_noncache_mounts(FILE *mounts) {
    struct mount_path *paths = calloc(MAX_MOUNTS, sizeof(*paths));
    struct mount_entry entry;
    size_t count = 0;
    int result = -1, cache_rw = 0, next;
    if (!paths) return -1;
    while ((next = read_mount(mounts, &entry)) > 0) {
        if (!strcmp(entry.path, "/cache") && !strcmp(entry.type, "ext4") &&
            !strncmp(entry.options, "rw", 2) &&
            (entry.options[2] == ',' || entry.options[2] == '\0')) cache_rw = 1;
        if (keep_mount(entry.path)) continue;
        if (count == MAX_MOUNTS) { errno = E2BIG; goto finish; }
        paths[count].path = strdup(entry.path);
        if (!paths[count].path) goto finish;
        paths[count].order = count;
        count++;
    }
    if (next < 0) goto finish;
    if (!cache_rw) { errno = ENODEV; goto finish; }
    qsort(paths, count, sizeof(*paths), deepest_first);
    for (size_t i = 0; i < count; i++) {
        if (umount2(paths[i].path, MNT_DETACH)) {
            fprintf(stderr, "rebootlog: cannot detach private mount %s: %s\n",
                    paths[i].path, strerror(errno));
            goto finish;
        }
    }
    result = 0;
finish:
    for (size_t i = 0; i < count; i++) free(paths[i].path);
    free(paths);
    return result;
}

static int isolate_cache(void) {
    if (unshare(CLONE_NEWNS)) return -1;
    if (mount(NULL, "/", NULL, MS_REC | MS_PRIVATE, NULL)) return -1;
    FILE *mounts = fopen("/proc/self/mounts", "re");
    if (!mounts) return -1;
    int result = detach_noncache_mounts(mounts);
    if (!result) {
        struct mount_entry entry;
        int next;
        rewind(mounts);
        while ((next = read_mount(mounts, &entry)) > 0) {
            if (!keep_mount(entry.path)) { errno = EBUSY; result = -1; break; }
        }
        if (next < 0) result = -1;
    }
    fclose(mounts);
    return result;
}

static int read_identity(const char *path, char *buffer, size_t size) {
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t count = read(fd, buffer, size - 1);
    int saved_errno = errno;
    close(fd);
    errno = saved_errno;
    if (count <= 0) return -1;
    buffer[count] = '\0';
    return 0;
}

static void open_diagnostics(struct diagnostic_fds *fds) {
    for (size_t i = 0; i < sizeof(diagnostic_paths) / sizeof(diagnostic_paths[0]); i++)
        fds->proc[i] = open(diagnostic_paths[i], O_RDONLY | O_CLOEXEC);
    fds->sysrq = open("/proc/sysrq-trigger", O_WRONLY | O_CLOEXEC);
}

static void close_diagnostics(struct diagnostic_fds *fds) {
    for (size_t i = 0; i < sizeof(diagnostic_paths) / sizeof(diagnostic_paths[0]); i++)
        if (fds->proc[i] >= 0) close(fds->proc[i]);
    if (fds->sysrq >= 0) close(fds->sysrq);
}

static long long monotonic_ms(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now)) return -1;
    return (long long)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

/* The proc FDs remain valid after /proc is detached in our private namespace. */
static int snapshot_diagnostics(int out, const struct diagnostic_fds *fds,
                                unsigned int sample, long long elapsed) {
    char buffer[8192];
    if (dprintf(out, "\nsample=%u elapsed_ms=%lld\n", sample, elapsed) < 0) return -1;
    for (size_t i = 0; i < sizeof(diagnostic_paths) / sizeof(diagnostic_paths[0]); i++) {
        if (dprintf(out, "%s:\n", diagnostic_paths[i]) < 0) return -1;
        if (fds->proc[i] < 0) {
            if (dprintf(out, "unavailable at collector start\n") < 0) return -1;
            continue;
        }
        if (lseek(fds->proc[i], 0, SEEK_SET) < 0) {
            if (dprintf(out, "seek error=%d\n", errno) < 0) return -1;
            continue;
        }
        ssize_t size;
        do { size = read(fds->proc[i], buffer, sizeof(buffer)); } while (size < 0 && errno == EINTR);
        if (size < 0) {
            if (dprintf(out, "read error=%d\n", errno) < 0) return -1;
        } else if (write_all(out, buffer, (size_t)size) || write_all(out, "\n", 1)) return -1;
    }
    return fsync(out);
}

static int arm_for_boot(const char *boot_id) {
    FILE *mounts = fopen("/proc/self/mounts", "re");
    struct mount_entry entry;
    int next, valid = 0;
    if (!mounts) return -1;
    while ((next = read_mount(mounts, &entry)) > 0) {
        if (!strcmp(entry.path, "/cache") && !strcmp(entry.type, "ext4") &&
            !strncmp(entry.options, "rw", 2) &&
            (entry.options[2] == ',' || entry.options[2] == '\0')) valid = 1;
    }
    fclose(mounts);
    if (next < 0) return -1;
    if (!valid) { errno = ENODEV; return -1; }
    if (mkdir("/cache/s17-reboot", 0700) && errno != EEXIST) return -1;
    int dir = open("/cache/s17-reboot", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (dir < 0) return -1;
    int fd = openat(dir, "armed", O_WRONLY | O_CREAT | O_TRUNC | O_DSYNC |
                    O_CLOEXEC | O_NOFOLLOW, 0600);
    int result = fd < 0 ? -1 : write_all(fd, boot_id, strlen(boot_id));
    if (!result) result = fsync(dir);
    if (fd >= 0) close(fd);
    close(dir);
    return result;
}

static int open_part(int dir, unsigned int sequence, const char *identity, size_t *size) {
    char name[32], header[4096];
    snprintf(name, sizeof(name), "kmsg-%u.log", sequence % LOG_PARTS);
    int fd = openat(dir, name, O_WRONLY | O_CREAT | O_TRUNC | O_DSYNC |
                    O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd < 0) return -1;
    int count = snprintf(header, sizeof(header),
                         "S17 reboot collector v2; part=%u; private cache namespace\n%s\n",
                         sequence, identity);
    if (count < 0 || (size_t)count >= sizeof(header) ||
        write_all(fd, header, (size_t)count) || fsync(dir)) {
        close(fd);
        return -1;
    }
    *size = (size_t)count;
    return fd;
}

int main(int argc, char **argv) {
    int check = argc == 2 && !strcmp(argv[1], "--check");
    int arm = argc == 2 && !strcmp(argv[1], "--arm");
    if (argc != 1 && !check && !arm) return 1;
    struct sigaction action = {.sa_handler = stop_capture};
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGTERM, &action, NULL) || sigaction(SIGINT, &action, NULL)) return 1;
    if (chdir("/")) return 1;
    char boot_id[64], version[512], cmdline[2048], identity[3072];
    if (read_identity("/proc/sys/kernel/random/boot_id", boot_id, sizeof(boot_id))) return 1;
    boot_id[strcspn(boot_id, "\r\n")] = '\0';
    if (strlen(boot_id) != 36 || strspn(boot_id, "0123456789abcdef-") != 36) return 1;
    if (arm) {
        if (arm_for_boot(boot_id)) { perror("rebootlog: arm"); return 1; }
        printf("Armed for current boot: %s\n", boot_id);
        return 0;
    }
    if (!check) {
        char armed_boot[64];
        if (read_identity("/cache/s17-reboot/armed", armed_boot, sizeof(armed_boot)) ||
            strcmp(boot_id, armed_boot)) return 0;
        int requested = wait_for_reboot();
        if (requested < 0) { perror("rebootlog: powerctl"); return 1; }
        if (!requested) return 0;
    }
    if (read_identity("/proc/version", version, sizeof(version)) ||
        read_identity("/proc/cmdline", cmdline, sizeof(cmdline))) {
        perror("rebootlog: identity");
        return 1;
    }
    int length = snprintf(identity, sizeof(identity), "mode=%s; boot_id=%s\n%s%s",
                          check ? "check" : "reboot", boot_id, version, cmdline);
    if (length < 0 || (size_t)length >= sizeof(identity)) return 1;

    int kmsg = open("/dev/kmsg", O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    int marker = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    if (kmsg < 0 || marker < 0) { perror("rebootlog: kmsg"); return 1; }
    if (lseek(kmsg, 0, SEEK_END) < 0) { perror("rebootlog: seek kmsg"); return 1; }
    struct diagnostic_fds diagnostics;
    open_diagnostics(&diagnostics);
    if (isolate_cache()) { perror("rebootlog: private cache setup"); return 1; }

    if (mkdir("/cache/s17-reboot", 0700) && errno != EEXIST) return 1;
    int root = open("/cache/s17-reboot", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (root < 0) return 1;
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now)) return 1;
    char session[128];
    snprintf(session, sizeof(session), "%s-%lld-%ld-%ld", boot_id,
             (long long)now.tv_sec, now.tv_nsec, (long)getpid());
    if (mkdirat(root, session, 0700) || fsync(root)) return 1;
    int dir = openat(root, session, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    close(root);
    if (dir < 0) return 1;
    size_t part_size;
    unsigned int sequence = 0;
    int out = open_part(dir, sequence, identity, &part_size);
    if (out < 0) { perror("rebootlog: open part"); return 1; }

    int ready = openat(dir, "ready", O_WRONLY | O_CREAT | O_EXCL | O_DSYNC | O_CLOEXEC, 0600);
    if (ready < 0 || write_all(ready, identity, strlen(identity)) || fsync(dir)) return 1;
    close(ready);
    dprintf(marker, "<6>[S17/REBOOT] collector v2 ready /cache/s17-reboot/%s\n", session);
    close(marker);
    if (check) {
        int snapshot = openat(dir, "task-snapshots.log", O_WRONLY | O_CREAT | O_EXCL |
                              O_DSYNC | O_CLOEXEC | O_NOFOLLOW, 0600);
        if (snapshot < 0 || fsync(dir) || snapshot_diagnostics(snapshot, &diagnostics, 0, 0))
            return 1;
        close(snapshot);
        close_diagnostics(&diagnostics);
        printf("Private cache setup passed: /cache/s17-reboot/%s\n", session);
        close(out);
        close(dir);
        close(kmsg);
        return 0;
    }
    int snapshots = openat(dir, "task-snapshots.log", O_WRONLY | O_CREAT | O_EXCL |
                           O_DSYNC | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (snapshots < 0 || fsync(dir)) return 1;
    long long started = monotonic_ms();
    if (started < 0) return 1;
    const long long sample_times[] = {10000, 30000, 60000};
    unsigned int sample = 0;
    char buffer[16384];
    int result = 0;
    while (!stopping) {
        long long elapsed = monotonic_ms() - started;
        if (sample < sizeof(sample_times) / sizeof(sample_times[0]) &&
            elapsed >= sample_times[sample]) {
            if (snapshot_diagnostics(snapshots, &diagnostics, sample, elapsed)) {
                result = 1;
                break;
            }
            if (!sample) {
                if (diagnostics.sysrq < 0) dprintf(snapshots, "sysrq unavailable at collector start\n");
                else {
                    const char requests[] = {'w', 't'};
                    for (size_t i = 0; i < sizeof(requests); i++) {
                        int error = write_all(diagnostics.sysrq, &requests[i], 1);
                        dprintf(snapshots, "sysrq %c result=%d errno=%d\n",
                                requests[i], error, error ? errno : 0);
                    }
                }
                fsync(snapshots);
            }
            sample++;
        }
        struct pollfd fd = {.fd = kmsg, .events = POLLIN};
        int available = poll(&fd, 1, 250);
        if (available < 0 && errno == EINTR) continue;
        if (available < 0) { result = 1; break; }
        if (!available) continue;
        ssize_t count = read(kmsg, buffer, sizeof(buffer));
        if (count < 0 && (errno == EAGAIN || errno == EINTR)) continue;
        if (count < 0 && errno == EPIPE) {
            const char lost[] = "S17 collector: kmsg overrun; some records lost\n";
            if (write_all(out, lost, sizeof(lost) - 1)) { result = 1; break; }
            part_size += sizeof(lost) - 1;
            continue;
        }
        if (count <= 0) { result = 1; break; }
        if (part_size + (size_t)count > LOG_PART_SIZE) {
            close(out);
            out = open_part(dir, ++sequence, identity, &part_size);
            if (out < 0) { result = 1; break; }
        }
        if (write_all(out, buffer, (size_t)count)) { result = 1; break; }
        part_size += (size_t)count;
    }
    if (result) perror("rebootlog: capture stopped");
    if (out >= 0) { fsync(out); close(out); }
    fsync(snapshots);
    close(snapshots);
    close_diagnostics(&diagnostics);
    close(dir);
    close(kmsg);
    return result;
}
