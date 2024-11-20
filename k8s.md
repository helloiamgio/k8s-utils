# **k8s super-cheatsheet**

## KUBECTL

 - **Install (https://kubernetes.io/docs/tasks/tools/)**
	```bash
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	chmod +x kubectl
	mkdir -p ~/.local/bin
	mv ./kubectl ~/.local/bin/kubectl
	# and then append (or prepend) ~/.local/bin to $PATH
	kubectl version --client
	```
 - **Autocomplete**

	```bash
	source <(kubectl completion bash) # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
	echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.
	alias k=kubectl
	complete -o default -F __start_kubectl k
	```
	


## **UTILS**

 - **krew**
	https://krew.sigs.k8s.io/docs/user-guide/setup/install/
	https://krew.sigs.k8s.io/plugins/

 - **kubectx/kubens**
https://github.com/ahmetb/kubectx
	



## **NAMESPACES & CONTEXT**

 - **use multiple kubeconfig files at the same time and view merged config**

	```bash
	KUBECONFIG=~/.kube/config:~/.kube/kubconfig2 	
	kubectl config view
	```        

 - **get the password for the e2e user + switch context**

	```bash
	kubectl config view -o jsonpath='{.users[?(@.name == "e2e")].user.password}'
	kubectl config view -o jsonpath='{.users[].name}'    # display the first user
	kubectl config view -o jsonpath='{.users[*].name}'   # get a list of users
	kubectl config get-contexts                          # display list of contexts
	kubectl config current-context                       # display the current-context
	kubectl config use-context my-cluster-name           # set the default context to my-cluster-name
	kubectl config set-cluster my-cluster-name           # set a cluster entry in the kubeconfig
	```
	

 - **configure the URL to a proxy server to use for requests made by this client in the kubeconfig**

	```bash
	kubectl config set-cluster my-cluster-name --proxy-url=my-proxy-url`
    ```
	
 - **add a new user to your kubeconf that supports basic auth**

	```bash
	kubectl config set-credentials kubeuser/foo.kubernetes.com --username=kubeuser --password=kubepassword`
	```	
	 
 - **permanently save the namespace for all subsequent kubectl commands in
   that context.**  
 
	```bash
	kubectl config set-context --current --namespace=ggckad-s2`
	```
	
 - **set a context utilizing a specific username and namespace.**

	```bash
    kubectl config set-context gce --user=cluster-admin --namespace=foo \
  && kubectl config use-context gce
	kubectl config unset users.foo                       # delete user foo
	```

 - **short alias to set/show context/namespace (only works for bash and
   bash-compatible shells, current context to be set before using kn to
   set namespace)**

	```bash
    alias kx='f() { [ "$1" ] && kubectl config use-context $1 || kubectl config current-context ; } ; f'
    alias kn='f() { [ "$1" ] && kubectl config set-context --current --namespace $1 || kubectl config view --minify | grep namespace | cut -d" " -f6 ; } ; f'
	```

 - **switch namespace senza kubens**
  
	```bash
	kubectl config set-context $(kubectl config current-context) --namespace=<namespace>
	kubectl config view | grep namespace
	kubectl get pods
	```
  
- **list all namespace resources**

	```
	kubectl api-resources --verbs=list --namespaced -o name   | xargs -n 1 kubectl get --show-kind --ignore-not-found -n tibco-prod
	```

- **events sorted** 

	```bash
	kubectl get events --sort-by=.metadata.creationTimestamp
	```
	
- **get quotas for all namespace** 

	```bash
	kubectl get quota --all-namespaces -o=custom-columns=Project:.metadata.namespace,TotalPods:.status.used.pods,TotalCPURequest:.status.used.requests'\.'cpu,TotalCPULimits:.status.used.limits'\.'cpu,TotalMemoryRequest:.status.used.requests'\.'memory,TotalMemoryLimit:.status.used.limits'\.'memory
	```

## **EVENTS**

 - **get event sort by creation**

	```bash
    kubectl get events --sort-by=.metadata.creationTimestamp
	```

## **POD**

 - **pod request/limits**

	```bash
	kubectl get $i -o=jsonpath='{range .spec.containers[*]}{"Container Name: "}{.name}{"\n"}{"Requests:"}{.resources.requests}{"\n"}{"Limits:"}{.resources.limits}{"\n"}{end}' -n <NAMESPACE>
	```
	
 - **pod x nodo**
	
	```bash
	kubectl get pods -o wide --all-namespaces | awk '{print $8}' | sort | uniq -c
	```

 - **max pod x nodo**
 
	```bash
	kubectl get node <node_name> -ojsonpath='{.status.capacity.pods}{"\n"}'
	```
	
 - **aprire shell in un pod**

	```bash
	kubectl exec -it --namespace=<NAMESPACE> <pod> -- bash (-c "mongo")
	```

 - **describe pod with particular label**

	```bash
	pod=$(kubectl get pods --selector="name=frontend" --output=jsonpath={.items..metadata.name})
kubectl describe pod $pod
	```

 - **list only name**

	```bash
	kubectl get pods --no-headers -o custom-columns=":metadata.name"
	kubectl get deploy --no-headers -o custom-columns=":metadata.name"
	```

 - **list pod by restart**

	```bash
	kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'
	```
	
 - **list pod by age**

	```bash
	kubectl get pods --sort-by=.metadata.creationTimestamp
	```
	
 - **list non running pod**

	```bash
	kubectl get pods -A --field-selector=status.phase!=Running | grep -v Complete

	kubectl get pod --field-selector status.phase!=Running -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,NAMEDPACE:.metadata.namespace
	```
	
 - **get pods x nodes**

	```bash
	kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=
	```
	
 - **get pod using column**

	```bash
	kubectl get pods --all-namespaces -o=custom-columns=NAME:.metadata.name,Namespace:.metadata.namespace
	```
	
 - **list pod sort by name**

	```bash
	kubectl get po -o wide --sort-by=.spec.nodeName
	```

 - **list all container in the cluster**

	```bash
	kubectl get pods -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .status.containerStatuses[*]}{.name}{": "}{.ready}{", "}{end}{end}'
	kubectl get pod --all-namespaces | awk '{print $3}' | awk -F/ '{s+=$1} END {print s}' ### count
	```

 - **which pod is using which PVC**

	```bash
	kubectl get po -o json --all-namespaces | jq -j '.items[] | "\(.metadata.namespace), \(.metadata.name), \(.spec.volumes[].persistentVolumeClaim.claimName)\n"' | grep -v null
	```

 - **Pod termination message**

	```bash
	kubectl get pod termination-demo -o go-template="{{range .status.containerStatuses}}{{.lastState.terminated.message}}{{end}}"
	```

 - **delete evicted pods**

	```bash
	for POD in $(kubectl get pods|grep Evicted|awk '{print $1}'); do kubectl delete pods $POD ; done
	```

 - **delete ALL non Running pods**
 
	```bash
	kubectl get po --all-namespaces --no-headers | grep -v Running > /tmp/podnotok && cat /tmp/podnotok | while read ns pod rep stat; do kubectl delete pod $pod -n $ns --force --grace-period=0 ; done
	```

 - **logs tail**

	```bash
	k logs -f NOMEPOD --tail=10
	```

 - **logs degli ultimi x minuti**

	```bash
	k logs -f NOMEPOD --since=30m
	```

 - **check reason for evicted pods**

	```bash
	kubectl get pod -A -o json | jq '.items | select(.status.reason=="Evicted") | {NAME:.metadata.name, NAMESPACE:.metadata.namespace, REASON:.status.reason, MESSAGE:.status.message}'
	```

 - **Produce ENV for all pods**

	```bash
	for pod in $(kubectl get po --output=jsonpath={.items..metadata.name}); do echo $pod && kubectl exec -it $pod -- env; done
    ```

> **INTERACT with POD**

		kubectl logs my-pod                                 # dump pod logs (stdout)
		kubectl logs -l name=myLabel                        # dump pod logs, with label name=myLabel (stdout) 
		kubectl logs my-pod --previous                      # dump pod logs (stdout) for a previous instantiation of a container
		kubectl logs my-pod -c my-container                 # dump pod container logs (stdout, multi-container case)
		kubectl logs -l name=myLabel -c my-container        # dump pod logs, with label name=myLabel (stdout)
		kubectl logs my-pod -c my-container --previous      # dump pod container logs (stdout, multi-container case) for a previous instantiation of a container
		kubectl logs -f my-pod                              # stream pod logs (stdout)
		kubectl logs -f my-pod -c my-container              # stream pod container logs (stdout, multi-container case)
		kubectl logs -f -l name=myLabel --all-containers    # stream all pods logs with label name=myLabel (stdout)
		kubectl run -i --tty busybox --image=busybox:1.28 -- sh  # Run pod as interactive shell
		kubectl run nginx --image=nginx -n mynamespace      # Start a single instance of nginx pod in the namespace of mynamespace
		kubectl run nginx --image=nginx                     # Run pod nginx and write its spec into a file called pod.yaml--dry-run=client -o yaml > pod.yaml
		kubectl attach my-pod -i                            # Attach to Running Container
		kubectl port-forward my-pod 5000:6000               # Listen on port 5000 on the local machine and forward
		to port 6000 on my-pod
		kubectl exec my-pod -- ls /                         # Run command in existing pod (1 container case)
		kubectl exec --stdin --tty my-pod -- /bin/sh        # Interactive shell access to a running pod (1 container case)
		kubectl exec my-pod -c my-container -- ls /         # Run command in existing pod (multi-container case)
		kubectl top pod POD_NAME --containers               # Show metrics for a given pod and its containers
		kubectl top pod POD_NAME --sort-by=cpu              # Show metrics for a given pod and sort it by 'cpu' or 'memory'
		
		kubectl cp /tmp/foo_dir my-pod:/tmp/bar_dir            # Copy /tmp/foo_dir local directory to /tmp/bar_dir in a remote pod in the current namespace
		kubectl cp /tmp/foo my-pod:/tmp/bar -c my-container    # Copy /tmp/foo local file to /tmp/bar in a remote pod in a specific container
		kubectl cp /tmp/foo my-namespace/my-pod:/tmp/bar       # Copy /tmp/foo local file to /tmp/bar in a remote pod in namespace my-namespace
		kubectl cp my-namespace/my-pod:/tmp/foo /tmp/bar       # Copy /tmp/foo from a remote pod to /tmp/bar locally`

