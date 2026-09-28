FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc

# cdp-slim stub service image (Issue #04): one image for all 7 v1 services.
# Each container serves /var/www over HTTP; SERVICE_NAME/PORT/SEED configure identity.
# Base is digest-pinned; darkhttpd (static-file server) added via apk because the
# stock busybox in this base lacks the httpd applet (verified at build time).
# Real CDP images arrive later; the endpoint shape (GET /health, GET /state/<key>) is the contract.
RUN apk add --no-cache darkhttpd
COPY stub.sh /usr/local/bin/stub.sh
RUN chmod +x /usr/local/bin/stub.sh

ENTRYPOINT ["/usr/local/bin/stub.sh"]
