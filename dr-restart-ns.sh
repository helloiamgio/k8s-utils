#!/bin/bash
clear
# Get all namespaces
namespaces=$(kubectl get namespaces --no-headers | awk '{print $1}' | egrep -v 'kube|istio|default|node|monitoring')

echo "### Available namespaces: ###"
echo  $namespaces
echo "Enter the namespace to scale down and restore deployments:"
read -r namespace
kubens $namespace

# Get all deployments in the specified namespace
deployments=$(kubectl get deployments -n $namespace -o jsonpath='{.items[*].metadata.name}')

# Create or truncate replicas.txt file
if [ -f /var/tmp/replicas-$namespace.txt ]; then
  truncate -s 0 /var/tmp/replicas-$namespace.txt
else
  touch /var/tmp/replicas-$namespace.txt
fi


# Store the original replicas of all deployments
for deployment in $deployments; do
  replicas=$(kubectl get deployment $deployment -n $namespace -o jsonpath='{.spec.replicas}')
  originalReplicas[$deployment]=$replicas
  echo "kubectl scale --replicas=$replicas deployment $deployment -n $namespace" >> /var/tmp/replicas-$namespace.txt
  echo "kubectl wait --for=condition=ready pod -l app=$deployment --timeout=900s" >> /var/tmp/replicas-$namespace.txt
done

if [ $namespace = "app-hub" ] || [ $namespace = "app-hub-fix" ] 
then
  sed -i -n '/cache-adapter/{x;p;x;};1h;1!{x;p;}' /var/tmp/replicas-$namespace.txt
fi

if [ $namespace = "wso2-upgrade" ] 
then
cat << EOF > /var/tmp/replicas-$namespace.txt
kubectl scale --replicas=1 deployment 3-2-0-wso2apim-devportal -n $namespace
kubectl wait --for=condition=ready pod -l app=3-2-0-wso2apim-devportal --timeout=900s
kubectl scale --replicas=4 deployment 3-2-0-wso2apim-is -n $namespace
kubectl wait --for=condition=ready pod -l app=3-2-0-wso2apim-is --timeout=900s
kubectl scale --replicas=8 deployment 3-2-0-wso2apim-gw-worker -n $namespace
kubectl wait --for=condition=ready pod -l app=3-2-0-wso2apim-gw-worker --timeout=900s
EOF
fi
#read -p "STOP" stop
# Scale all deployments to 0 replicas
for deployment in $deployments; do
  kubectl scale deployment $deployment --replicas=0 -n $namespace
done

# Wait for all pods to terminate
podsTerminated=false
while [ "$podsTerminated" = false ]; do
  runningPods=$(kubectl get pods -n $namespace -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}')
  if [ -z "$runningPods" ]; then
    podsTerminated=true
  else
    sleep 5
  fi
done

# Prompt user for confirmation before scaling deployments back to their original replicas
while true; do
  echo "Do you want to restore the original replicas? (y/n)"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY]|[sS])$ ]]; then
    while read -r line; do
      eval $line
    done < /var/tmp/replicas-$namespace.txt
    break
  elif [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "Aborted"
    break
  else
    echo "Invalid input. Please enter 'y' or 'n'"
  fi
done
echo "### ALL NODE ###"
kubectl get pod -n $namespace
