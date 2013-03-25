#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glib.h>
#include <glib/gprintf.h>
#include "nrt.h"


static gboolean binary_only = FALSE;
static guint build_restarts = 1000;
static guint seed = 0x2a23b6bb;
static gdouble param_gamma = 0.4;
static gdouble param_alpha = 1.0;
static gdouble param_beta = 0.2;
static gdouble param_delta = 0.2;
static gdouble param_lambda = 1.0;
static gchar *	test_fname = NULL;
static gchar 	output_prefix_default[] = "output/out";
static gchar *	output_prefix = output_prefix_default;
static gchar *	output_tree_fname = NULL;
static gchar *	output_pred_fname = NULL;
static gchar *	output_time_fname = NULL;

static GOptionEntry options[] = {
	{ "seed",	 's', 0, G_OPTION_ARG_INT,	&seed,		"set RNG seed to S",		"S" },

	{ "binary-only", 'B', 0, G_OPTION_ARG_NONE,	&binary_only, 	"only construct binary trees",	NULL },
	{ "restarts",	 'R', 0, G_OPTION_ARG_INT,	&build_restarts,"take best of N restarts",	"N" },

	{ "test-file",	 't', 0, G_OPTION_ARG_FILENAME,	&test_fname,	"test dataset", NULL },
	{ "prefix",	 'p',  0, G_OPTION_ARG_STRING,	&output_prefix,	"prefix for output filenames", NULL },

	{ "gamma",	 'g', 0, G_OPTION_ARG_DOUBLE,	&param_gamma,	"set mixture parameter to GAMMA","GAMMA" },
	{ "alpha",	 'a', 0, G_OPTION_ARG_DOUBLE,	&param_alpha,	"set on-diagonal one hyperparameter to ALPHA", "ALPHA" },
	{ "beta",	 'b', 0, G_OPTION_ARG_DOUBLE,	&param_beta,	"set on-diadonal zero hyperparameter to BETA", "BETA" },
	{ "delta",	 'd', 0, G_OPTION_ARG_DOUBLE,	&param_delta,	"set off-diagonal one hyperparameter to DELTA", "DELTA" },
	{ "lambda",	 'l', 0, G_OPTION_ARG_DOUBLE,	&param_lambda,	"set off-diadonal zero hyperparameter to LAMBDA", "LAMBDA" },
	{ NULL,		   0, 0, 0,			NULL,		NULL, NULL },
};

gchar * parse_args(int *argc, char ***argv) {
	GError * error;
	GOptionContext * ctx;

	ctx = g_option_context_new("FILE -- fit an NRT");
	g_option_context_add_main_entries(ctx, options, NULL);
	error = NULL;
	if (!g_option_context_parse(ctx, argc, argv, &error)) {
		g_print("option parsing failed: %s\n", error->message);
		goto error;
	}
	if (*argc < 2) {
		g_print("missing argument FILE\n");
		goto error;
	}
	if (*argc > 2) {
		g_print("too many arguments\n");
		goto error;
	}
	g_option_context_free(ctx);
	output_tree_fname = g_strdup_printf("%s.tree", output_prefix);
	output_pred_fname = g_strdup_printf("%s.pred", output_prefix);
	output_time_fname = g_strdup_printf("%s.time", output_prefix);
	return (*argv)[1];
error:
	g_print("%s", g_option_context_get_help(ctx, TRUE, NULL));
	g_option_context_free(ctx);
	exit(1);
}

Tree * run(GRand * rng, Dataset * dataset, gboolean verbose) {
	Params * params;
	Tree * root;
	Build * build;

	if (verbose) {
		dataset_println(dataset, "");
	}

	params = params_new(dataset,
			param_gamma,
			param_alpha, param_beta,
			param_delta, param_lambda);
	params->binary_only = binary_only;

	build = build_new(rng, params, build_restarts, FALSE);
	params_unref(params);
	build_run(build);
	root = build_get_best_tree(build);
	tree_ref(root);
	build_free(build);

	g_assert(tree_num_leaves(root) == dataset_num_labels(dataset));
	return root;
}

void eval_test(Tree * root, GIOChannel *io) {
	Dataset * test;
	GList * pairs;
	gint value_omitted;

	if (test_fname == NULL) {
		return;
	}
	test = dataset_gml_load(test_fname);
	pairs = dataset_get_label_pairs(test, &value_omitted);
	// better not be sparse.
	g_assert(value_omitted < 0);
	for (GList * xx = pairs; xx != NULL; xx = g_list_next(xx)) {
		Pair * pair = xx->data;
		gboolean missing;
		gboolean value = dataset_get(test, pair->fst, pair->snd, &missing);
		gdouble logpred_true = tree_logpredict(root, pair->fst, pair->snd, TRUE);
		gdouble logpred_false = tree_logpredict(root, pair->fst, pair->snd, FALSE);
		g_assert(!missing);
		io_printf(io, "%s,%s,%s,%1.17e,%1.17e\n",
				dataset_label_to_string(test, pair->fst),
				dataset_label_to_string(test, pair->snd),
				(value? "true": "false"),
				logpred_false,
				logpred_true);
	}
	dataset_get_label_pairs_free(pairs);
	dataset_unref(test);
}

void timer_save_io(GTimer * timer, GIOChannel * io) {
	io_printf(io, "time: %es\n", g_timer_elapsed(timer, NULL));
}

int main(int argc, char * argv[]) {
	GRand * rng;
	GTimer * timer;
	Dataset * dataset;
	gchar *fname;
	Tree * root;

	fname = parse_args(&argc, &argv);

	g_print("seed: %x\n", seed);
	g_print("output prefix: %s\n", output_prefix);
	rng = g_rand_new_with_seed(seed);
	timer = g_timer_new();
	dataset = dataset_gml_load(fname);

	g_timer_start(timer);
	root = run(rng, dataset, FALSE);
	g_timer_stop(timer);

	io_stdout((IOFunc)timer_save_io, timer);
	tree_println(root, "tree: ");

	io_writefile(output_time_fname, (IOFunc)timer_save_io, timer);
	tree_io_save(root, output_tree_fname);

	io_writefile(output_pred_fname, (IOFunc)eval_test, root);

	tree_unref(root);
	g_free(output_tree_fname);
	g_free(output_pred_fname);
	g_free(output_time_fname);
	dataset_unref(dataset);
	g_timer_destroy(timer);
	g_rand_free(rng);
	return 0;
}

