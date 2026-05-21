#include <emscripten.h>
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <wasi/api.h>

static int uya_unknown_host_wasi_err_i32(__wasi_errno_t err) {
    if (err != 0) {
        errno = err;
        return -1;
    }
    return 0;
}

static ssize_t uya_unknown_host_wasi_err_ssize(__wasi_errno_t err, __wasi_size_t count) {
    if (err != 0) {
        errno = err;
        return -1;
    }
    return (ssize_t)count;
}

ssize_t uya_unknown_host_write(int32_t fd, const uint8_t *buf, size_t count) {
    __wasi_ciovec_t iov = {
        .buf = buf,
        .buf_len = count,
    };
    __wasi_size_t written = 0;
    return uya_unknown_host_wasi_err_ssize(__wasi_fd_write(fd, &iov, 1u, &written), written);
}

ssize_t uya_unknown_host_read(int32_t fd, uint8_t *buf, size_t count) {
    __wasi_iovec_t iov = {
        .buf = buf,
        .buf_len = count,
    };
    __wasi_size_t read_count = 0;
    return uya_unknown_host_wasi_err_ssize(__wasi_fd_read(fd, &iov, 1u, &read_count), read_count);
}

ssize_t uya_unknown_host_writev(int32_t fd, const struct iovec *iov, int32_t iovcnt) {
    if (iovcnt < 0) {
        errno = EINVAL;
        return -1;
    }
    __wasi_size_t written = 0;
    return uya_unknown_host_wasi_err_ssize(__wasi_fd_write(fd, (const __wasi_ciovec_t *)iov, (size_t)iovcnt, &written), written);
}

int32_t uya_unknown_host_open(const uint8_t *pathname, int32_t flags, int32_t mode) {
    return open((const char *)pathname, flags, mode);
}

int32_t uya_unknown_host_close(int32_t fd) {
    return uya_unknown_host_wasi_err_i32(__wasi_fd_close(fd));
}

int32_t uya_unknown_host_access(const uint8_t *pathname, int32_t mode) {
    (void)mode;
    int32_t fd = uya_unknown_host_open(pathname, O_RDONLY, 0);
    if (fd < 0) {
        return -1;
    }
    return uya_unknown_host_close(fd);
}

int64_t uya_unknown_host_lseek(int32_t fd, int64_t offset, int32_t whence) {
    __wasi_whence_t wasi_whence = __WASI_WHENCE_SET;
    if (whence == 0) {
        wasi_whence = __WASI_WHENCE_SET;
    } else if (whence == 1) {
        wasi_whence = __WASI_WHENCE_CUR;
    } else if (whence == 2) {
        wasi_whence = __WASI_WHENCE_END;
    } else {
        errno = EINVAL;
        return -1;
    }
    __wasi_filesize_t new_offset = 0;
    if (__wasi_fd_seek(fd, (__wasi_filedelta_t)offset, wasi_whence, &new_offset) != 0) {
        errno = EINVAL;
        return -1;
    }
    return (int64_t)new_offset;
}

void *uya_unknown_host_mmap(void *addr, size_t length, int32_t prot, int32_t flags, int32_t fd, int64_t offset) {
    return mmap(addr, length, prot, flags, fd, (off_t)offset);
}

int32_t uya_unknown_host_munmap(void *addr, size_t length) {
    return munmap(addr, length);
}

int32_t uya_unknown_host_mprotect(void *addr, size_t length, int32_t prot) {
    return mprotect(addr, length, prot);
}

int32_t uya_unknown_host_fcntl(int32_t fd, int32_t cmd, int32_t arg) {
    (void)fd;
    (void)cmd;
    (void)arg;
    errno = ENOSYS;
    return -1;
}

int32_t uya_unknown_host_mkdir(const uint8_t *pathname, int32_t mode) {
    (void)pathname;
    (void)mode;
    errno = ENOSYS;
    return -1;
}

int32_t uya_unknown_host_rmdir(const uint8_t *pathname) {
    (void)pathname;
    errno = ENOSYS;
    return -1;
}

int32_t uya_unknown_host_chdir(const uint8_t *path) {
    if (path != NULL && strcmp((const char *)path, "/") == 0) {
        return 0;
    }
    errno = ENOSYS;
    return -1;
}

uint8_t *uya_unknown_host_getcwd(uint8_t *buf, size_t size) {
    if (buf == NULL || size < 2u) {
        errno = ERANGE;
        return NULL;
    }
    buf[0] = '/';
    buf[1] = '\0';
    return buf;
}

int32_t uya_unknown_host_dup(int32_t fd) {
    (void)fd;
    errno = ENOSYS;
    return -1;
}

int32_t uya_unknown_host_dup2(int32_t oldfd, int32_t newfd) {
    (void)oldfd;
    (void)newfd;
    errno = ENOSYS;
    return -1;
}

void uya_unknown_host_exit(int32_t code) {
    __wasi_proc_exit((__wasi_exitcode_t)code);
}

int32_t uya_gui_web_host_fstat_size(int32_t fd, int64_t *out_size) {
    __wasi_filesize_t cur = 0;
    __wasi_filesize_t end = 0;
    if (__wasi_fd_seek(fd, 0, __WASI_WHENCE_CUR, &cur) != 0) {
        return -1;
    }
    if (__wasi_fd_seek(fd, 0, __WASI_WHENCE_END, &end) != 0) {
        return -1;
    }
    if (__wasi_fd_seek(fd, (__wasi_filedelta_t)cur, __WASI_WHENCE_SET, &cur) != 0) {
        return -1;
    }
    if (out_size != NULL) {
        *out_size = (int64_t)end;
    }
    return 0;
}

int32_t uya_gui_web_host_gettimeofday(int64_t *tv_sec, int64_t *tv_usec) {
    double now_ms = emscripten_get_now();
    int64_t whole_ms = (int64_t)now_ms;
    if (tv_sec != NULL) {
        *tv_sec = whole_ms / 1000;
    }
    if (tv_usec != NULL) {
        *tv_usec = (whole_ms % 1000) * 1000;
    }
    return 0;
}

int32_t uya_gui_web_host_clock_gettime(int32_t clock_id, int64_t *tv_sec, int64_t *tv_nsec) {
    double now_ms = emscripten_get_now();
    int64_t whole_ms = (int64_t)now_ms;
    (void)clock_id;
    if (tv_sec != NULL) {
        *tv_sec = whole_ms / 1000;
    }
    if (tv_nsec != NULL) {
        *tv_nsec = (whole_ms % 1000) * 1000000;
    }
    return 0;
}

int32_t uya_gui_web_host_nanosleep(int64_t req_sec, int64_t req_nsec, int64_t *rem_sec, int64_t *rem_nsec) {
    (void)req_sec;
    (void)req_nsec;
    if (rem_sec != NULL) {
        *rem_sec = 0;
    }
    if (rem_nsec != NULL) {
        *rem_nsec = 0;
    }
    return 0;
}
