#!/bin/bash
now=$(date +"%d-%m-%Y_%H-%M-%S")
logfile=$PWD/restore-k8s-$now.log
echo "LOG FILE: $logfile" | tee -a $logfile
declare -a K8S=( "cm")
for K8S_OBJ in "${K8S[@]}"; do
    echo "--START creating $K8S_OBJ" | tee -a $logfile
    cd $K8S_OBJ;
    for cm in $(ls); do
        for file in $(ls $cm); do
        /usr/local/bin/kubectl create cm $cm --from-file=$cm/$file
        echo "/usr/local/bin/kubectl create cm $cm --from-file=$cm/$file" | tee -a $logfile;
        done
    done
    cd ..;
done
#declare -a K8S=( "vs" "pvc" "pv" "service" "deployment")
declare -a K8S=( "pvc" "pv" "deployment")
for K8S_OBJ in "${K8S[@]}"; do
    echo "--START creating $K8S_OBJ" | tee -a $logfile
    cd $K8S_OBJ;
    for dir in $(ls); do
        /usr/local/bin/kubectl apply -f "$dir/$dir.yaml"
        echo "/usr/local/bin/kubectl apply -f $dir/$dir.yaml" | tee -a $logfile;
    done
    cd ..;
done
echo "--END" | tee -a $logfile