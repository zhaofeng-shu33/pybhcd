# distutils: language = c
from libc.string cimport strlen
from cython.operator import address

cdef extern from "bhcd/bhcd/bhcd.h":
    ctypedef char gchar
    ctypedef unsigned int guint
    ctypedef int gint
    ctypedef gint gboolean
    ctypedef double gdouble
    ctypedef void* gpointer
    
    ctypedef struct GRand:
        pass
    ctypedef struct Tree:
        pass
    ctypedef struct Dataset:
        pass
    ctypedef struct Build:
        pass
    ctypedef struct Params:
        gboolean binary_only

    GRand* g_rand_new()
    void tree_io_save_string(Tree*, gchar**)
    Build * build_new(GRand *rng, Params * params, guint num_restarts, gboolean sparse)
    Dataset * dataset_gml_load(const gchar*)
    Params * params_new(Dataset *, gdouble, gdouble, gdouble, gdouble, gdouble)
    void build_set_verbose(Build * build, gboolean value)
    void params_unref(Params * params)
    void build_run(Build * build)
    Tree * build_get_best_tree(Build * build)
    void build_free(Build * build)
    void tree_ref(Tree * tree)
    void tree_unref(Tree * tree)
    void g_rand_free(GRand* rand_)
    void g_free(gpointer mem)
    void tree_io_save_string(Tree* tree, gchar** strbufferptr)
    
cpdef bhcd(gml_py_str, gamma=0.4, alpha=1.0, beta=0.2, delta=1.0, _lambda=0.2, binary_only=False, restarts=1, sparse=False):
    cdef char* gml_c_str
    cdef GRand* rng_ptr
    cdef Params* params_ptr
    cdef Dataset* dataset_ptr
    cdef Build* build_ptr
    cdef Tree* root_ptr
    cdef gchar* strbuffer
    gml_py_byte = (gml_py_str + '\n').encode('ascii')
    gml_c_str = gml_py_byte
    rng_ptr = g_rand_new()
    dataset_ptr = dataset_gml_load( <gchar*> gml_c_str)
    params_ptr = params_new(dataset_ptr, <gdouble> gamma, <gdouble> alpha, 
        <gdouble> beta, <gdouble> delta, <gdouble> _lambda)    
    params_ptr.binary_only = <gboolean> binary_only
    build_ptr = build_new(rng_ptr, params_ptr, <guint> restarts, <gboolean> sparse)
    build_set_verbose(build_ptr, 0)
    params_unref(params_ptr)
    build_run(build_ptr)
    root_ptr = build_get_best_tree(build_ptr)
    tree_ref(root_ptr)
    build_free(build_ptr)
    tree_io_save_string(root_ptr, address(strbuffer))
    cdef gint str_size = strlen(strbuffer)
    tree_unref(root_ptr)
    g_rand_free(rng_ptr)
    cdef bytes py_result_string = strbuffer
    g_free(strbuffer)
    return py_result_string.decode('ascii')
