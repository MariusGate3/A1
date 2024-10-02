#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <stdint.h>
#include <errno.h>
#include <assert.h>
#include<math.h>

#include "record.h"
#include "coord_query.h"

struct naive_data {
  struct record *rs;
  int n;
};

double eucldist(double lon, double lon_dest, double lat, double lat_dest) {
  return sqrt(((lon-lon_dest) * (lon-lon_dest)) + ((lat-lat_dest) * (lat-lat_dest)));
}

struct naive_data* mk_naive(struct record* rs, int n) {
  struct naive_data* data = malloc(sizeof(struct naive_data));
  data->rs = rs;
  data->n = n;
  return data;
}

void free_naive(struct naive_data* data) {
  free(data);
}

const struct record* lookup_naive(struct naive_data *data, double lon, double lat) {
  const struct record* result_record = data->rs;
  int64_t current_record = 0;
  int64_t closest_record = 0;
  double min_distance = eucldist(data->rs[closest_record].lon, lon, data->rs[closest_record].lat, lat);

  while(current_record < data->n) {
    double current_distance = eucldist(data->rs[current_record].lon, lon, data->rs[current_record].lat,lat);
    if (current_distance < min_distance) {
      closest_record = current_record;
      min_distance = current_distance;
      result_record = &data->rs[closest_record];
    }
    current_record++;
  }
  return result_record;
}

int main(int argc, char** argv) {
  return coord_query_loop(argc, argv,
                          (mk_index_fn)mk_naive,
                          (free_index_fn)free_naive,
                          (lookup_fn)lookup_naive);
}
