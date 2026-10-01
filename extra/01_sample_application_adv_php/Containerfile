# UBI 10: Apache httpd + PHP 8.3 (S2I)
FROM registry.access.redhat.com/ubi10/php-83
 
# sources go where S2I assemble expects them
USER 0
COPY src/ /tmp/src/
RUN chown -R 1001:0 /tmp/src
USER 1001
 
# install deps (composer.json), prepare app
RUN /usr/libexec/s2i/assemble
 
CMD /usr/libexec/s2i/run

