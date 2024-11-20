#!/usr/bin/env bash

# MIT License

# Copyright (c) 2022 Navratan Gupta

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
clear
export KUBECONFIG=/home/$SUDO_USER/.kube/config

function exitWithMsg()
{
    # $1 is error code
    # $2 is error message
    echo "Error $1: $2"
    exit $1
}

function exitAfterCleanup()
{
    echo "Error $1: $2"
    clean $1
}

function clean()
{
    # $1 is error code
    echo
    echo "Cleaning up, before exiting..."
    if [[ "$(which k3d)" != "" ]]; then
        sleep 2
        k3d cluster delete $clusterName
    fi
    if [ -d /home/$SUDO_USER/.kube ]; then
        sudo chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.kube
    fi
    exit $1
}

trap 'clean $?' ERR SIGINT

if [ $EUID -ne 0 ]; then
    exitWithMsg 1 "Run this as root or with sudo privilege."
fi

basedir=$(cd $(dirname $0) && pwd)

k3dVersion="v5.0.1"
kubectlVersion="v1.22.2"
metallbVersion="v0.10.3"
ingressControllerVersion="v1.0.4"

k3dclusterinfo="/home/$SUDO_USER/k3dclusters.info"

totalMem=$(free --giga | grep -w Mem | tr -s " "  | cut -d " " -f 2)

usedMem=$(free --giga | grep -w Mem | tr -s " "  | cut -d " " -f 3)

availableMem=$(expr $totalMem - $usedMem)

echo "Available Memory: "$availableMem"Gi"

