#include "cache2.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <glib.h>
#include <pthread.h>

struct cache2 {
  struct fuse_operations *next_oper;
};

static struct cache2 cache2;

// options

struct option {
  int debug;
  char *nocache_globs;
  GPtrArray *uncacheable_patterns;
};

static struct option option;

#define CACHE2_OPT(t, p, v) { t, offsetof(struct option, p), v }

static const struct fuse_opt option_list[] = {
  // for enabling fuse_fs::debug
  FUSE_OPT_KEY("debug", FUSE_OPT_KEY_KEEP),
  FUSE_OPT_KEY("-d", FUSE_OPT_KEY_KEEP),

  CACHE2_OPT("debug", debug, 1),
  CACHE2_OPT("-d", debug, 1),
  CACHE2_OPT("nocache_globs=%s", nocache_globs, 0),

  FUSE_OPT_END
};

static int option_init(struct fuse_args *args) {
  option.debug = 0;
  option.nocache_globs = NULL;
  option.uncacheable_patterns = g_ptr_array_new();
  int res = fuse_opt_parse(args, &option, option_list, NULL);
  if (res != -1 && option.nocache_globs != NULL) {
    int i;
    char **globs = g_strsplit(option.nocache_globs, ",", 0);
    for (i = 0; globs[i] != NULL; ++i) {
      g_ptr_array_add(
          option.uncacheable_patterns, g_pattern_spec_new(globs[i]));
    }
  }
  return res;
}

// logging

#define LOG(args...) (fprintf(stderr, "NOENT: " args))
#define WARN(args...) (LOG("WARN: " args))
#define ERROR(args...) (LOG("ERROR: " args))
#define DEBUG(args...) ((option.debug) ? LOG("DEBUG: " args) : (void)0)

// negative path cache

static GHashTable *negpath_cache = NULL;

G_LOCK_DEFINE_STATIC(negpath_lock);
#define NEGPATH_LOCK() (G_LOCK(negpath_lock))
#define NEGPATH_UNLOCK() (G_UNLOCK(negpath_lock))

static void negpath_init() {
  negpath_cache = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
}

static gboolean negpath_lookup(const char *path) {
  char *orig_path = NULL;
  uintptr_t count = 0;
  NEGPATH_LOCK();
  gboolean found = g_hash_table_lookup_extended(
      negpath_cache, path, (gpointer *)&orig_path, (gpointer *)&count);
  if (found) {
    // Use g_hash_table_steal() in order to reuse the original key.
    // g_hash_table_replace() will free the original key.
    (void)g_hash_table_steal(negpath_cache, orig_path);
    if (count >= UINT32_MAX) {
      WARN("%s: Counter overflowed\n", path);
      count = 0;
    }
    g_hash_table_insert(negpath_cache, orig_path, (gpointer)(count + 1));
  }
  NEGPATH_UNLOCK();
  return found;
}

static void negpath_insert(const char *path) {
  char *pathcopy = g_strdup(path);
  NEGPATH_LOCK();
  // The value is a counter, not a pointer.
  g_hash_table_insert(negpath_cache, pathcopy, (gpointer)1);
  NEGPATH_UNLOCK();
}

static void negpath_remove(const char *path) {
  NEGPATH_LOCK();
  g_hash_table_remove(negpath_cache, path);
  NEGPATH_UNLOCK();
}

static void negpath_sizeof_line(
    const char* path, gpointer count, size_t *size) {
  (void)count;
  // <32-bit hex><SP><path><LF>
  *size += strlen(path) + 10;
}

static size_t negpath_sizeof_stats() {
  size_t size = 0;
  NEGPATH_LOCK();
  g_hash_table_foreach(
      negpath_cache, (GHFunc)negpath_sizeof_line, (gpointer)&size);
  NEGPATH_UNLOCK();
  return size;
}

static void negpath_format_line(
    const char* path, gpointer raw, GString *data) {
  uintptr_t count = (uintptr_t)raw;
  g_string_append_printf(data, "%08X %s\n", (uint32_t)count, path);
}

static GString *negpath_format_stats() {
  size_t size = 0;
  GString *data = NULL;
  NEGPATH_LOCK();
  g_hash_table_foreach(
      negpath_cache, (GHFunc)negpath_sizeof_line, (gpointer)&size);
  data = g_string_sized_new(size);
  g_hash_table_foreach(
      negpath_cache, (GHFunc)negpath_format_line, (gpointer)data);
  NEGPATH_UNLOCK();
  return data;
}

// helpers

static gboolean is_cacheable(const char *path) {
  for (int i = 0; i < option.uncacheable_patterns->len; ++i) {
    GPatternSpec *pat =
        (GPatternSpec *)g_ptr_array_index(option.uncacheable_patterns, i);
    if (g_pattern_match_string(pat, path)) {
      return FALSE;
    }
  }
  return TRUE;
}

