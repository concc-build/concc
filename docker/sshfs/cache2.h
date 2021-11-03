#include <fuse.h>
#include <fuse_opt.h>

struct fuse_operations *cache2_wrap(struct fuse_operations *oper);
int cache2_parse_options(struct fuse_args *args);
