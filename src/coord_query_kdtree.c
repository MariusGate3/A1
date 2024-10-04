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

struct node {
  struct record *rs;
  double lon;
  double lat;
  struct node *left;
  struct node *right;
};

double eucldist(double lon, double lon_dest, double lat, double lat_dest) {
  return sqrt(((lon-lon_dest) * (lon-lon_dest)) + ((lat-lat_dest) * (lat-lat_dest)));
}

int sort_by_lon(const void *a, const void *b) {
    struct record *r1 = (struct record *)a;
    struct record *r2 = (struct record *)b;
    if (r1->lon < r2->lon) {
        return -1;
    } else if (r1->lon > r2->lon) {
        return 1;   
    }
    return 0;
}

int sort_by_lat(const void *a, const void *b) {
    struct record *r1 = (struct record *)a;
    struct record *r2 = (struct record *)b;
    if (r1->lat < r2->lat) {
        return -1;
    } else if (r1->lat > r2->lat) {
        return 1;   
    }
    return 0;
}

struct node* build_kd_tree (struct record* rs, int n, int depth) {
    if (n == 0) {
        return NULL;
    }

    if (depth % 2 == 0) {
        // Sorter baseret på x axis:
        qsort(rs, n, sizeof(struct record), sort_by_lon);

    } else {
        // Sorter baseret på y axis:
        qsort(rs, n, sizeof(struct record), sort_by_lat);
    }

    struct node *node = malloc(sizeof(struct node)); 
    int middle = n / 2;
    node->rs = &rs[middle];
    node->lon = rs[middle].lon;
    node->lat = rs[middle].lat;

    node->left = build_kd_tree(rs, middle, depth + 1);
    node->right = build_kd_tree(rs + middle + 1, n - middle - 1, depth + 1);

    return node;
}

struct node* mk_kd_tree (struct record* rs, int n) {
    return build_kd_tree(rs,n,0);
}

void free_naive(struct node* root) {
    if (root == NULL) {
        return;
    }
    free_naive(root->left);
    free_naive(root->right);
    free(root);
}

struct node* search_kd_tree(struct node *root, size_t depth, struct node *closest, double closest_dist, double targetLon, double targetLat) {
    if (root == NULL) {
        return closest;
    }

    double distToTarget = eucldist(root->lon, targetLon, root->lat, targetLat);

    if (closest == NULL || distToTarget < closest_dist) {
        closest = root;
        closest_dist = distToTarget;
    }

    struct node *nextNode;
    struct node *otherNode;
    double r_prime;

    if (depth % 2 == 0) {
        if (targetLon < root->lon) {
            nextNode = root->left;
            otherNode = root->right;
        } else {
            nextNode = root->right;
            otherNode = root->left;
        }
        r_prime = fabs(targetLon - root->lon);
    } else {
        if (targetLat < root->lat) {
            nextNode = root->left;
            otherNode = root->right;
        } else {
            nextNode = root->right;
            otherNode = root->left;
        }
        r_prime = fabs(targetLat - root->lat);
    }

    closest = search_kd_tree(nextNode, depth + 1, closest, closest_dist, targetLon, targetLat);
    closest_dist = eucldist(closest->lon, targetLon, closest->lat, targetLat);

    if (closest_dist > r_prime) {
        struct node *temp = search_kd_tree(otherNode, depth + 1, closest, closest_dist, targetLon, targetLat);
        double tempDist = eucldist(temp->lon, targetLon, temp->lat, targetLat);

        if (tempDist < closest_dist) {
            closest = temp;
        }
    }

    return closest;
}

const struct record* lookup_kd(struct node *root, double lon, double lat) {
    return search_kd_tree(root, 0, NULL, INFINITY, lon, lat)->rs;
}

int main(int argc, char** argv) {
  return coord_query_loop(argc, argv,
                          (mk_index_fn)mk_kd_tree,
                          (free_index_fn)free_naive,
                          (lookup_fn)lookup_kd);
}
