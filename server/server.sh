#!/bin/sh

while read line; do
    echo "$line" | redis-cli -h localhost -p 6379 PUBLISH mychannel
done
