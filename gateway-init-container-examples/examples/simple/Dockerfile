FROM busybox

WORKDIR /config
COPY config config
COPY entrypoint.sh .
CMD [ "/bin/sh", "./entrypoint.sh" ]