#!/bin/sh -l

echo "max-message-length $1"
time=$(date)
echo "time=$time" >> $GITHUB_OUTPUT

