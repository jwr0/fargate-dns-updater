FROM python:3.11.0-alpine

WORKDIR /
RUN apk add --update --no-cache bash curl jq
RUN pip3 install awscli
COPY entrypoint.sh entrypoint.sh
COPY change-resource-record-sets-skeleton.json change-resource-record-sets-skeleton.json
ENTRYPOINT ["/entrypoint.sh"]
