#!/bin/bash

printf 'unexpected-runtime:%s\n' "${0##*/}" >> "$ZSH_TEST_TRACE"
printf 'Unexpected runtime command during shell startup: %s %s\n' "$0" "$*" >&2
exit 90
