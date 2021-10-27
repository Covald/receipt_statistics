#!/bin/bash

reload_nginx() {
    docker-compose exec -T server-nginx /usr/sbin/nginx -s reload
}


zero_downtime_deploy() {
    echo "Stop old worker container"
    docker-compose stop -t 120 worker
    docker-compose rm -sf worker

    echo "Get old server container id"
    service_name="server"
    old_container_name=$(docker ps -a --format "{{.Names}}" --filter name=$service_name | grep -v nginx | tail -n1)

    # bring a new container online, running new code
    # (nginx continues routing to the old container only)
    echo "Up new contianer"
    docker-compose up -d --no-deps --scale $service_name=2 --no-recreate $service_name

    # wait for new container to be available
    echo "Waiting for new container to be available..."
    new_container_id=$(docker ps -f name=$service_name -f since=$old_container_name -q | grep -v nginx | head -n1)
    docker exec -t $new_container_id dockerize -wait 'http://localhost:8000' -timeout 5s

    # start routing reuests to the new container (as well as the old)
    echo "Reload nginx"
    reload_nginx

    # take the old container offline
    echo "Stop and remove old container"
    docker rm -f $old_container_name

    echo "Scale down application container"
    docker-compose up -d --no-deps --scale $service_name=1 --no-recreate $service_name

    # stop routing requests to the old container
    echo "Reload nginx"
    reload_nginx

    echo "Start new worker container"
    docker-compose up -d --no-recreate worker
    # start routing prometheus requests to the new worker container
    echo "Reload nginx"
    reload_nginx
}

# zero_downtime_deploy
server_is_running=$(docker-compose ps -q server)
worker_is_running=$(docker-compose ps -q worker)
nginx_is_running=$(docker-compose ps -q server-nginx)
if [[ "$server_is_running" != "" && "$nginx_is_running" != "" && "$worker_is_running" != "" ]]; then
    zero_downtime_deploy
else
    docker-compose stop && docker-compose up -d
fi