## DEPLOY

 - **restart pod graceful**

	```bash
    k get deploy
    k rollout restart deployment ncp-3ds
	```

 - **ROLLOUT RESTART under 1.15 kubectl**

	```bash
	kubectl patch deployment NOMEDEPLOY -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"date\":\"`date +'%s'`\"}}}}}"
	```

 - **restart updating dummy ENV**

	```bash
	`kubectl set env deploy/<DEPLOY> MYVAR=$(date)`
	```

 - **RESTART ALL DEPLOYMENT in THE CLUSTER**
	
	```bash
	kubectl get deployments --all-namespaces | tail +2 | awk '{ cmd=sprintf("kubectl rollout restart deployment -n %s %s", $1, $2) ; system(cmd) }'
	```

 - **SCALE DOWN**

	```bash
	cat all_deployment.txt | grep -v "0/0" | grep -v NAME | grep -v kube-system | grep -v istio-system | while read ns dep more ; do kubectl scale deployment $dep -n $ns --replicas=0; done
	```

 - **SCALE UP**

	```bash
	cat all_deployment.txt | grep -v "0/0" | grep -v NAME | grep -v istio-system | grep -v kube-system | while read ns dep rep more; do replica=$(echo $rep | cut -f2 -d "/"); kubectl scale deployment $dep -n $ns --replicas=$replica; done
	```

 - **BACKUP DEPLOY**

	```bash
	for i in $(kubectl get deployments --no-headers -o custom-columns=":metadata.name"); do k get deploy $i -o yaml > $i-deploy.yaml; done
	```
	
 - **SET RESOURCES DEPLOY**  
 
	```bash
	kubectl set resources deployment nginx --limits cpu=200m,memory=512Mi --requests cpu=100m,memory=256Mi
	```

 - **REMOVE RESOURCES DEPLOY**

	```bash
	kubectl set resources deployment ng
	```

 - **ROLLOUT DEPLOY**

	```bash
	kubectl rollout status deployment nginx
	kubectl rollout pause deployment nginx
	kubectl rollout resume deployment nginx
	kubectl rollout history deployment nginx
	kubectl rollout undo deployments nginx (--to-revision 3)
	```
 

 - **Disable a deployment livenessProbe using a json patch with positional
   arrays**

	```bash
	kubectl patch deployment valid-deployment  --type json   -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/livenessProbe"}]'inx --limits cpu=0,memory=0 --requests cpu=0,memory=0
	```

