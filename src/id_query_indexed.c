#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <stdint.h>
#include <errno.h>
#include <assert.h>

#include "record.h"
#include "id_query.h"

struct indexed_data {
    struct indexed_record *irs;
    int n;
};

struct indexed_data* mk_indexed(struct record* rs, int n) {
  struct indexed_data* data = malloc(sizeof(struct indexed_data));
  data->irs = malloc(n * sizeof(struct indexed_record));
  data->n = n;

  for (int i = 0; i < n; i++) {
    data->irs[i].osm_id = rs[i].osm_id;
    data->irs[i].record = &rs[i];
  }
  return data;
}

void free_indexed(struct indexed_data* data) {
  free(data);
}

const struct record* lookup_indexed(struct indexed_data *data, int64_t needle) {
  int64_t current_record = 0;
  while(current_record < data->n) {
    if(data->irs[current_record].osm_id == needle) {
        return data->irs[current_record].record;
    }
    current_record++;
  }
  return NULL;
}

int main(int argc, char** argv) {
  return id_query_loop(argc, argv,
                    (mk_index_fn)mk_indexed,
                    (free_index_fn)free_indexed,
                    (lookup_fn)lookup_indexed);
}
