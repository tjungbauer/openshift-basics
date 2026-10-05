FROM registry.access.redhat.com/ubi10/php-83
USER 0
COPY src/ /tmp/src/
RUN chown -R 1001:0 /tmp/src
USER 1001
RUN /usr/libexec/s2i/assemble
CMD /usr/libexec/s2i/run
