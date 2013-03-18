#include <stdio.h>
#include <string.h>
#include <glib.h>
#include "nrt.h"

void run(GRand * rng, Dataset * dataset, gboolean verbose) {
	Params * params;
	GList * labels;
	Tree * root;

	if (verbose) {
		dataset_println(dataset, "");
	}

	params = params_default(dataset);

	labels = dataset_get_labels(dataset);

	root = build(params, labels);

	tree_println(root, "result: ");

	g_assert(tree_num_leaves(root) == dataset_num_labels(dataset));
	tree_unref(root);
	g_list_free(labels);
	params_unref(params);
}

int main(int argc, char * argv[]) {
	GRand * rng;
	GTimer * timer;
	Dataset * dataset;
	gchar *fname;

	fname = argv[1];

	rng = g_rand_new();
	timer = g_timer_new();
	dataset = dataset_gml_load(fname);

	g_timer_start(timer);
	run(rng, dataset, FALSE);
	g_timer_stop(timer);
	g_print("time: %es\n", g_timer_elapsed(timer, NULL));

	dataset_unref(dataset);
	g_timer_destroy(timer);
	g_rand_free(rng);
	return 0;
}

