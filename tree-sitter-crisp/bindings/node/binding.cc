#include <napi.h>

typedef struct TSLanguage TSLanguage;

extern "C" TSLanguage *tree_sitter_crisp();

// "tree-sitter", "currentVersion" hance changing the namespace to "tree_sitter_crisp"

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports["name"] = Napi::String::New(env, "crisp");
  auto language = Napi::External<TSLanguage>::New(env, tree_sitter_crisp());
  exports["language"] = language;
  return exports;
}

NODE_API_MODULE(tree_sitter_crisp_binding, Init)
