# Docker KAFKA SSL

This will help you quickly spin up a SSL enabled Kafka instance with version 2.13-3.0.0

## How to

Basic commands

### Start the server

```bash
 ./kafka-start.sh
```

This script will create the ssl certificates and start kafka instance with one broker in docker container. which can be access on localhost:9092. 
Required certificates for SSL connection will get downloaded to kafkaCerts in current working diretory.

Topic : test

### Stop the server

```bash
./kafka-stop.sh
```

This script will stop and remove the container.