#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

# Define colors for output
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
BOLD='\033[1m'
RESET='\033[0m'

# Define an array of programs to compile
programs=("random_ids" "id_query_naive" "id_query_binsort" "id_query_indexed")

# Compile necessary programs by iterating over the array
echo -e "${BLUE}Compiling programs...${RESET}"
for program in "${programs[@]}"; do
  make "$program"
done

# Create test_files directory
echo -e "${BLUE}Generating a test_files directory...${RESET}"
mkdir -p test_files
rm -f test_files/*

# Path to TSV FILE
tsv_file="20000records.tsv"

# Generate random IDs using random ID generator
echo -e "${BLUE}Generating random IDs...${RESET}"
./random_ids "${tsv_file}" | head -n 5 > test_files/random_ids.input

# Now use the generated random IDs to test queries
echo -e "${BLUE}Running query tests with random IDs...${RESET}"
exitcode=0

# List of query programs to test (excluding id_query_naive, since it runs separately)
queries=("id_query_binsort" "id_query_indexed")

while read -r random_id; do
  # Print a message before running all programs with the current random ID
  echo -e "${YELLOW}${BOLD}>>> Running all programs with random ID ${random_id}...${RESET}"

  # Run id_query_naive first to generate expected output
  echo -e "${YELLOW}>>> Generating expected output using id_query_naive with random ID ${random_id}...${RESET}"
  echo "${random_id}" | ./id_query_naive "${tsv_file}" | sed '/Reading records/d; /Building index/d; /Query time/d; /Total query runtime/d' > "test_files/${random_id}.id_query_naive.expected"

  # Now run the other query programs and compare their outputs to the expected output from id_query_naive
  for query_program in "${queries[@]}"; do
    echo -e "${YELLOW}>>> Running ${query_program} with random ID ${random_id}...${RESET}"

    # Give current random ID to the query program, and save the output in test_files without the query times and build times for comparison
    echo "${random_id}" | ./${query_program} "${tsv_file}" | sed '/Reading records/d; /Building index/d; /Query time/d; /Total query runtime/d' > "test_files/${random_id}.${query_program}.actual"

    # Compare the output of current query program with the expected output from id_query_naive
    if ! diff -u "test_files/${random_id}.id_query_naive.expected" "test_files/${random_id}.${query_program}.actual"; then
      echo -e "${RED}${BOLD}>>> Test failed for ${query_program} with random ID ${random_id} :-(${RESET}"
      exitcode=1
    else
      echo -e "${GREEN}${BOLD}>>> Test passed for ${query_program} with random ID ${random_id} :-)${RESET}"
    fi

  done

  # newline to separate the results of each ID
  echo -e "${BLUE}${BOLD}>>> Finished running all programs with random ID ${random_id}${RESET}\n"

done < test_files/random_ids.input

exit $exitcode
