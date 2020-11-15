#!/bin/sh

for i in $(seq 30)
do
	sleep 3
	wget -Y on -O /dev/null http://google.com && exit 0
done

sleep 999999

exit 1
