FROM google/golang
RUN curl -sSL https://get.docker.com/ | sh
ADD ./hack/build.sh /build.sh
CMD ["/build.sh"]
