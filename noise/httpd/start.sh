#!/bin/sh

mkdir -p /var/www/localhost/htdocs/images
mount -t tmpfs -o size=10g none /var/www/localhost/htdocs/images

cp /images/* /var/www/localhost/htdocs/images

httpd -C  "ServerName localhost" -e Debug -DFOREGROUND
