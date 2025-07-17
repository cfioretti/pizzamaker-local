FROM fluentd:v1.16-debian-1

USER root

RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN gem install fluent-plugin-elasticsearch:5.4.3 \
                fluent-plugin-docker_metadata_filter \
                fluent-plugin-record-modifier

RUN mkdir -p /var/log/fluentd-buffers /var/log/fluentd-containers
RUN chown -R fluent:fluent /var/log/fluentd-buffers /var/log/fluentd-containers

USER fluent

COPY fluent.conf /fluentd/etc/fluent.conf

EXPOSE 24224
