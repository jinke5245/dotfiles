#!/bin/bash

set -eu

# The installation fixture only needs the GUID from the repository's formatted JSON.
if [[ "$#" -ne 6 || "$1" != -extract || "$2" != Profiles.0.Guid || "$3" != raw || "$4" != -o || "$5" != - ]]; then
  printf 'Unexpected plutil invocation: %s\n' "$*" >&2
  exit 90
fi

awk -F '"' '/"Guid":/ { print $4; exit }' "$6"
