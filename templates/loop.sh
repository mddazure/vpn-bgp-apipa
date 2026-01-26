#!/bin/bash
for (( ; ; ))
do
   curl 10.10.2.5
   sleep 1
   curl 10.10.2.6
   sleep 1
done