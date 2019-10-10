# distutils: language = c
# cython: language_level=3
from libc.string cimport strlen
from cython.operator import address


cdef extern from "glib.h":
    ctypedef char gchar
    ctypedef unsigned int guint
    ctypedef int gint
    ctypedef void* gpointer
    ctypedef gint gboolean
    ctypedef double gdouble
    ctypedef const void* gconstpointer
    ctypedef struct GRand:
        pass
    ctypedef struct GHashTable:
        pass
    ctypedef struct GQueue:
        pass
    GRand* g_rand_new()
    void g_rand_free(GRand* rand_)
    void g_free(gpointer mem)
    gpointer g_hash_table_lookup(GHashTable*, gconstpointer)
    GQueue* g_queue_new()
    void g_queue_push_head(GQueue*, gpointer)
    gboolean g_queue_is_empty(GQueue*)
    gpointer g_queue_pop_head(GQueue*)
    void g_queue_push_tail(GQueue*, gpointer)
    void g_queue_free(GQueue*)

cdef extern from "bhcd/bhcd/bhcd.h":
    ctypedef struct Tree:
        pass
    ctypedef struct Dataset:
        GHashTable* labels

    ctypedef struct Build:
        pass
    ctypedef struct Params:
        gboolean binary_only
    ctypedef struct Pair:
        gpointer fst
        gpointer snd

    void tree_io_save_string(Tree*, gchar**)
    Build * build_new(GRand *rng, Params * params, guint num_restarts, gboolean sparse)
    Dataset* dataset_new()
    Params * params_new(Dataset *, gdouble, gdouble, gdouble, gdouble, gdouble)
    void build_set_verbose(Build * build, gboolean value)
    void params_unref(Params * params)
    void build_run(Build * build)
    Tree * build_get_best_tree(Build * build)
    void build_free(Build * build)
    void tree_ref(Tree * tree)
    void tree_unref(Tree * tree)
    gpointer dataset_label_create(Dataset*, const gchar*)
    void dataset_set(Dataset*, gpointer, gpointer, gboolean)
    Pair* pair_new(gpointer, gpointer)
    gpointer GINT_TO_POINTER(gint)
    gint GPOINTER_TO_INT(gpointer)
    gdouble tree_get_logprob(Tree*)
    gdouble tree_get_logresponse(Tree*)
    gboolean tree_is_leaf(Tree*)
    const gchar* dataset_label_to_string(Dataset*, gconstpointer)
    gconstpointer leaf_get_label(Tree*)
    
cpdef bhcd(nx_obj, gamma=0.4, alpha=1.0, beta=0.2, delta=1.0, _lambda=0.2, binary_only=False, restarts=1, sparse=False):
    cdef GRand* rng_ptr
    cdef Params* params_ptr
    cdef Dataset* dataset_ptr
    cdef Build* build_ptr
    cdef Tree* tree_root_ptr
    cdef int nedges, nvertices
    cdef char* node_label_c_str
    cdef gpointer src
    cdef gpointer dst
    cdef gint next_index = -1
    cdef Pair* cur
    cdef Tree* tree_tmp_ptr
    cdef gint parent_index
    cdef GQueue * qq
    
    nedges = len(nx_obj.edges)
    nvertices = len(nx_obj.nodes)
    # load dataset
    dataset_ptr = dataset_new()
    for n in nx_obj.nodes():
        node_label_c_str = <char*> n
        dataset_label_create(dataset_ptr, <gchar*> node_label_c_str)
    for u, v in nx_obj.edges():
        node_label_c_str = <char*> u
        src = g_hash_table_lookup(dataset_ptr.labels, node_label_c_str)
        node_label_c_str = <char*> v
        dst = g_hash_table_lookup(dataset_ptr.labels, node_label_c_str)
        dataset_set(dataset_ptr, src, dst, 1)
    # end load dataset
    rng_ptr = g_rand_new()
    params_ptr = params_new(dataset_ptr, <gdouble> gamma, <gdouble> alpha, 
        <gdouble> beta, <gdouble> delta, <gdouble> _lambda)    
    params_ptr.binary_only = <gboolean> binary_only
    build_ptr = build_new(rng_ptr, params_ptr, <guint> restarts, <gboolean> sparse)
    build_set_verbose(build_ptr, 0)
    params_unref(params_ptr)
    build_run(build_ptr)
    tree_root_ptr = build_get_best_tree(build_ptr)
    # build json instance
    json_root = {}
    json_root["fit"]["logprob"] = tree_get_logprob(tree_root_ptr)
    tree_list = []
    qq = g_queue_new()
    g_queue_push_head(qq, pair_new(GINT_TO_POINTER(next_index), tree_root_ptr))
    next_index += 1
    while (not g_queue_is_empty(qq)):
        cur = <Pair*> g_queue_pop_head(qq)
        parent_index = GPOINTER_TO_INT(cur.fst)
        tree_tmp_ptr = <Tree*> cur.snd
        if (tree_is_leaf(tree_root_ptr)):
            tree_item_property = {}
            tree_item_property["logProb"] = tree_get_logprob(tree_tmp_ptr)
            tree_item_property["logresp"] = tree_get_logresponse(tree_tmp_ptr)
            tree_item_property["parent"] = parent_index
            tree_item_property["label"] = dataset_label_to_string(dataset_ptr, leaf_get_label(tree_tmp_ptr))
            tree_list.append({"leaf":tree_item_property})
    json_root["tree"] = tree_list
    # end json instance
    tree_ref(tree_root_ptr)
    build_free(build_ptr)
    tree_unref(tree_root_ptr)
    g_rand_free(rng_ptr)
