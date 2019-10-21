# distutils: language = c
# cython: language_level=3
from libc.string cimport strlen
from cython.operator import address

import networkx as nx

cdef extern from "glib.h":
    ctypedef char gchar
    ctypedef unsigned int guint
    ctypedef int gint
    ctypedef void* gpointer
    ctypedef gint gboolean
    ctypedef double gdouble
    ctypedef const void* gconstpointer
    ctypedef void(*GDestroyNotify)(gpointer)
    ctypedef guint(*GHashFunc)(gconstpointer)
    ctypedef gboolean(*GEqualFunc)(gconstpointer, gconstpointer)
    ctypedef struct GRand:
        pass
    ctypedef struct GHashTable:
        pass
    ctypedef struct GQueue:
        pass
    ctypedef struct GList:
        gpointer data
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
    GList* g_list_next(GList*)
    guint g_str_hash(gconstpointer)
    gboolean g_str_equal(gconstpointer, gconstpointer)
    gboolean g_hash_table_insert(GHashTable*, gpointer, gpointer)
    GHashTable* g_hash_table_new_full(GHashFunc, GEqualFunc, GDestroyNotify, GDestroyNotify)
    void g_hash_table_unref(GHashTable*)
    gchar* g_strdup(const gchar*)

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
    ctypedef struct DatasetPairIter:
        pass
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
    void pair_free(Pair*)
    GList* branch_get_children(Tree*)
    void dataset_label_pairs_iter_init(Dataset*, DatasetPairIter*)
    gboolean dataset_label_pairs_iter_next(DatasetPairIter*, gpointer*, gpointer*)
    gdouble tree_logpredict(Tree*, gconstpointer, gconstpointer, gboolean)
    gboolean dataset_get(Dataset*, gconstpointer, gconstpointer, gboolean*)
    void dataset_unref(Dataset*)

cdef void construct_dataset_from_networkx_graph(nx_obj, Dataset* dataset_ptr):
    cdef GHashTable * id_labels
    cdef char* node_label_c_str
    cdef gpointer label
    cdef gchar* id    
    cdef gpointer src
    cdef gpointer dst
    
    nedges = len(nx_obj.edges)
    nvertices = len(nx_obj.nodes)
    # load dataset
    id_labels = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL)
    dataset_ptr = dataset_new()
    for n in nx_obj.nodes():
        n_byte_str = str(n).encode('ascii')
        node_label_c_str = <char*> n_byte_str
        label = dataset_label_create(dataset_ptr, <gchar*> node_label_c_str)
        id = g_strdup(<gchar*> node_label_c_str)
        g_hash_table_insert(id_labels, id, label)
    for u, v in nx_obj.edges():
        u_byte_str = str(u).encode('ascii')
        node_label_c_str = <char*> u_byte_str
        src = g_hash_table_lookup(id_labels, node_label_c_str)
        v_byte_str = str(v).encode('ascii')
        node_label_c_str = <char*> v_byte_str
        dst = g_hash_table_lookup(id_labels, node_label_c_str)
        dataset_set(dataset_ptr, src, dst, 1)
    g_hash_table_unref(id_labels)
    # end load dataset
    
cdef get_edge_prediction(num_nodes, Tree* tree_root_ptr):
    cdef Dataset* dataset_ptr = NULL
    cdef DatasetPairIter pairs
    cdef gpointer src = NULL
    cdef gpointer dst = NULL
    cdef gboolean value, missing
    cdef gdouble logpred_true, logpred_false
    nx_obj = nx.Graph()
    for i in range(num_nodes):
        for j in range(i+1, num_nodes):
            nx_obj.add_edge(i, j)
    construct_dataset_from_networkx_graph(nx_obj, dataset_ptr)
    dataset_label_pairs_iter_init(dataset_ptr, &pairs)
    edges = []
    while dataset_label_pairs_iter_next(&pairs, &src, &dst):
        value = dataset_get(dataset_ptr, src, dst, &missing)
        logpred_true = tree_logpredict(tree_root_ptr, src, dst, 1)
        logpred_false = tree_logpredict(tree_root_ptr, src, dst, 0)
        py_byte_str_1 = dataset_label_to_string(dataset_ptr, src)
        py_byte_str_2 = dataset_label_to_string(dataset_ptr, dst)
        py_boolean = value > 0
        edges.append([py_byte_str_1.decode('ascii'),
                      py_byte_str_2.decode('ascii'),
                      py_boolean,
                      logpred_true,
                      logpred_false])
    dataset_unref(dataset_ptr)
    return edges

cpdef bhcd(nx_obj, gamma=0.4, alpha=1.0, beta=0.2, delta=1.0, _lambda=0.2, binary_only=False, restarts=1, sparse=False, predict=False):
    cdef GRand* rng_ptr
    cdef Params* params_ptr
    cdef Dataset* dataset_ptr = NULL
    cdef Build* build_ptr
    cdef Tree* tree_root_ptr
    cdef int nedges, nvertices  
    cdef gint next_index = -1
    cdef Pair* cur
    cdef Tree* tree_tmp_ptr
    cdef gint parent_index
    cdef GQueue * qq
    cdef GList * child

    construct_dataset_from_networkx_graph(nx_obj, dataset_ptr)
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
    json_root = {"fit":{}}
    json_root["fit"]["logprob"] = tree_get_logprob(tree_root_ptr)
    if predict:
        json_root["fit"]["edge"] = get_edge_prediction(len(nx_obj.edges), tree_root_ptr)
    
    tree_list = []
    qq = g_queue_new()
    g_queue_push_head(qq, pair_new(GINT_TO_POINTER(next_index), tree_root_ptr))
    next_index += 1
    while (not g_queue_is_empty(qq)):
        cur = <Pair*> g_queue_pop_head(qq)
        parent_index = GPOINTER_TO_INT(cur.fst)
        tree_tmp_ptr = <Tree*> cur.snd
        if (tree_is_leaf(tree_tmp_ptr)):
            tree_item_property = {}
            tree_item_property["logProb"] = tree_get_logprob(tree_tmp_ptr)
            tree_item_property["logresp"] = tree_get_logresponse(tree_tmp_ptr)
            tree_item_property["parent"] = parent_index
            py_byte_str = dataset_label_to_string(dataset_ptr, leaf_get_label(tree_tmp_ptr))
            tree_item_property["label"] = py_byte_str.decode('ascii')
            tree_list.append({"leaf":tree_item_property})
        else:
            if (parent_index == -1):
                tree_item_property = {}
                tree_item_property["logProb"] = tree_get_logprob(tree_tmp_ptr)
                tree_item_property["logresp"] = tree_get_logresponse(tree_tmp_ptr)
                tree_item_property["id"] = next_index
                tree_list.append({"root":tree_item_property})
            else:
                tree_item_property = {}
                tree_item_property["logProb"] = tree_get_logprob(tree_tmp_ptr)
                tree_item_property["logresp"] = tree_get_logresponse(tree_tmp_ptr)
                tree_item_property["parent"] = parent_index
                tree_item_property["child"] = next_index
                tree_list.append({"stem":tree_item_property})
            child = branch_get_children(tree_tmp_ptr)
            while (child != NULL):
                g_queue_push_tail(qq, pair_new(GINT_TO_POINTER(next_index), child.data))
                child = g_list_next(child)
            next_index += 1
        pair_free(cur)
    g_queue_free(qq)
    json_root["tree"] = tree_list
    # end json instance
    tree_ref(tree_root_ptr)
    build_free(build_ptr)
    tree_unref(tree_root_ptr)
    dataset_unref(dataset_ptr)
    g_rand_free(rng_ptr)
    return json_root
