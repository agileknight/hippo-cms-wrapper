FROM eu.gcr.io/ccp-junior/hippo-site:new-env

COPY wrapper.sh /

CMD ["/wrapper.sh", "catalina.sh", "run"]
