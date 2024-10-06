#!/usr/bin/env bash

set -e

# colors for output
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RED='\033[31m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

VERBOSE=0
if [[ "$1" == "--verbose" ]]; then
  VERBOSE=1
fi

# compile programs
echo -e "${BLUE}${BOLD}Compiling programs...${RESET}"
for program in "random_ids" "id_query_naive" "id_query_binsort" "id_query_indexed" "coord_query_naive" "coord_query_kdtree"; do
  make "$program"
done

# Create test directories
mkdir -p test_files/naive_tests test_files/kdtree_tests test_files/binsort_tests test_files/indexed_tests test_files/random_coords
rm -rf test_files/naive_tests/* test_files/kdtree_tests/* test_files/binsort_tests/* test_files/indexed_tests/* test_files/random_coords/*

tsv_file="20000records.tsv"

# Test id naive implementation
echo -e "\n${YELLOW}${BOLD}Testing correctness of id naive implementation...${RESET}"
total_naive_tests=0
passed_naive_tests=0
exitcode=0

declare -A kvp
kvp[2202162]="2202162: France 1.875310 46.799535"
kvp[3219806]="3219806: Pierre-Perthuis 3.789289 47.432325"
kvp[43652]="43652: Campiglione-Fenile 7.322313 44.804598"
kvp[155009]="155009: Goyrans 1.425419 43.481700"

for id in "${!kvp[@]}"; do
  expected="${kvp[$id]}"
  actual=$(echo "$id" | ./id_query_naive "$tsv_file" | sed '/Reading records/d; /Building index/d; /Query time/d; /Total query runtime/d')
  let total_naive_tests+=1

  if diff <(echo "$actual") <(echo "$expected"); then
    [[ "$VERBOSE" -eq 1 ]] && echo -e "${GREEN}${BOLD}[PASS]${RESET} Test passed for ID ${id}"
    let passed_naive_tests+=1
  else
    [[ "$VERBOSE" -eq 1 ]] && echo -e "${RED}${BOLD}[FAIL]${RESET} Test failed for ID ${id}"
    exitcode=1
  fi
done
echo -e ">>> ${YELLOW}${BOLD}id_query_naive results: [${passed_naive_tests}/${total_naive_tests}] tests passed${RESET}"

# Generate random IDs
ids=5
echo -e "\n${BLUE}${BOLD}Generating random IDs for testing...${RESET}"
./random_ids "${tsv_file}" | head -n $ids > test_files/random_coords/random_ids.input

# Test id_query_binsort and id_query_indexed
echo -e "${BLUE}${BOLD}Running ID query tests with random IDs...${RESET}"
total_binsort_tests=0
passed_binsort_tests=0
total_indexed_tests=0
passed_indexed_tests=0
progress=0

while read -r random_id; do
  let progress+=1
  if [[ "$VERBOSE" -eq 0 ]]; then
    echo -ne ">>> ${CYAN}Running test [${progress}/${ids}]...${RESET}\r"
  fi

  echo "${random_id}" | ./id_query_naive "$tsv_file" | sed '/Reading records/d; /Building index/d; /Query time/d; /Total query runtime/d' > "test_files/naive_tests/${random_id}.naive.expected"

  for query_program in "id_query_binsort" "id_query_indexed"; do
    if [[ "$query_program" == "id_query_binsort" ]]; then
      output_folder="binsort_tests"
      let total_binsort_tests+=1
    else
      output_folder="indexed_tests"
      let total_indexed_tests+=1
    fi

    echo "${random_id}" | ./${query_program} "${tsv_file}" | sed '/Reading records/d; /Building index/d; /Query time/d; /Total query runtime/d' > "test_files/${output_folder}/${random_id}.${query_program}.actual"

    if diff -u "test_files/naive_tests/${random_id}.naive.expected" "test_files/${output_folder}/${random_id}.${query_program}.actual"; then
      if [[ "$query_program" == "id_query_binsort" ]]; then
        let passed_binsort_tests+=1
        [[ "$VERBOSE" -eq 1 ]] && echo -e "${GREEN}${BOLD}[PASS]${RESET} id_query_binsort test passed for ID ${random_id}"
      else
        let passed_indexed_tests+=1
        [[ "$VERBOSE" -eq 1 ]] && echo -e "${GREEN}${BOLD}[PASS]${RESET} id_query_indexed test passed for ID ${random_id}"
      fi
    else
      if [[ "$VERBOSE" -eq 1 ]]; then
        [[ "$query_program" == "id_query_binsort" ]] && echo -e "${RED}${BOLD}[FAIL]${RESET} id_query_binsort test failed for ID ${random_id}" || echo -e "${RED}${BOLD}[FAIL]${RESET} id_query_indexed test failed for ID ${random_id}"
      fi
      exitcode=1
    fi
  done
done < test_files/random_coords/random_ids.input

echo -e ">>> ${YELLOW}${BOLD}id_query_binsort results: [${passed_binsort_tests}/${total_binsort_tests}] tests passed${RESET}"
echo -e ">>> ${YELLOW}${BOLD}id_query_indexed results: [${passed_indexed_tests}/${total_indexed_tests}] tests passed${RESET}"
echo -e ">>> ${YELLOW}${BOLD}Note:${RESET} The correctness of ${CYAN}id_query_binsort${RESET} and ${CYAN}id_query_indexed${RESET} is verified by comparing their results against ${CYAN}id_query_naive${RESET}"

# Test correctness of coord naive implementation
echo -e "\n${YELLOW}${BOLD}Testing correctness of coord naive implementation...${RESET}"
total_coord_naive_tests=0
passed_coord_naive_tests=0

declare -A kvp2
kvp2["1.875310 46.799535"]="(1.875310,46.799535): France (1.875310,46.799535)"
kvp2["3.789289 47.432325"]="(3.789289,47.432325): Pierre-Perthuis (3.789289,47.432325)"
kvp2["7.322313 44.804598"]="(7.322313,44.804598): Campiglione-Fenile (7.322313,44.804598)"
kvp2["-50 -50"]="(-50.000000,-50.000000): Falkland Islands (-59.515303,-51.715778)"
kvp2["-50 60"]="(-50.000000,60.000000): Newfoundland and Labrador (-55.971164,49.124479)"
kvp2["1.425419 43.481700"]="(1.425419,43.481700): Goyrans (1.425419,43.481700)"

for coord in "${!kvp2[@]}"; do
  lon=$(echo "$coord" | cut -d' ' -f1)
  lat=$(echo "$coord" | cut -d' ' -f2)
  expected="${kvp2[$coord]}"
  
  actual=$(echo "$lon $lat" | ./coord_query_naive "$tsv_file" | sed '/Reading records/d; /Building index/d; /Query time/d; /Total query runtime/d')
  let total_coord_naive_tests+=1

  if [[ "$actual" == "$expected" ]]; then
    [[ "$VERBOSE" -eq 1 ]] && echo -e "${GREEN}${BOLD}[PASS]${RESET} Test passed for coordinates lon=${lon}, lat=${lat}"
    let passed_coord_naive_tests+=1
  else
    [[ "$VERBOSE" -eq 1 ]] && echo -e "${RED}${BOLD}[FAIL]${RESET} Test failed for coordinates lon=${lon}, lat=${lat}. Expected: $expected, but got: $actual"
    exitcode=1
  fi
done

echo -e ">>> ${YELLOW}${BOLD}coord_query_naive results: [${passed_coord_naive_tests}/${total_coord_naive_tests}] tests passed${RESET}"

# Test KD-tree implementation on random coordinates
echo -e "\n${YELLOW}${BOLD}Testing KD-tree implementation on random coordinates...${RESET}"
random_coords_file="test_files/random_coords/random_coords.input"
for i in {1..5}; do
  echo "$((RANDOM%360-180)) $((RANDOM%180-90))" >> "$random_coords_file"
done

total_kdtree_tests=0
passed_kdtree_tests=0

while read -r lon lat; do
  let total_kdtree_tests+=1
  
  echo "${lon} ${lat}" | ./coord_query_naive "$tsv_file" | sed '/Reading records/d; /Building index/d; /Query time/d; /Total query runtime/d' > "test_files/naive_tests/naive_${lon}_${lat}.out"
  echo "${lon} ${lat}" | ./coord_query_kdtree "$tsv_file" | sed '/Reading records/d; /Building index/d; /Query time/d; /Total query runtime/d' > "test_files/kdtree_tests/kdtree_${lon}_${lat}.out"

  if diff -u "test_files/naive_tests/naive_${lon}_${lat}.out" "test_files/kdtree_tests/kdtree_${lon}_${lat}.out"; then
    [[ "$VERBOSE" -eq 1 ]] && echo -e "${GREEN}${BOLD}[PASS]${RESET} Test passed for coordinates lon=${lon}, lat=${lat}"
    let passed_kdtree_tests+=1
  else
    [[ "$VERBOSE" -eq 1 ]] && echo -e "${RED}${BOLD}[FAIL]${RESET} Test failed for coordinates lon=${lon}, lat=${lat}. Expected: $expected, but got: $actual"
    exitcode=1
  fi
done < "$random_coords_file"

echo -e ">>> ${YELLOW}${BOLD}KD tree implementation summary: [${passed_kdtree_tests}/${total_kdtree_tests}] tests passed${RESET}"
echo -e ">>> ${YELLOW}${BOLD}Note:${RESET} The KD-tree implementation is tested by comparing its results against the naive implementation for coords"

# Total Tests passed
echo -e "\n${BLUE}${BOLD}Final Summary of All Tests${RESET}"
let total_passed=$((passed_naive_tests + passed_binsort_tests + passed_indexed_tests + passed_coord_naive_tests + passed_kdtree_tests))
let total_tests=$((total_naive_tests + total_binsort_tests + total_indexed_tests + total_coord_naive_tests + total_kdtree_tests))
echo -e ">>> ${YELLOW}${BOLD}Total: [${total_passed}/${total_tests}] tests passed${RESET}"

if [[ "$VERBOSE" -eq 0 ]]; then
  echo -e "${YELLOW}${BOLD}Note:${RESET} You can run this script with the ${CYAN}--verbose${RESET} flag to see more detailed information about individual tests."
fi

exit $exitcode