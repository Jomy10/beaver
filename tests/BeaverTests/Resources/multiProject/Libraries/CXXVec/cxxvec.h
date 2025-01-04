#ifdef __cplusplus
extern "C" {
#endif

void* new_vec();

void vec_destroy(void*);

void vec_push(void*, int);

int vec_get(void*, int);

#ifdef __cplusplus
}
#endif
