#ifndef C_IMPORT_MAGIC
#error "C_IMPORT_MAGIC must be provided by @c_import cflags"
#endif

int add_magic_i32(int x) {
    return x + C_IMPORT_MAGIC;
}