## NODES

 - **ALLOCAZIONE RISORSE**

	```bash
	alias util='kubectl get nodes --no-headers | awk '\''{print $1}'\'' | xargs -I {} sh -c '\''echo {} ; kubectl describe node {} | grep Allocated -A 5 | grep -ve Event -ve Allocated -ve percent -ve -- ; echo '\'''
	util
	```

 - **label node**

	```bash
	kubectl node <node-name> kubernets.io/role=<name-your-node-role>  --overwrite  
es. kubectl label node worker1  node-role.kubernetes.io/worker=worker
	```

 - **check Taints**

	```bash
	kubectl get nodes <NODE> -o json | jq -r '.spec.taints | .[]'
	```

 - **get node info columns**

	```bash
	kubectl get nodes -o custom-columns="Name:.metadata.name,InternalIP:.status.addresses[0].address"

	kubectl get nodes -o custom-columns="Name:.metadata.name,InternalIP:.status.addresses[0].address,Kernel:.status.nodeInfo.kernelVersion,MemoryPressure:.status.conditions[0].status,DiskPressure:.status.conditions[1].status,PIDPressure:.status.conditions[2].status,Ready:.status.conditions[3].status"
	```

> **INTERACT withNODES**

	
	kubectl cordon my-node                                                 	# Mark my-node as unschedulable
	kubectl drain my-node                                                	  # Drain my-node in preparation for maintenance
	kubectl uncordon my-node                                            	   # Mark my-node as schedulable
	kubectl top node my-node                                             	  # Show metrics for a given node
	kubectl cluster-info                                                 	  # Display addresses of the master and services
	kubectl cluster-info dump                                            	  # Dump current cluster state to stdout
	kubectl cluster-info dump --output-directory=/path/to/cluster-state    	# Dump current cluster state to /path/to/cluster-state
	

 - **View existing taints on which exist on current nodes.**

	```bash
	kubectl get nodes -o=custom-columns=NodeName:.metadata.name,TaintKey:.spec.taints[*].key,TaintValue:.spec.taints[*].value,TaintEffect:.spec.taints[*].effect
	```

 - **If a taint with that key and effect already exists, its value is
   replaced as specified.**

	```bash
	kubectl taint nodes foo dedicated=special-user:NoSchedule
	```

