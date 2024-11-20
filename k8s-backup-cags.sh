#!/bin/bash
now=$(date +"%d-%m-%Y_%H-%M-%S")
mkdir backup-$now && cd backup-$now;
logfile=$PWD/backup-$now.log
echo "LOG FILE: $logfile" | tee $logfile
BACKUP_HOME=$PWD
    mkdir $BACKUP_HOME/cm && cd $BACKUP_HOME/cm
    echo "--START backing up configmaps" | tee $logfile
    for cm in $(/usr/local/bin/kubectl get cm | grep 3-2-0-wso2apim | awk '{print $1}'); do
        mkdir $cm
        /usr/local/bin/kubectl describe cm $cm >"$cm/$cm"
    done
    for dir in $(ls); do
        file="$dir/$dir"
        subfileName=$dir/tmpFile
        while IFS= read -r line; do
            if [ "$line" == "----" ]; then
                sed -i '$ d' $subfileName
                subfileName=$dir/$(echo $previousLine | tr -d ':')
                echo "Storing cm $subfileName" | tee $logfile
            elif [ "$(echo $line | awk '{print $1}')" == "Events:" ]; then
                break
            else
                echo "$line" >>"$subfileName"
            fi
            previousLine=$line
        done <"$file"
        rm $dir/$dir $dir/tmpFile
    done
    declare -a K8S=( "vs" "pvc" "pv" "service" "deployment")
    for K8S_OBJ in "${K8S[@]}"; do
        echo "--START backing up $K8S_OBJ" | tee $logfile
        mkdir $BACKUP_HOME/$K8S_OBJ && cd $BACKUP_HOME/$K8S_OBJ;
        for vs in $(/usr/local/bin/kubectl get $K8S_OBJ | awk '{print $1}'); do
        mkdir $vs;
        /usr/local/bin/kubectl get $K8S_OBJ $vs -o yaml >"$vs/$vs.yaml" && echo "Getting $vs for backup" | tee $logfile;
        done
        cd ..;
    done