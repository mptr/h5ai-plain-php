FROM php:8-fpm

RUN apt-get update -y \
    && apt-get install -y nginx

# PHP_CPPFLAGS are used by the docker-php-ext-* scripts
ENV PHP_CPPFLAGS="$PHP_CPPFLAGS -std=c++11"

RUN docker-php-ext-install pdo_mysql \
    && docker-php-ext-install opcache \
    && apt-get install libicu-dev -y \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && apt-get remove libicu-dev icu-devtools -y
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/php-opocache-cfg.ini

RUN docker-php-ext-install mysqli
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# write nginx conf
RUN echo 'server { \
    root    /var/www/html; \
    include /etc/nginx/default.d/*.conf; \
    index app.php index.php index.html index.htm /_h5ai/public/index.php; \
    client_max_body_size 30m; \
    error_page 404 /404.php; \
    location / { \
        try_files $uri $uri/ $uri.html $uri.php$is_args$query_string; \
    } \
    location ~ [^/]\.php(/|$) { \
        try_files $uri =404; \
        fastcgi_split_path_info ^(.+?\.php)(/.*)$; \
        fastcgi_param HTTP_PROXY ""; \
        fastcgi_pass 127.0.0.1:9000; \
        fastcgi_index index.php; \
        include fastcgi.conf; \
    } \
}' > /etc/nginx/sites-enabled/default

# write entrypoint.sh
RUN echo '#!/usr/bin/env bash \
service nginx start \
php-fpm' > /etc/entrypoint.sh

WORKDIR /var/www/html

EXPOSE 80

ENTRYPOINT ["sh", "/etc/entrypoint.sh"]
