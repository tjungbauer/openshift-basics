# Red Hat UBI 10 image with Apache httpd 2.4
FROM registry.access.redhat.com/ubi10/httpd-24
 
LABEL org.opencontainers.image.title="hello-web" \
      org.opencontainers.image.version="1.0.0"
 
# copy the static content into the document root
COPY html/ /var/www/html/
 
# httpd in this image listens on 8080 and runs as UID 1001
EXPOSE 8080
CMD ["run-httpd"]

