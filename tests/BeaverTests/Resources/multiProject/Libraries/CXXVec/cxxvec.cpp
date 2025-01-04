#include <vector>

extern "C" void* new_vec() {
  return (void*) new std::vector<int>();
}

extern "C" void vec_destroy(void* _vec) {
  std::vector<int>* vec = (std::vector<int>*) _vec;
  delete vec;
}

extern "C" void vec_push(void* _vec, int val) {
  std::vector<int>* vec = (std::vector<int>*) _vec;
  vec->push_back(val);
}

extern "C" int vec_get(void* _vec, int idx) {
  std::vector<int>* vec = (std::vector<int>*) _vec;
  return vec->at(idx);
}
