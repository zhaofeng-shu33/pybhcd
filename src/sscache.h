#ifndef	SSCACHE_H
#define	SSCACHE_H

#include <glib.h>
#include "dataset.h"

struct SSCache_t;
typedef struct SSCache_t SSCache;

SSCache * sscache_new(Dataset *);
gpointer sscache_get_label(SSCache *cache, gpointer label);
gpointer sscache_get_offblock(SSCache *cache, gpointer root, GList * children);
void sscache_unref(SSCache *cache);

gpointer suffstats_new_empty(void);
gpointer suffstats_new_offblock(Dataset * dataset, GList * srcs, GList * dsts);
gpointer suffstats_copy(gpointer src);
void suffstats_ref(gpointer ss);
void suffstats_unref(gpointer ss);
void suffstats_add(gpointer pdst, gpointer psrc);

#endif /*SSCACHE_H*/
