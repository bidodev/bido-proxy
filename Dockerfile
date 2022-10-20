ARG IMAGE=alpine:3.16.1
FROM $IMAGE as builder

ENV NGINX_VERSION 1.23.1
ADD https://github.com/krallin/tini/releases/download/v0.19.0/tini /tini

WORKDIR /tmp

RUN apk update && \
    apk add       \
      alpine-sdk  \
      openssl-dev \
      pcre-dev    \
      zlib-dev

RUN curl -LSs http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -O                                             && \
    tar xf nginx-${NGINX_VERSION}.tar.gz                                                                             && \
    cd     nginx-${NGINX_VERSION}                                                                                    && \
    git clone https://github.com/chobits/ngx_http_proxy_connect_module                                               && \
    patch -p1 < ./ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_102101.patch                             && \
    ./configure                                                                                                         \
      --add-module=./ngx_http_proxy_connect_module                                                                      \
      --sbin-path=/usr/sbin/nginx                                                                                       \
      --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' && \
    make -j $(nproc)                                                                                                 && \
    make install                                                                                                     && \
    rm -rf /tmp/*

RUN chmod +x /tini

FROM $IMAGE

COPY nginx_whitelist.conf /usr/local/nginx/conf/nginx.conf
COPY --from=builder /usr/local/nginx/sbin/nginx /usr/local/nginx/sbin/nginx
COPY --from=builder /tini /tini

EXPOSE 8888

ENTRYPOINT ["/tini", "--"]

CMD [ "nginx", "-g", "daemon off;" ]
