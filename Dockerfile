FROM ubuntu:16.04

ARG DOWNLOAD_URL=https://github.com/delphix/dxtoolkit/releases/download/v2.3.9.1/dxtoolkit2-2.3.9.1-redhat7.tar.gz

RUN apt-get update && apt-get install -y wget curl \
   && mkdir -p /app/bin \
   && wget -O /app/bin/dxtools.tar.gz $DOWNLOAD_URL \
   && tar -xzvf /app/bin/dxtools.tar.gz -C /app/bin --strip-components=1 \
   && rm -f /app/bin/dxtools.tar.gz
  
COPY ./bin /app/bin

ENV PATH=$PATH:/app/bin/

WORKDIR /app/bin/

CMD ["/app/bin/gitlab_ci_cd_controller.sh"]
