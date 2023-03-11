FROM ubuntu:latest

RUN apt-get update && apt-get -y upgrade \
	&& apt-get install -y --no-install-recommends curl python3 curl openssl openjdk-8-jre-headless \
	&& rm -rf /var/lib/apt/lists/*

ADD ./kafka kafka
ADD ./createCerts.sh createCerts.sh
ADD ./docker-entrypoint.sh docker-entrypoint.sh 
ENV FLOGO_LOG_LEVEL DEBUG
ENTRYPOINT [ "/docker-entrypoint.sh" ]