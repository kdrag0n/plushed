#!/usr/bin/env bash

i=1
for f in *
do
    mv "$f" "$i"
    i=$((i+1))
done
