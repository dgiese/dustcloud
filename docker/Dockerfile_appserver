FROM python:3.5

RUN pip3 install pymysql python-miio cryptography Pillow bottle

COPY dustcloud /opt/dustcloud

RUN cp /opt/dustcloud/config.sample.ini /opt/dustcloud/config.ini && \
    sed -i 's/host = 127.0.0.1/host = db/g' /opt/dustcloud/config.ini && \
    chown www-data:www-data /opt/dustcloud/www/cache

