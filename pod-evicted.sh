#!/bin/bash

read -p "Inserisci il nome del namespace: " namespace

# Verifica del motivo dell'eviction per i pod evicted nel namespace specificato
kubectl get pods --namespace=$namespace --field-selector=status.phase=Failed -o json | jq -r '.items[] | .metadata.name + ": " + .status.conditions[] | select(.reason == "Evicted") | .message'

# Cancellazione dei pod evicted nel namespace specificato
kubectl delete pods --all --namespace=$namespace --field-selector=status.phase=Failed
