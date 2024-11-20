
# lista le immagini ordinate per dimensione
docker images --format 'table {{.Repository}}\t{{.ID}}\t{{.Tag}}\t{{.Size}}' | (read -r; printf "%s\n" "$REPLY"; sort -h -k4)


# Effettua il backup dei container attivi
for container in $(docker ps --format {{.Names}}); do
    docker export $container -o $container.tar
done

# Effettua il backup delle immagini
docker save $(docker images --format {{.Repository}}:{{.Tag}}) -o images.tar

# Effettua il backup dei volumi
docker run --rm --volumes-from $(docker ps -qa) -v $(pwd):/backup alpine tar cvf /backup/volumes.tar /data

# Rimuovi i container non in esecuzione
docker container prune

# Rimuovi le immagini non utilizzate dai container attivi
docker image prune --filter "dangling=false"

#rimuove tutte le immagini che non hanno almeno un container associato
docker image prune -a
docker image prune --all --filter label!=name="ucp"

# Rimuovi i volumi non utilizzati dai container attivi
docker volume prune

docker volume rm $(docker volume ls -qf dangling=true)

docker system df

docker system df -v
### shpw labels
docker container ls --format "table {{.ID}}\t{{.Labels}}" 