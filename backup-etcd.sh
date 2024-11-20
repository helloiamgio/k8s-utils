#!/bin/bash

# Funzione per ottenere l'endpoint di etcd da un cluster Kubernetes
get_etcd_endpoint() {
    ETCD_ENDPOINT=$(kubectl cluster-info | grep -o 'https://[^ ]*' | sed 's/https:\/\/\([^:]*\):[^ ]*/\1/' | head -n 1)
    if [[ -z "$ETCD_ENDPOINT" ]]; then
        echo "Impossibile ottenere l'endpoint di etcd dal cluster Kubernetes. Assicurati che il cluster sia configurato correttamente e che etcd sia in esecuzione."
        exit 1
    fi
    ETCD_ENDPOINT+=":2379"  # Aggiungi la porta di default di etcd (2379)
}

# Funzione per installare etcdctl se non è già presente
install_etcdctl() {
    if ! command -v etcdctl &>/dev/null; then
        echo "Installazione di etcdctl..."
        ETCD_VER=$(curl -sL https://github.com/etcd-io/etcd/releases/latest | grep -oP '(?<=tag\/v)[0-9]+\.[0-9]+\.[0-9]+')
        DOWNLOAD_URL="https://github.com/etcd-io/etcd/releases/download/v${ETCD_VER}/etcd-v${ETCD_VER}-linux-amd64.tar.gz"
        curl -L "$DOWNLOAD_URL" -o /tmp/etcd.tar.gz
        tar xzf /tmp/etcd.tar.gz -C /tmp/
        sudo mv /tmp/etcd-v${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/etcdctl
        rm -rf /tmp/etcd-v${ETCD_VER}-linux-amd64 /tmp/etcd.tar.gz
        echo "etcdctl installato con successo."
    else
        echo "etcdctl è già installato."
    fi
}

perform_backup() {
    get_etcd_endpoint
    BACKUP_DIR="/var/tmp"
    BACKUP_FILE="$BACKUP_DIR/etcd-snapshot-$(date +%Y%m%d%H%M%S).db"
    echo "Eseguendo il backup di etcd in corso..."
    echo "Questo potrebbe richiedere del tempo, dipendendo dalle dimensioni del database di etcd."
    etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --endpoints="$ETCD_ENDPOINT" snapshot save "$BACKUP_FILE"
    echo "Backup completato con successo."
}

perform_restore() {
    echo "Backup disponibili in /var/tmp:"
    ls -p /var/tmp | grep '\.db$'

    echo "Inserisci il nome del file di backup di etcd dalla lista sopra:"
    read -r BACKUP_FILE
    BACKUP_PATH="/var/tmp/$BACKUP_FILE"
    if [ ! -f "$BACKUP_PATH" ]; then
        echo "Il file di backup specificato non esiste."
        return
    fi

    get_etcd_endpoint
    RESTORE_DATA_DIR="/var/lib/etcd-from-backup"
    echo "Eseguendo il ripristino di etcd in corso..."
    etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --endpoints="$ETCD_ENDPOINT" snapshot restore "$BACKUP_PATH" \
      --data-dir="$RESTORE_DATA_DIR"
    echo "Ripristino completato con successo."
}

verify_backup() {
    echo "Backup disponibili in /var/tmp:"
    ls -p /var/tmp | grep '\.db$'

    echo "Inserisci il nome del file di backup di etcd dalla lista sopra:"
    read -r BACKUP_FILE
    BACKUP_PATH="/var/tmp/$BACKUP_FILE"
    if [ ! -f "$BACKUP_PATH" ]; then
        echo "Il file di backup specificato non esiste."
        return
    fi

    echo "Verifica del backup in corso..."
    etcdctl --write-out=table snapshot status "$BACKUP_PATH"
    if [ $? -eq 0 ]; then
        echo "Verifica del backup completata. Il backup è corretto."
    else
        echo "Verifica del backup completata. Il backup potrebbe non essere corretto."
    fi
}

etcd_members_and_endpoint_status() {
    get_etcd_endpoint
    echo "Stato dei membri di etcd:"
    etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --endpoints="$ETCD_ENDPOINT" member list 

    echo "Stato dell'endpoint di etcd:"
    etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --endpoints="$ETCD_ENDPOINT" endpoint status --write-out table
	
	echo "Stato di salute dell'endpoint di etcd:"
    etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key  --endpoints="$ETCD_ENDPOINT" endpoint health
}

# Pulisci lo schermo all'avvio dello script
clear

# Installa etcdctl se non è già presente
install_etcdctl

# Menu interattivo
echo "Seleziona l'operazione desiderata:"
echo "1) Esegui il backup di etcd"
echo "2) Esegui il ripristino di etcd"
echo "3) Verifica la correttezza del backup"
echo "4) Verifica lo stato dei membri di etcd in formato tabellare"
read -r choice

case $choice in
    1)
        perform_backup
        ;;
    2)
        perform_restore
        ;;
    3)
        verify_backup
        ;;
    4)
        etcd_members_and_endpoint_status
        ;;
    *)
        echo "Scelta non valida. Uscita."
        ;;
esac