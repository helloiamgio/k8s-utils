#!/bin/bash

# Funzione per verificare se un comando è installato
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verifica se kubens è già installato
if command_exists kubens; then
    echo "kubens è già installato."
else
    echo "kubens non è installato. Installazione in corso..."
    # Scarica e installa kubens
    wget https://github.com/ahmetb/kubectx/raw/master/kubens -O /usr/local/bin/kubens
    chmod +x /usr/local/bin/kubens
    echo "kubens è stato installato."
fi

# Verifica se kubectx è già installato
if command_exists kubectx; then
    echo "kubectx è già installato."
else
    echo "kubectx non è installato. Installazione in corso..."
    # Scarica e installa kubectx
    wget https://github.com/ahmetb/kubectx/raw/master/kubectx -O /usr/local/bin/kubectx
    chmod +x /usr/local/bin/kubectx
    echo "kubectx è stato installato."
fi
