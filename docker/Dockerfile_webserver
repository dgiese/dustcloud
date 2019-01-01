FROM ubuntu:16.04

ARG cloudserverip

RUN apt-get update && \
    apt-get install -y apache2 php7.0-zip composer libapache2-mod-php7.0 supervisor \
    php7.0-mysql python3-pip virtualenv python3-mysqldb python3-cryptography python3-pil php7.0-curl

COPY dustcloud /opt/dustcloud

RUN sed -i 's/^\(\[supervisord\]\)$/\1\nnodaemon=true/' /etc/supervisor/supervisord.conf
RUN mkdir -p /var/log/supervisor

COPY docker/programs.conf /etc/supervisor/conf.d/programs.conf
COPY docker/dustcloud.conf /etc/apache2/conf-enabled/

RUN cp /opt/dustcloud/config.sample.ini /opt/dustcloud/config.ini && \
    sed -i 's/host = 127.0.0.1/host = db/g' /opt/dustcloud/config.ini && \
    sed -i "s/ip = 10.0.0.1/ip = $cloudserverip/g" /opt/dustcloud/config.ini && \
    sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf && \
    chown www-data:www-data /opt/dustcloud/www/cache

RUN cd /opt/dustcloud/www && composer install
RUN pip3 install python-miio pymysql cryptography Pillow bottle


ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
