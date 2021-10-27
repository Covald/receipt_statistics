# https://github.com/elastic/logstash-docker
FROM docker.elastic.co/logstash/logstash:7.9.2

# Add your logstash plugins setup here
RUN logstash-plugin install logstash-codec-rubydebug
RUN logstash-plugin install logstash-filter-date
