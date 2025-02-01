#include <flatbuffers/flatbuffers.h>
#include "../MyFileFormat_generated.h"
#include <stdint.h>
#include <assert.h>
#include <string.h>

int main(void) {
  flatbuffers::FlatBufferBuilder builder;

  auto person = CreatePersonDirect(builder, "John", "Doe", 0);
  builder.Finish(person);

  const uint8_t* flatbuffer = builder.GetBufferPointer();

  const Person* deserializedPerson = GetPerson(flatbuffer);

  assert(strcmp(deserializedPerson->fname()->c_str(), "John") == 0);
  assert(strcmp(deserializedPerson->lname()->c_str(), "Doe") == 0);
  assert(deserializedPerson->birthdate() == 0);
}

