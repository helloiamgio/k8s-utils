#!/bin/bash

# Ottieni i nomi di tutti i deployment nel cluster
deployment_names=$(kubectl get deployments -o=jsonpath='{.items[*].metadata.name}')

# Per ogni nome di deployment, stampa le immagini dei relativi container
for deployment_name in $deployment_names; do
    container_names=$(kubectl get deployment $deployment_name -o=jsonpath='{.spec.template.spec.containers[*].name}')
    for container_name in $container_names; do
        image=$(kubectl get deployment $deployment_name -o=jsonpath="{.spec.template.spec.containers[?(@.name=='$container_name')].image}")
        echo "Deployment: $deployment_name - Container: $container_name - Immagine: $image"
    done
done