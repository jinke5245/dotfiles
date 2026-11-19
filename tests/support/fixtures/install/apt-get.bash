#!/usr/bin/env bash

# Available for discovery; the sudo fixture handles package installation.
printf 'Unexpected direct apt-get invocation in an offline installer test.\n' >&2
exit 90
