FROM debian:wheezy

RUN apt-get update \
 && apt-get install -y vim \
 && apt-get install -y --no-install-recommends \
    curl perl make build-essential procps \
    libreadline-dev libncurses5-dev libpcre3-dev libssl-dev \
 && apt-get install -y unzip \
 && rm -rf /var/lib/apt/lists/* \
 && alias ll='ls -althr --color'

ENV OPENRESTY_VERSION 1.9.7.4
ENV OPENRESTY_PREFIX /etc/openresty
ENV NGINX_PREFIX /etc/openresty/nginx
ENV VAR_PREFIX /run/nginx

# NginX prefix is automatically set by OpenResty to $OPENRESTY_PREFIX/nginx
# look for $ngx_prefix in https://github.com/openresty/ngx_openresty/blob/master/util/configure

RUN cd /root \
 && echo "==> Downloading OpenResty..." \
 && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
 && echo "==> Configuring OpenResty..." 

RUN cd /root \
 && curl -sSLk https://github.com/maxmind/libmaxminddb/releases/download/1.1.1/libmaxminddb-1.1.1.tar.gz -o libmaxminddb.tar.gz \
 && mkdir openresty-${OPENRESTY_VERSION}/libmaxminddb \
 && tar -xzvf libmaxminddb.tar.gz  -C openresty-*/libmaxminddb --strip-components=1 \
 && cd /root/openresty-*/libmaxminddb \
 && ./configure \
 && make \
 && make check \ 
 && make install \
 && ldconfig

#RUN cd /root \
# && curl -sSLk http://people.freebsd.org/~osa/ngx_http_redis-0.3.7.tar.gz -o ngx-http-redis.tar.gz \
# && mkdir openresty-${OPENRESTY_VERSION}/http-redis \
# && tar -xzvf ngx-http-redis.tar.gz -C /root/openresty-*/http-redis --strip-components=1

#RUN cd /root \ 
# && curl -sSLk https://github.com/leev/ngx_http_geoip2_module/archive/1.0.tar.gz -o ngx-http-geoip2.tar.gz \
# && mkdir openresty-${OPENRESTY_VERSION}/http-geoip2 \
# && tar -xzvf ngx-http-geoip2.tar.gz  -C /root/openresty-*/http-geoip2 --strip-components=1 

RUN cd /root \
 && curl -sSL http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz -o ngx_cache_purge-2.3.tar.gz \
 && mkdir openresty-${OPENRESTY_VERSION}/ngx_cache_purge \
 && tar -xzvf ngx_cache_purge-2.3.tar.gz  -C /root/openresty-*/ngx_cache_purge  --strip-components=1
 
#RUN cd /root \
# && curl -sSLk https://github.com/simpl/ngx_devel_kit/archive/v0.2.19.zip -o ngx_devel_kit-0.2.19.zip \
# && unzip ngx_devel_kit-0.2.19.zip -d /root/openresty-*/ \
# && mv /root/openresty-${OPENRESTY_VERSION}/ngx_devel_kit-0.2.19 /root/openresty-${OPENRESTY_VERSION}/ngx_devel_kit

RUN cd /root \
 && curl -sSLk https://github.com/p0pr0ck5/lua-resty-waf/archive/master.zip -o lua-resty-waf-master.zip \
 && unzip lua-resty-waf-master.zip -d /root/openresty-*/bundle/

RUN cd /root/openresty-* \
 && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
 && echo "using upto $NPROC threads" \
 && ./configure \
    --prefix=$OPENRESTY_PREFIX \
    --http-client-body-temp-path=$VAR_PREFIX/client_body_temp \
    --http-proxy-temp-path=$VAR_PREFIX/proxy_temp \
    --http-log-path=/var/log/access.log \
    --error-log-path=var/log/error.log \
    --pid-path=$VAR_PREFIX/nginx.pid \
    --lock-path=$VAR_PREFIX/nginx.lock \
    --with-luajit \
    --with-pcre-jit \
    --with-ipv6 \
    --with-http_ssl_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
#    --with-http_spdy_module \
#    --with-http_image_filter_module \
    --with-file-aio \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_realip_module \
    --with-http_auth_request_module \
    --with-http_addition_module \
    --with-http_sub_module \
#    --add-module=http-redis \
#    --add-module=http-geoip2 \
#    --add-module=./ngx_devel_kit \
    --add-module=./ngx_cache_purge \
    --without-http_ssi_module \
    --without-http_userid_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    -j${NPROC} \
 && echo "==> Building OpenResty..." \
 && make -j${NPROC} \
 && echo "==> Installing OpenResty..." \
 && make install \
 && echo "==> Finishing..." \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/nginx \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/openresty \
 && ln -sf $OPENRESTY_PREFIX/bin/resty /usr/local/bin/resty \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* $OPENRESTY_PREFIX/luajit/bin/lua \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* /usr/local/bin/lua \
 && rm -rf /root/ngx_openresty*

WORKDIR $NGINX_PREFIX/
RUN mkdir -p /var/log/nginx /data/www 
RUN cp -r /root/openresty-${OPENRESTY_VERSION}/bundle/lua-resty-waf-master /etc/openresty/lualib/lua-resty-waf-master

#ONBUILD RUN rm -rf conf/* /data/nginx/*
#ONBUILD COPY nginx $NGINX_PREFIX/

CMD ["nginx", "-g", "daemon off;"] 
#ENTRYPOINT /usr/local/bin/nginx -c /opt/openresty/nginx/conf/nginx.conf && /bin/bash
