FROM alpine:3.4

RUN set -x \
	&& addgroup -g 82 -S www-data \
	&& adduser -u 82 -D -S -G www-data www-data

ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $HTTPD_PREFIX/bin:$PATH
RUN mkdir -p "$HTTPD_PREFIX" \
	&& chown www-data:www-data "$HTTPD_PREFIX"
WORKDIR $HTTPD_PREFIX

RUN mkdir -p /run/apache2

RUN apk add --no-cache apache2
RUN apk add --no-cache mod_file_cache

COPY images/* /var/www/localhost/htdocs/

EXPOSE 80

CMD ["httpd", "-C",  "ServerName localhost", "-e", "Debug", "-DFOREGROUND"]