// fuse operations

static int cache2_getattr(
    const char *path, struct stat *stbuf, struct fuse_file_info *fi) {
  if (strcmp(path, "/.negpath-stats") == 0) {
    stbuf->st_mode = S_IFREG | 0444;
    stbuf->st_nlink = 1;
    stbuf->st_size = negpath_sizeof_stats();
    return 0;
  }
  if (negpath_lookup(path)) {
    DEBUG("%s: HIT\n", path);
    return -ENOENT;
  }
  int err = cache2.next_oper->getattr(path, stbuf, fi);
  if (err == -ENOENT && is_cacheable(path)) {
    DEBUG("%s: ADD\n", path);
    negpath_insert(path);
  }
  return err;
}

static int cache2_opendir(const char *path, struct fuse_file_info *fi) {
  int res = cache2.next_oper->opendir(path, fi);
  if (res == 0 && is_cacheable(path)) {
    fi->cache_readdir = 1;
  }
  return res;
}

static int cache2_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                          off_t offset, struct fuse_file_info *fi,
                          enum fuse_readdir_flags flags) {
  int res = cache2.next_oper->readdir(path, buf, filler, offset, fi, flags);
  if (res == 0 && strcmp(path, "/") == 0) {
    filler(buf, ".negpath-stats", NULL, 0, 0);
  }
  return res;
}

static int cache2_mkdir(const char *path, mode_t mode) {
  if (negpath_lookup(path)) {
    DEBUG("%s: DELETE\n", path);
    negpath_remove(path);
  }
  return cache2.next_oper->mkdir(path, mode);
}

static int cache2_symlink(const char *from, const char *to) {
  if (strcmp(to, "/.negpath-stats") == 0) {
    return -EACCES;
  }
  if (negpath_lookup(to)) {
    DEBUG("%s: DELETE\n", to);
    negpath_remove(to);
  }
  return cache2.next_oper->symlink(from, to);
}

static int cache2_rename(const char *from, const char *to, unsigned int flags) {
  if (strcmp(from, "/.negpath-stats") == 0 || strcmp(to, "/.negpath-stats") == 0) {
    return -EACCES;
  }
  if (negpath_lookup(to)) {
    DEBUG("%s: DELETE\n", to);
    negpath_remove(to);
  }
  return cache2.next_oper->rename(from, to, flags);
}

static int cache2_open(const char *path, struct fuse_file_info *fi) {
  if (strcmp(path, "/.negpath-stats") == 0) {
    if ((fi->flags & O_ACCMODE) != O_RDONLY) {
      return -EACCES;
    }
    return 0;
  }
  return cache2.next_oper->open(path, fi);
}

static int cache2_flush(const char *path, struct fuse_file_info *fi) {
  if (strcmp(path, "/.negpath-stats") == 0) {
    return 0;
  }
  return cache2.next_oper->flush(path, fi);
}

static int cache2_release(const char *path, struct fuse_file_info *fi) {
  if (strcmp(path, "/.negpath-stats") == 0) {
    return 0;
  }
  return cache2.next_oper->release(path, fi);
}

static int cache2_read(const char *path, char *buf, size_t size,
                       off_t offset, struct fuse_file_info *fi) {
  if (strcmp(path, "/.negpath-stats") == 0) {
    GString *data = negpath_format_stats();
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

static int cache2_create(
    const char *path, mode_t mode, struct fuse_file_info *fi) {
  if (strcmp(path, "/.negpath-stats") == 0) {
    return -EACCES;
  }
  if (negpath_lookup(path)) {
    DEBUG("%s: DELETE\n", path);
    negpath_remove(path);
  }
  return cache2.next_oper->create(path, mode, fi);
}

static void cache2_fill(struct fuse_operations *oper,
                        struct fuse_operations *cache_oper)
{
  memcpy(cache_oper, oper, sizeof(*oper));
  cache_oper->getattr = cache2_getattr;
  cache_oper->opendir = cache2_opendir;
  cache_oper->readdir = cache2_readdir;
  cache_oper->mkdir = cache2_mkdir;
  cache_oper->symlink = cache2_symlink;
  cache_oper->rename = cache2_rename;
  cache_oper->open = cache2_open;
  cache_oper->flush = cache2_flush;;
  cache_oper->release = cache2_release;
  cache_oper->read = cache2_read;
  cache_oper->create = cache2_create;
}

// public

int cache2_parse_options(struct fuse_args *args) {
  return option_init(args);
}

struct fuse_operations *cache2_wrap(struct fuse_operations *oper) {
  static struct fuse_operations cache_oper;
  cache2.next_oper = oper;
  cache2_fill(oper, &cache_oper);
  negpath_init();
  return &cache_oper;
}
