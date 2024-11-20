#!/bin/bash

# Funzione per stampare il valore delle label dei pod
stampare_valore_label_pod() {
    namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
    kubectl get pods --namespace=$namespace -o=jsonpath='{range .items[*]}{"Namespace: "}{.metadata.namespace}{"\nPod Name: "}{.metadata.name}{"\nLabel: "}{.metadata.labels}{"\n\n"}'
}

# Funzione per eseguire una ricerca con una label specifica
ricerca_label_specifica() {
    read -p "Inserisci la label nel formato label:valore: " label
    label_key=$(echo $label | cut -d ":" -f 1)
    label_value=$(echo $label | cut -d ":" -f 2)
    kubectl get pods --namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}') -l "$label_key"="$label_value" -o wide
}

# Funzione per visualizzare i nodeselector dei deployment
visualizzare_nodeselector_deployment() {
    kubectl get deployments --namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}') -o=jsonpath='{range .items[*]}{"\n\nDeployment Name: "}{.metadata.name}{"\nNamespace: "}{.metadata.namespace}{"\nNodeSelector: "}{.spec.template.spec.nodeSelector}{"\n"}'
}

# Loop principale del menu
while true; do
    echo "Seleziona un'opzione:"
    echo "1) Stampare il valore delle label dei pod"
    echo "2) Eseguire una ricerca con una label specifica"
    echo "3) Visualizzare i nodeselector dei deployment"
    echo "4) Esci"

    read -p "Scelta: " choice
    case $choice in
        1) stampare_valore_label_pod;;
        2) ricerca_label_specifica;;
        3) visualizzare_nodeselector_deployment;;
        4) echo "Uscita..."; exit;;
        *) echo "Scelta non valida";;
    esac
done
