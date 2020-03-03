FROM ubuntu:18.04

ARG VERSION="v2.4.5"
ARG HTTP_PROXY=""

RUN mkdir -p /app/bin && apt update && apt install -y curl wget
RUN wget -qO-  https://github.com/delphix/dxtoolkit/releases/download/${VERSION}/dxtoolkit2-${VERSION}-ubuntu1804-installer.tar.gz | tar -C /app --transform 's/^dxtoolkit2/bin/' -xvz

ENV PATH=$PATH:/app/bin/

WORKDIR /app/bin/

CMD ["/app/bin/gitlab_ci_cd_controller.sh"]
