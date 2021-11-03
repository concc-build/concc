#include "cache2.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <glib.h>
#include <pthread.h>

struct cache2 {
  struct fuse_operations *next_oper;
  GHashTable *noent_paths;
  pthread_mutex_t lock;
  int debug;
};

static struct cache2 cache2;

#define CACHE2_OPT(t, p, v) { t, offsetof(struct cache2, p), v }

static const struct fuse_opt cache2_opts[] = {
  /* for enabling fuse_fs::debug */
  FUSE_OPT_KEY("debug", FUSE_OPT_KEY_KEEP),
  FUSE_OPT_KEY("-d", FUSE_OPT_KEY_KEEP),

  CACHE2_OPT("debug", debug, 1),
  CACHE2_OPT("-d", debug, 1),

  FUSE_OPT_END
};

#define LOG(args...) (fprintf(stderr, "NOENT: " args))
#define WARN(args...) (LOG("WARN: " args))
#define ERROR(args...) (LOG("ERROR: " args))
#define DEBUG(args...) ((cache2.debug) ? LOG("DEBUG: " args) : (void)0)

static gboolean cache2_is_noent(const char *path) {
  char *orig_path = NULL;
  uintptr_t count = 0;
  pthread_mutex_lock(&cache2.lock);
  gboolean found = g_hash_table_lookup_extended(
      cache2.noent_paths, path, (gpointer *)&orig_path, (gpointer *)&count);
  if (found) {
    /*
     * Use g_hash_table_steal() in order to reuse the original key.
     * g_hash_table_replace() will free the original key.
     */
    (void)g_hash_table_steal(cache2.noent_paths, orig_path);
    if (count >= UINT32_MAX) {
      WARN("%s: Counter overflowed\n", path);
      count = 0;
    }
    g_hash_table_insert(cache2.noent_paths, orig_path, (gpointer)(count + 1));
  }
  pthread_mutex_unlock(&cache2.lock);
  return found;
}

static void cache2_add_noent(const char *path) {
  char *pathcopy = g_strdup(path);
  pthread_mutex_lock(&cache2.lock);
  /* The value is a counter, not a pointer. */
  g_hash_table_insert(cache2.noent_paths, pathcopy, (gpointer)1);
  pthread_mutex_unlock(&cache2.lock);
}

static void cache2_delete_noent(const char *path) {
  pthread_mutex_lock(&cache2.lock);
  g_hash_table_remove(cache2.noent_paths, path);
  pthread_mutex_unlock(&cache2.lock);
}

static void cache2_sizeof_noent(
    const char* path, gpointer count, size_t *size) {
  (void)count;
  /* <32-bit hex><SP><path><LF> */
  *size += strlen(path) + 10;
}

static size_t cache2_sizeof_noent_stats() {
  size_t size = 0;
  pthread_mutex_lock(&cache2.lock);
  g_hash_table_foreach(
      cache2.noent_paths, (GHFunc)cache2_sizeof_noent, (gpointer)&size);
  pthread_mutex_unlock(&cache2.lock);
  return size;
}

static void cache2_format_noent(
    const char* path, gpointer raw, GString *data) {
  uintptr_t count = (uintptr_t)raw;
  g_string_append_printf(data, "%08X %s\n", (uint32_t)count, path);
}

static GString *cache2_make_noent_stats() {
  size_t size = 0;
  GString *data = NULL;
  pthread_mutex_lock(&cache2.lock);
  g_hash_table_foreach(
      cache2.noent_paths, (GHFunc)cache2_sizeof_noent, (gpointer)&size);
  data = g_string_sized_new(size);
  g_hash_table_foreach(
      cache2.noent_paths, (GHFunc)cache2_format_noent, (gpointer)data);
  pthread_mutex_unlock(&cache2.lock);
  return data;
}

static int cache2_getattr(
    const char *path, struct stat *stbuf, struct fuse_file_info *fi) {
  if (strcmp(path, "/.noent-stats") == 0) {
    stbuf->st_mode = S_IFREG | 0444;
    stbuf->st_nlink = 1;
    stbuf->st_size = cache2_sizeof_noent_stats();
    return 0;
  }
  if (cache2_is_noent(path)) {
    DEBUG("%s: HIT\n", path);
    return -ENOENT;
  }
  int err = cache2.next_oper->getattr(path, stbuf, fi);
  if (err == -ENOENT) {
    DEBUG("%s: ADD\n", path);
    cache2_add_noent(path);
  }
  return err;
}

static int cache2_open(const char *path, struct fuse_file_info *fi) {
  if (strcmp(path, "/.noent-stats") == 0) {
    if ((fi->flags & O_ACCMODE) != O_RDONLY) {
      return -EACCES;
    }
    return 0;
  }
  return cache2.next_oper->open(path, fi);
}

