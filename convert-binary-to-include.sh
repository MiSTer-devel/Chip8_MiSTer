#!/bin/sh
od -A n -v -t x1 -w1 "$1" | sed -e 's/^[ \t]*//'