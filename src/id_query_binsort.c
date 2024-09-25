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

int compare_index(const void *a, const void *b) {
  const struct indexed_record *rec_a = (const struct indexed_record *)a;
  const struct indexed_record *rec_b = (const struct indexed_record *)b;
  
  if(rec_a->osm_id > rec_b->osm_id) {return 1;};
  if(rec_a->osm_id < rec_b->osm_id) {return -1;};
  return 0;
}

struct indexed_data* mk_indexed(struct record* rs, int n) {
  struct indexed_data* data = malloc(sizeof(struct indexed_data));
  data->irs = malloc(n * sizeof(struct indexed_record));
  data->n = n;

  for (int i = 0; i < n; i++) {
    data->irs[i].osm_id = rs[i].osm_id;
    data->irs[i].record = &rs[i];
  }
  qsort(data->irs, n, sizeof(struct indexed_record), compare_index);
  return data;
}

void free_indexed(struct indexed_data* data) {
  free(data->irs);
  free(data);
}

const struct record* lookup_binsearch(struct indexed_data *data, int64_t needle) {
  int64_t low = 0;
  int64_t high = data->n-1;
  while(low <= high) {
    int64_t mid = (low + high) / 2;
    if(data->irs[mid].osm_id == needle) {
      return data->irs[mid].record;
    } else if (data->irs[mid].osm_id < needle) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return NULL;
}

int main(int argc, char** argv) {
  return id_query_loop(argc, argv,
                    (mk_index_fn)mk_indexed,
                    (free_index_fn)free_indexed,
                    (lookup_fn)lookup_binsearch);
}
