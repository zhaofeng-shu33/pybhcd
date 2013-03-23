#ifndef	TREE_H
#define	TREE_H

#include <glib.h>
#include "params.h"
#include "labelset.h"

struct Tree_t;
typedef struct Tree_t Tree;

Tree * leaf_new(Params * params, gpointer label);
Tree * branch_new(Params * params);
Tree * branch_new_full1(Params * params, ...);
#define	branch_new_full(params, ...)	branch_new_full1(params, __VA_ARGS__, NULL)

Tree * tree_copy(Tree * orig);
void tree_ref(Tree * tree);
void tree_unref(Tree * tree);

void tree_assert(Tree * tree);

void branch_add_child(Tree * branch, Tree * child);
GList * branch_get_children(Tree * branch);

gconstpointer leaf_get_label(Tree * leaf);

gboolean tree_is_leaf(Tree * tree);
Labelset * tree_get_labels(Tree * tree);
GList * tree_get_labelsets(Tree * tree);
Params * tree_get_params(Tree * tree);
gdouble tree_get_logprob(Tree *tree);
gdouble tree_get_logresponse(Tree *tree);
gdouble tree_logpredict(Tree *tree, gpointer src, gpointer dst, gboolean value);

guint tree_num_intern(Tree * tree);
guint tree_num_leaves(Tree * tree);

void tree_println(Tree * tree, const gchar *prefix);
void tree_tostring(Tree * tree, GString *str);
void tree_struct_tostring(Tree * tree, GString *str);

#endif /*TREE_H*/
