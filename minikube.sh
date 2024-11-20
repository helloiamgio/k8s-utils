#!/bin/bash

clear

echo "****************************************"
echo "******           MINIKUBE         ******"
echo "****************************************"

# Verifica i permessi dell'utente
if [ "$(id -u)" == "0" ]; then
   echo "Questo script non deve essere eseguito come root. Utilizzare un utente con i permessi sudo." 1>&2
   exit 1
fi

# Controllo se Docker è installato
if ! command -v docker &> /dev/null; then
    echo "Docker non è installato. Installazione in corso..."
	sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
	sudo usermod -aG docker $USER && newgrp docker
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Controllo se kubectl è installato
if ! command -v kubectl &> /dev/null; then
    echo "kubectl non è installato. Installazione in corso..."
    sudo yum install -y kubectl
fi

# Controllo se kubectx e kubens sono installati
if ! command -v kubectx &> /dev/null || ! command -v kubens &> /dev/null; then
    echo "kubectx e kubens non sono installati. Installazione in corso..."
    git clone https://github.com/ahmetb/kubectx.git ~/.kubectx
    sudo ln -s ~/.kubectx/kubectx /usr/local/bin/kubectx
    sudo ln -s ~/.kubectx/kubens /usr/local/bin/kubens
fi

# Controllo se helm è installato
if ! command -v helm &> /dev/null; then
    echo "helm non è installato. Installazione in corso..."
    sudo yum install -y helm
fi

# Controllo se Git è installato
if ! command -v git &> /dev/null; then
    echo "Git non è installato. Installazione in corso..."
    sudo yum install -y git
fi

# Installa Minikube
echo "Minikube non è installato. Installazione in corso..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Richiedo il nome del cluster
read -p "Inserisci il nome del cluster: " cluster_name

# Avvio Minikube con il driver Docker
minikube start --driver=docker --addons=dashboard,ingress,dns,metrics-server,cert-manager --cni=flannel --vm-driver=none --cpu=4 --memory=6g -p $cluster_name

# Stampo le informazioni sul cluster
kubectl cluster-info

# Richiede all'utente quale addon installare
addons=("dashboard" "registry" "ingress" "metrics-server" "cert-mamanger")
selected_addons=()
echo "Seleziona gli addon da installare (premere INVIO per saltare l'installazione):"
for addon in "${addons[@]}"
do
    read -p "Vuoi installare $addon? [s/n] " choice
    case "$choice" in 
        s|S ) selected_addons+=($addon);;
        n|N ) ;;
        * ) ;;
    esac
done

for addon in "${selected_addons[@]}"
do
    case "$addon" in
        dashboard ) minikube addons enable dashboard;;
        registry ) minikube addons enable registry;;
        ingress ) minikube addons enable ingress;;
        metrics-server ) minikube addons enable metrics-server;;
        cert-manager ) minikube addons enable cert-manager;;
        * ) ;;
    esac
done

# Stampa lo stato di Minikube e dei componenti
minikube status
kubectl version --short
helm version --short
kubectx --current

# Creazione ingress per esporre la dashboard
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: dashboard.acn
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard
                port:
                  name: https
EOF
echo "Dashboard URL: https://dashboard.acn"

# Creazione del servizio account di tipo admin
kubectl -n kube-system create sa admin
kubectl create clusterrolebinding admin --clusterrole cluster-admin --serviceaccount=kube-system:admin
echo "Token di accesso: $(kubectl -n kubernetes-dashboard create token admin-user)"

# Aggiungi l'IP per l'host dashboard.acn in /etc/hosts
if [ $(grep dashboard.acn /etc/hosts | echo $?) -ne 0 ]
then
  echo "$(minikube ip)  dashboard.acn" | sudo tee -a /etc/hosts > /dev/null
else 
  echo "Indirizzo IP della dashboard già presente"   
fi  
			