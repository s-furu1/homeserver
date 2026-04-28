#!/bin/bash
mkdir -p /mnt/backup/daily/homeserver
mkdir -p /mnt/backup/daily/vaultwarden
mkdir -p /mnt/backup/daily/docker-volumes
rsync -av --delete ~/homeserver/ /mnt/backup/daily/homeserver/
rsync -av --delete /mnt/backup/vaultwarden/data/ /mnt/backup/daily/vaultwarden/
sudo rsync -av --delete /var/lib/docker/volumes/ /mnt/backup/daily/docker-volumes/
