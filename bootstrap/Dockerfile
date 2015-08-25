FROM alpine
COPY add-user gen-cert output-crt /usr/local/sbin/
RUN apk update \
 && apk add openssl \
 && apk add apache2-utils
ENTRYPOINT ["sh"]

