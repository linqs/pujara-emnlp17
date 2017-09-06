#!/bin/bash

readonly DATA_URL='https://linqs-data.soe.ucsc.edu/public/pujara-emnlp17/data-full.tar.gz'
readonly DATA_FILE='data-full.tar.gz'
readonly DATA_DIR='data'

FETCH_COMMAND=''

function err() {
   echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

# Check for:
#  - wget or curl (final choice to be set in FETCH_COMMAND)
#  - tar
function check_requirements() {
   local hasWget

   type wget > /dev/null 2> /dev/null
   hasWget=$?

   type curl > /dev/null 2> /dev/null
   if [[ "$?" -eq 0 ]]; then
      FETCH_COMMAND="curl -o"
   elif [[ "${hasWget}" -eq 0 ]]; then
      FETCH_COMMAND="wget -O"
   else
      err 'wget or curl required to download dataset'
      exit 10
   fi

   type tar > /dev/null 2> /dev/null
   if [[ "$?" -ne 0 ]]; then
      err 'tar required to extract dataset'
      exit 11
   fi
}

function fetch_data() {
   if [[ -e "${DATA_FILE}" ]]; then
      echo "Data file found cached, skipping download."
      return
   fi

   echo "Downloading the dataset with command: $FETCH_COMMAND"
   $FETCH_COMMAND "${DATA_FILE}" "${DATA_URL}"
   if [[ "$?" -ne 0 ]]; then
      err 'Failed to download dataset'
      exit 20
   fi
}

function extract_data() {
   if [[ -e "${DATA_DIR}" ]]; then
      echo "Extracted data found cached, skipping extract."
      return
   fi

   echo 'Extracting the dataset'
   tar -xvzf "${DATA_FILE}"
   if [[ "$?" -ne 0 ]]; then
      err 'Failed to extract dataset'
      exit 30
   fi
}

function main() {
   check_requirements
   fetch_data
   extract_data
}

main "$@"