## CRONJOB

 - **execute jobs immediately**

	```bash
	kubectl get cronjob -n <NAMESPACE>
	kubectl create job --from=cronjob/<cronjob-name> <job-name> -n <NAMESPACE>

	kubectl get pods -n <NAMESPACE>
	kubectl delete job <job-name>
	kubectl delete pods/nomepod -n <NAMESPACE>
	```

 - **patch cronjob schedule**

	```bash
	kubectl patch cronjobs <job-name> -p '{"spec" : {"suspend" : true }}'
	```

 - **suspend active cronjobs**

	```bash
	kubectl get cronjob | grep False | awk '{print $1}' | xargs kubectl patch cronjob -p '{"spec" : {"suspend" : true }}'
	```

 - **resume suspended cronjobs**

	```bash
	kubectl get cronjob | grep True | awk '{print $1}' | xargs kubectl patch cronjob -p '{"spec" : {"suspend" : false }}'
	```

 - **LOOP**

	```bash
	for CJ in $(k get cj -A | grep ocr | awk '{print $2}'); do k patch cj $CJ -p '{"spec" : {"suspend" : true }}'; done
	for CJ in $(k get cj -A | grep ocr | awk '{print $2}'); do k patch cj $CJ -p '{"spec" : {"suspend" : false }}'; done
	```

 - **recreate cronjob**

	```bash
	for CJ in $(k get cj -A | grep ocr | awk '{print $2}'); do k get cj $CJ -o yaml > $CJ.backup.yaml; done
	for CJ in $(k get cj -A | grep ocr | awk '{print $2}'); do k delete cj $CJ ; donefor CJ in $(ls -1 *.yaml); do k create -f $CJ.backup.yaml ; done
	```

 - **create a Job which prints "Hello World"**

	```bash
	kubectl create job hello --image=busybox:1.28 -- echo "Hello World"
	```

 - **create a CronJob that prints "Hello World" every minute**

	```bash
	kubectl create cronjob hello --image=busybox:1.28   --schedule="*/1 * * * *" -- echo "Hello World"
	```

## IMAGES

 - **list all images for pod**

	```bash
	kubectl get pods -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' | sort

	kubectl get pods -o jsonpath="{.items[*].spec.containers[*].image}"
	```

## DAEMONSET

 - **Scaling k8s daemonset down to zero**

	```bash
	kubectl patch daemonset myDaemonset -p '{"spec": {"template": {"spec": {"nodeSelector": {"non-existing": "true"}}}}}'
	```

 - **Scaling up k8s daemonset**

	```bash
	kubectl patch daemonset myDaemonset --type json -p=' {"op": "remove", "path": "/spec/template/spec/nodeSelector/non-existing"} '
	```

## **SECRET**

 - **Print secrets in clear base64**

	```bash
	kubectl get secret my-secret -o 'go-template={{index .data "username"}}' | base64 -d
	kubectl get secret my-secret -o json | jq '.data | map_values(@base64d)'
	```

 - **update with patch**

	```bash
	kubectl patch secret test --type='json' -p='[{"op" : "replace" ,"path" : "/data/username" ,"value" : "dGVzdHVzZXIy"}]'
	```

 - **Create a secret with several keys**

```bash
	cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  password: $(echo -n "s33msi4" | base64 -w0)
  username: $(echo -n "jane" | base64 -w0)
EOF
```

 - **Output decoded secrets without external tools**

	```bash
	kubectl get secret my-secret -o go-template='{{range $k,$v := .data}}{{" "}}{{$k}}{{"\n"}}{{$v|base64decode}}{{"\n\n"}}{{end}}'
	```

 - **List all Secrets currently in use by a pod**

	```bash
	kubectl get pods -o json | jq '.items[].spec.containers[].env[]?.valueFrom.secretKeyRef.name' | grep -v null | sort | uniq
	```

## **CONFIGMAP**

 - **extract file from configmap**

	```bash
	kubectl get cm <NOME-CONFIGMAP>-o jsonpath='{.data.ballerina\.conf}' > ballerina.conf
	```
