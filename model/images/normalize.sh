#!/usr/bin/env bash

for f in */*
do
    echo "$f"
    mv "$f" cur.tmp
    new_fn="$f.jpg"
    convert cur.tmp -resize '224x224!' -quality 95 "$new_fn"
done

rm -f cur.tmp