static int cache2_create(
    const char *path, mode_t mode, struct fuse_file_info *fi) {
  if (strcmp(path, "/.noent-stats") == 0) {
    return -EACCES;
  }
  if (cache2_is_noent(path)) {
    DEBUG("%s: DELETE\n", path);
    cache2_delete_noent(path);
  }
  return cache2.next_oper->create(path, mode, fi);
}

static int cache2_read(const char *path, char *buf, size_t size,
                       off_t offset, struct fuse_file_info *fi) {
  if (strcmp(path, "/.noent-stats") == 0) {
    GString *data = cache2_make_noent_stats();
    if (offset < data->len) {
      if (offset + size > data->len) {
        size = data->len - offset;
      }
      memcpy(buf, data->str + offset, size);
    } else {
      size = 0;
    }
    g_string_free(data, TRUE);
    return (int)size;
  }
  return cache2.next_oper->read(path, buf, size, offset, fi);
}

static int cache2_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                          off_t offset, struct fuse_file_info *fi,
                          enum fuse_readdir_flags flags) {
  int res = cache2.next_oper->readdir(path, buf, filler, offset, fi, flags);
  if (res == 0 && strcmp(path, "/") == 0) {
    filler(buf, ".noent-stats", NULL, 0, 0);
  }
  return res;
}

static int cache2_flush(const char *path, struct fuse_file_info *fi) {
  if (strcmp(path, "/.noent-stats") == 0) {
    return 0;
  }
  return cache2.next_oper->flush(path, fi);
}

static int cache2_release(const char *path, struct fuse_file_info *fi) {
  if (strcmp(path, "/.noent-stats") == 0) {
    return 0;
  }
  return cache2.next_oper->release(path, fi);
}

static int cache2_rename(const char *from, const char *to, unsigned int flags) {
  if (strcmp(from, "/.noent-stats") == 0 || strcmp(to, "/.noent-stats") == 0) {
    return -EACCES;
  }
  if (cache2_is_noent(to)) {
    DEBUG("%s: DELETE\n", to);
    cache2_delete_noent(to);
  }
  return cache2.next_oper->rename(from, to, flags);
}

static int cache2_symlink(const char *from, const char *to) {
  if (strcmp(to, "/.noent-stats") == 0) {
    return -EACCES;
  }
  if (cache2_is_noent(to)) {
    DEBUG("%s: DELETE\n", to);
    cache2_delete_noent(to);
  }
  return cache2.next_oper->symlink(from, to);
}

static int cache2_mkdir(const char *path, mode_t mode) {
  if (cache2_is_noent(path)) {
    DEBUG("%s: DELETE\n", path);
    cache2_delete_noent(path);
  }
  return cache2.next_oper->mkdir(path, mode);
}

static void cache2_fill(struct fuse_operations *oper,
                        struct fuse_operations *cache_oper)
{
  cache_oper->access = oper->access;
  cache_oper->chmod = oper->chmod;
  cache_oper->chown = oper->chown;
  cache_oper->create = cache2_create;
  cache_oper->flush = cache2_flush;;
  cache_oper->fsync = oper->fsync;
  cache_oper->getattr = cache2_getattr;
  cache_oper->getxattr = oper->getxattr;
  cache_oper->init = oper->init;
  cache_oper->link = oper->link;
  cache_oper->listxattr = oper->listxattr;
  cache_oper->mkdir = cache2_mkdir;
  cache_oper->mknod = oper->mknod;
  cache_oper->open = cache2_open;
  cache_oper->opendir = oper->opendir;
  cache_oper->read = cache2_read;
  cache_oper->readdir = cache2_readdir;
  cache_oper->readlink = oper->readlink;
  cache_oper->release = cache2_release;
  cache_oper->releasedir = oper->releasedir;
  cache_oper->removexattr = oper->removexattr;
  cache_oper->rename = cache2_rename;
  cache_oper->rmdir = oper->rmdir;
  cache_oper->setxattr = oper->setxattr;
  cache_oper->statfs = oper->statfs;
  cache_oper->symlink = cache2_symlink;
  cache_oper->truncate = oper->truncate;
  cache_oper->unlink = oper->unlink;
  cache_oper->utimens = oper->utimens;
  cache_oper->write = oper->write;
}

/* public */

struct fuse_operations *cache2_wrap(struct fuse_operations *oper) {
  static struct fuse_operations cache_oper;
  cache2.next_oper = oper;
  cache2_fill(oper, &cache_oper);
  pthread_mutex_init(&cache2.lock, NULL);
  cache2.noent_paths = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
  if (cache2.noent_paths == NULL) {
    ERROR("Failed to create NOENT cache\n");
    return NULL;
  }
  return &cache_oper;
}

int cache2_parse_options(struct fuse_args *args) {
  cache2.debug = 0;
  return fuse_opt_parse(args, &cache2, cache2_opts, NULL);
}
