FROM alpine
COPY add-user del-user gen-cert output-crt output-auth sleep-forever do-restore do-backup /usr/local/sbin/
RUN apk update \
 && apk add openssl \
 && apk add apache2-utils
ENTRYPOINT ["sleep-forever"]

