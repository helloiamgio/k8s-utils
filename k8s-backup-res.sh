#!/bin/bash

cd "/home/k8s/kubebackup"

function usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --type, -t          Type of resource: service|deployment|configmaps|ingress|secret"
    echo "  --namespace, -n     Namespace"
    echo "  --output, -o        Output directory"
    exit 1
}

backup_dir="k8s-backup-$(date +'%Y%m%d%H%M%S')"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type|-t)
            resource_type="$2"
            shift 2
        ;;
        --namespace|-n)
            namespace="$2"
            shift 2
        ;;
        --output|-o)
            backup_dir="$2"
            shift 2
        ;;
        *)
            echo "Invalid option: $1"
            usage
        ;;
    esac
done

mkdir -p "$backup_dir"

function backup_resources() {
    local resource_type="$1"
    local namespace="$2"
    local resource_plural=""
    
    case "$resource_type" in
        service)
            resource_plural="services"
        ;;
        deployment)
            resource_plural="deployments"
        ;;
        configmaps)
            resource_plural="configmaps"
        ;;
        ingress)
            resource_plural="ingresses"
        ;;
        secret)
            resource_plural="secrets"
        ;;
        *)
            echo "Unsupported resource type: $resource_type"
            exit 1
        ;;
    esac
    
    local namespace_backup_dir="$backup_dir/$namespace"
    mkdir -p "$namespace_backup_dir"
    
    kubectl get "$resource_plural" -n "$namespace" -o yaml > "$namespace_backup_dir/${resource_type}s.yaml"
    
    echo "Backup for $resource_type in namespace $namespace completed"
}

if [[ -n "$namespace" ]]; then
    user_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
    
    if ! echo "$user_namespaces" | grep -q "$namespace"; then
        echo "Namespace $namespace does not exist or is not a user namespace"
        exit 1
    fi
    
    if [[ -n "$resource_type" ]]; then
        backup_resources "$resource_type" "$namespace"
    else
        backup_resources "service" "$namespace"
        backup_resources "deployment" "$namespace"
        backup_resources "configmaps" "$namespace"
        backup_resources "ingress" "$namespace"
        backup_resources "secret" "$namespace"
    fi
    
    echo "Backup process for namespace $namespace completed"
else
    user_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
    
    for namespace in $user_namespaces; do
        if [[ -n "$resource_type" ]]; then
            backup_resources "$resource_type" "$namespace"
        else
            backup_resources "service" "$namespace"
            backup_resources "deployment" "$namespace"
            backup_resources "configmaps" "$namespace"
            backup_resources "ingress" "$namespace"
            backup_resources "secret" "$namespace"
        fi
    done
    
    echo "Backup process completed"
fi
