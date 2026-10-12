#!/bin/sh
# Updates a Docker installation: database backup, newer image, restart.
#   ./update.sh            (run next to docker-compose.yml)
set -eu
cd "$(dirname "$0")"
echo "Backing up the database…"
docker compose exec -T alcove /alcove backup --dir=/data/pb_data --label=pre-update
echo "Pulling the latest image…"
docker compose pull alcove
echo "Restarting…"
docker compose up -d alcove
for i in $(seq 1 60); do
	if docker compose exec -T alcove /alcove healthcheck >/dev/null 2>&1; then
		docker compose exec -T alcove /alcove --version
		echo "Done."
		exit 0
	fi
	sleep 2
done
echo "The new version did not become healthy. Logs: docker compose logs alcove" >&2
exit 1