distroId=$(grep -w DISTRIB_ID /etc/*-release | cut -d "=" -f 2)
distroVersion=$(grep -w DISTRIB_RELEASE /etc/*-release | cut -d "=" -f 2)

if [ $availableMem -lt 2 ]; then
    exitWithMsg 1 "Atleast 2Gi of free memory required."
fi

if [ -d /home/$SUDO_USER/.kube ]; then
    sudo chown -R root:root /home/$SUDO_USER/.kube
fi

echo
read -p "Enter cluster name: " clusterName
read -p "Enter number of worker nodes (0 to 3) (1Gi memory per node is required): " nodeCount
read -p "Enter kubernetes api port (recommended: 5000-5500): " apiPort
echo

if [[ $apiPort != ?(-)+([0-9]) ]]; then
    exitWithMsg 1 "$apiPort is not a port. Port must be a number"
fi

if [[ $nodeCount != ?(-)+([0-9]) ]]; then
    exitWithMsg 1 "$nodeCount is not a number. Number of worker node must be a number"
fi

echo
echo "Updating packages."
sudo yum update -y
echo

echo "Checking docker..."
if [[ "$(which docker)" == "" ]]; then
    echo "Docker not found. Installing."
    yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-enginer-buildx-plugin docker-compose-plugin

    yum install -y yum-utils

    sudo dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo

    sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo chmod 666 /var/run/docker.sock
    sudo systemctl enable docker --now
    echo "Docker installed."
fi

echo "Checking K3d..."
if [[ "$(which k3d)" == "" ]]; then
    echo "K3d not found. Installing."
    curl -LO https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=$k3dVersion bash
    echo "K3d installed."
fi

echo "Checking kubectl..."
if [[ "$(which kubectl)" == "" ]]; then
    echo "kubectl not found. Installing."
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    kubectl version --client
    echo "kubectl installed."
fi
sleep 2

echo
echo "Checking if cluster already exists."
hasCluster=$(k3d cluster list | grep -w $clusterName | cut -d " " -f 1)
if [ "$hasCluster" == "$clusterName" ]; then
    exitWithMsg 100 "Cluster with name $clusterName already exist."
fi

echo
echo "Creating cluster"
echo
k3d cluster create $clusterName --api-port $apiPort --agents $nodeCount --k3s-arg "--disable=traefik@server:0" --k3s-arg "--disable=servicelb@server:0" --no-lb --wait --timeout 15m
echo "Cluster $clusterName created."

echo "Checking kubectl..."
if [[ "$(which kubectl)" == "" ]]; then
    echo "kubectl not found. Installing."
    curl -LO https://dl.k8s.io/release/$kubectlVersion/bin/linux/amd64/kubectl
    chmod +x kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    echo "Kubectl installed."
fi

sleep 2

kubectl cluster-info

if [ $? -ne 0 ]; then
    exitAfterCleanup 1 "Failed to spinup cluster."
fi

echo
echo "Deploying MetalLB loadbalancer."
echo
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
echo "Waiting for MetalLB to be ready. It may take 10 seconds or more."
sleep 60
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

kubectl label namespace metallb-system pod-security.kubernetes.io/enforce=privileged
kubectl label namespace metallb-system pod-security.kubernetes.io/audit=privileged
kubectl label namespace metallb-system pod-security.kubernetes.io/warn=privileged

echo "Installing json parser."
sudo yum install jq -y
cidr_block=$(docker network inspect k3d-$clusterName | jq '.[0].IPAM.Config[0].Subnet' | tr -d '"')
base_addr=${cidr_block%???}
first_addr=$(echo $base_addr | awk -F'.' '{print $1,$2,$3,240}' OFS='.')
range=$first_addr/29

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: cluster-k3d
  namespace: metallb-system
spec:
  addresses:
  - $range 
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF

echo
echo "Deploying Nginx Ingress Controller."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-$ingressControllerVersion/deploy/static/provider/aws/deploy.yaml
echo "Waiting for Nginx Ingress controller to be ready. It may take 10 seconds or more."
kubectl wait --timeout=180s  --for=condition=ready pod -l app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx -n ingress-nginx

sleep 5

echo "Getting Loadbalancer IP"
externalIP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LoadBalancer IP: $externalIP"

echo "Deploying dashboard + Cert Manager"
kubectl create ns kubernetes-dashboard
GITHUB_URL=https://github.com/kubernetes/dashboard/releases
VERSION_KUBE_DASHBOARD=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/${VERSION_KUBE_DASHBOARD}/aio/deploy/recommended.yaml -n kubernetes-dashboard

GITHUB_URL=https://github.com/jetstack/cert-manager/releases
VERSION_CERT_MANAGER=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/${VERSION_CERT_MANAGER}/cert-manager.yaml 
sleep 60

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin-user
    namespace: kubernetes-dashboard
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: A…M
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: clusterissuer-le
  namespace: kubernetes-dashboard
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: middlewareadmins.it@test.acn
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
         ingress:
           class: nginx
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  secretName: certificate-prod-dashboard
  dnsNames:
    - dashboard.test.acn
  issuerRef:
    name: clusterissuer-le
    kind: ClusterIssuer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/issuer: clusterissuer-le
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - dashboard.test.acn
      secretName: certificate-prod-dashboard
  rules:
    - host: dashboard.test.acn
      http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              service:
                name: kubernetes-dashboard
                port:
                  number: 443
EOF
kubectl -n kubernetes-dashboard create token admin-user

sudo chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.kube

echo "Setting KUBECONFIG"
k3d kubeconfig write $clusterName
sleep 3
echo "Lanciare"G
echo "export KUBECONFIG=$(k3d kubeconfig write $clusterName)"
sleep 3
echo $KUBECONFIG

function clusterInfo()
{
    echo
    echo
    echo "---------------------------------------------------------------------------"
    echo "---------------------------------------------------------------------------"
    echo "Cluster name: $clusterName"
    echo "K8s server: https://0.0.0.0:$apiPort"
    echo "Ingress Load Balancer: $externalIP"
    echo "Open sample app in browser: http://$externalIP/sampleapp"
    echo "To stop this cluster (If running), run: k3d cluster stop $clusterName"
    echo "To start this cluster (If stopped), run: k3d cluster start $clusterName"
    echo "To delete this cluster, run: k3d cluster delete $clusterName"
    echo "To list all clusters, run: k3d cluster list"
    echo "To switch to another cluster (In case of multiple clusters), run: kubectl config use-context k3d-<CLUSTERNAME>"
    echo "---------------------------------------------------------------------------"
    echo "---------------------------------------------------------------------------"
    echo
}
clusterInfo | tee -a "$k3dclusterinfo"
chown $SUDO_USER:$SUDO_USER "$k3dclusterinfo"
chmod 400 "$k3dclusterinfo"
echo "Find cluster info in "$k3dclusterinfo" file."
echo "Lanciare"
echo "export KUBECONFIG=$(k3d kubeconfig write $clusterName)"
sleep 3
echo $KUBECONFIG
echo "|-- THANK YOU --|"
echo
