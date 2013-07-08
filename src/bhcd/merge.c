#include "merge.h"
#include "sscache.h"

static gdouble merge_calc_logprob_rel(Params * params, Tree * aa, Tree * bb);


Merge * merge_new(GRand * rng, Merge * parent, Params * params, guint ii, Tree * aa, guint jj, Tree * bb, Tree * mm) {
	Merge * merge;
	gdouble logprob_rel;

	merge = g_slice_new(Merge);
	merge->ii = ii;
	merge->jj = jj;
	merge->tree = mm;
	tree_ref(merge->tree);
	logprob_rel = merge_calc_logprob_rel(params, aa, bb);
	merge->score = tree_get_logprob(merge->tree)
	       		- tree_get_logprob(aa) - tree_get_logprob(bb) - logprob_rel;
	merge->sym_break = g_rand_double(rng);
	return merge;
}

void merge_free(Merge * merge) {
	tree_unref(merge->tree);
	g_slice_free(Merge, merge);
}

void merge_free1(gpointer merge, gpointer data) {
	merge_free(merge);
}


void merge_println(const Merge * merge, const gchar * prefix) {
	GString * out;

	out = g_string_new(prefix);
	merge_tostring(merge, out);
	g_print("%s\n", out->str);
	g_string_free(out, TRUE);
}

void merge_tostring(const Merge * merge, GString * out) {
	g_string_append_printf(out, "%03d + %03d (%2.2e/%1.2e)-> ", merge->ii, merge->jj, merge->score, merge->sym_break);
	tree_tostring(merge->tree, out);
}

Merge * merge_join(GRand * rng, Merge * parent, Params * params, guint ii, Tree * aa, guint jj, Tree * bb) {
	Tree * tree;
	Merge * merge;

	tree = branch_new(params);
	branch_add_child(tree, aa);
	branch_add_child(tree, bb);
	merge = merge_new(rng, parent, params, ii, aa, jj, bb, tree);
	tree_unref(tree);
	return merge;
}

Merge * merge_absorb(GRand * rng, Merge * parent, Params * params, guint ii, Tree * aa, guint jj, Tree * bb) {
	/* absorb bb as a child of aa */
	Tree * tree;
	Merge * merge;

	if (tree_is_leaf(aa) || params->binary_only) {
		return NULL;
	}

	tree = tree_copy(aa);
	branch_add_child(tree, bb);
	merge = merge_new(rng, parent, params, ii, aa, jj, bb, tree);
	tree_unref(tree);
	return merge;
}

Merge * merge_collapse(GRand * rng, Merge * parent, Params * params, guint ii, Tree * aa, guint jj, Tree * bb) {
	/* make children of aa and children of bb all children of a new node */
	Tree * tree;
	Merge * merge;
	GList * child;

	if (tree_is_leaf(aa) || params->binary_only) {
		return NULL;
	}

	tree = branch_new(params);
	for (child = branch_get_children(aa); child != NULL; child = g_list_next(child)) {
		branch_add_child(tree, child->data);
	}
	for (child = branch_get_children(bb); child != NULL; child = g_list_next(child)) {
		branch_add_child(tree, child->data);
	}
	merge = merge_new(rng, parent, params, ii, aa, jj, bb, tree);
	tree_unref(tree);
	return merge;
}

Merge * merge_best(GRand * rng, Merge * parent, Params * params, guint ii, Tree * aa, guint jj, Tree * bb) {
	Merge * merge;
	Merge * best_merge;

	best_merge = merge_join(rng, parent, params, ii, aa, jj, bb);
	merge = merge_absorb(rng, parent, params, ii, aa, jj, bb);
	if (merge != NULL) {
		if (merge->score > best_merge->score) {
			merge_free(best_merge);
			best_merge = merge;
		} else {
			merge_free(merge);
		}
	}
	merge = merge_absorb(rng, parent, params, jj, bb, ii, aa);
	if (merge != NULL) {
		if (merge->score > best_merge->score) {
			merge_free(best_merge);
			best_merge = merge;
		} else {
			merge_free(merge);
		}
	}
	return best_merge;
}

static gdouble merge_calc_logprob_rel(Params * params, Tree * aa, Tree * bb) {
	gpointer offblock;
	gdouble logprob_rel;

	offblock = sscache_get_offblock(params->sscache,
			tree_get_merge_left(aa),
			tree_get_merge_right(aa),
			tree_get_merge_left(bb),
			tree_get_merge_right(bb));
	/*
	g_print("score offblock: ");
	suffstats_print(offblock);
	g_print("\n");
	*/
	logprob_rel = params_logprob_offscore(params, offblock);
	return logprob_rel;
}

gint merge_cmp_neg_score(gconstpointer paa, gconstpointer pbb) {
	const Merge * aa = paa;
	const Merge * bb = pbb;
	gdouble diff = bb->score - aa->score;
	if (diff < 0) {
		return -1;
	} else if (diff > 0) {
		return 1;
	} else {
		if (bb->sym_break < aa->sym_break) {
			return -1;
		} else if (bb->sym_break > aa->sym_break) {
			return 1;
		} else {
			/*
			merge_println(aa, "aa: ");
			merge_println(bb, "bb: ");
			*/
			g_warning("unable to break tie!");
			// really no way to discriminate!
			return 0;
		}
	}
}

