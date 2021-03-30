#!/bin/bash

host=$0
host="k8s.local"

v1=0
v2=0

while sleep 0.3;
do
    response=$(curl -s $host)

    if [[ $response == *v1* ]];then
        let v1+=1
    elif [[ $response == *v2* ]];then
        let v2+=1
    fi

    echo "v1: $v1 v2: $v2 - $response"
done