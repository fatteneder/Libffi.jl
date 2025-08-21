#include <julia.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>


jl_value_t * mwe_jl_alloc_genericmemory_carg(size_t nel) {
   jl_value_t *memory_type = jl_eval_string("Memory{Int64}");
   printf("memory_type = %p\n", memory_type);
   printf("nel = %ld\n", nel);
   fflush(stdout);
   jl_value_t *memory = (jl_value_t *)jl_alloc_genericmemory(memory_type, nel);
   printf("memory = %p\n", memory);
   printf("jl_typeof_str(memory_type) = %s\n", jl_typeof_str(memory_type));
   printf("jl_typeof_str(memory) = %s\n", jl_typeof_str(memory));
   return memory;
}

jl_value_t * mwe_jl_alloc_genericmemory_jlarg(jl_value_t *memory_type) {
   jl_value_t *memory_type_from_eval = jl_eval_string("Memory{Int64}");
   size_t nel = 3;
   printf("memory_type = %p\n", memory_type);
   printf("memory_type_from_eval = %p\n", memory_type_from_eval);
   printf("jl_typeof_str(memory_type) = %s\n", jl_typeof_str(memory_type));
   printf("jl_typeof_str(memory_type_from_eval) = %s\n", jl_typeof_str(memory_type_from_eval));
   if (memory_type != memory_type_from_eval)
      jl_errorf("mwe_jl_alloc_genericmemory_jlarg: jl_value_t *memory_type is wrong: %p", memory_type);
   jl_value_t *memory = (jl_value_t *)jl_alloc_genericmemory(memory_type, nel);
   printf("memory = %p\n", memory);
   printf("jl_typeof_str(memory) = %s\n", jl_typeof_str(memory));
   fflush(stdout);
   return memory;
}

int64_t mwe_accept_jl_type(jl_value_t *x) {
   jl_value_t *y = jl_get_field(x, "y");
   return jl_unbox_int64(y);
}

int64_t mwe_my_square_jl(jl_value_t *x) {
   int64_t xx = jl_unbox_int64(x);
   return xx*xx;
}

int mwe_my_square(int x) {
   printf("SERS x = %d\n", x);
   return x*x;
}

int mwe_my_square_w_ptr_arg(int *x) {
   return (*x)*(*x);
}

void mwe_do_nothing(void) {
   printf("doing nothing on the C side...\n");
}

int * mwe_alloc_an_array(int n) {
   int *a = (int *)malloc(sizeof(int)*n);
   for (int i = 0; i < n; i++)
      a[i] = i;
   return a;
}

jl_value_t * get_tuple_pointer() {
   jl_value_t *tpl = jl_eval_string("(2,)");
   printf("jl_is_tuple(tpl) = %d\n", jl_is_tuple(tpl));
   return tpl;
}

int64_t mwe_foreign_carg_cret(int64_t n) {
   printf("n = %ld\n", n);
   return 1;
}

int64_t mwe_foreign_cptr_cret(int64_t *n) {
   printf("n = %p\n", n);
   printf("n[1] = %ld\n", n[1]);
   return 1;
}

int64_t mwe_foreign_jlarg_cret(jl_value_t *n) {
   printf("n = %p\n", n);
   printf("jl_typeof_str(n) = ");
   printf("%s\n", jl_typeof_str(n));
   return 1;
}

jl_value_t * mwe_foreign_carg_jlret(int64_t n) {
   printf("n = %ld\n", n);
   jl_value_t *v = jl_eval_string("1");
   return v;
}

jl_value_t * mwe_foreign_jlarg_jlret(jl_value_t *n) {
   printf("n = %p\n", n);
   printf("jl_typeof_str(n) = %s\n", jl_typeof_str(n));
   jl_value_t *v = jl_eval_string("1");
   return v;
}

typedef struct _my_type {
   int x;
} my_type;

my_type mwe_my_type(int x) {
   my_type mt;
   mt.x = x;
   return mt;
}

void mwe_jl_is_module(jl_value_t *m) {
   printf("jl_is_module(m) = %d\n", jl_is_module(m));
   jl_value_t *mt = jl_typeof(m);
   printf("mt == (jl_value_t *)jl_module_type = %d\n", mt == (jl_value_t *)jl_module_type);
   return;
}

// from libccalltest.c
typedef struct {
    int64_t real;
    int64_t imag;
} complex_t;

int64_t mwe_ctest_jl_arg_c_ret(complex_t a) {
   printf("a.real = %ld\n", a.real);
   printf("a.imag = %ld\n", a.imag);
   return a.real + a.imag;
}

complex_t mwe_ctest_c_arg_jl_ret(int64_t real, int64_t imag) {
   complex_t a;
   a.real = real;
   a.imag = imag;
   return a;
}
