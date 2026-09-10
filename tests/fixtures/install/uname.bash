#!/usr/bin/env bash

[ "${1:--s}" = -s ] || exit 90
cat "$HOME/.install-test/platform"
