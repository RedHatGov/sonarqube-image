# Downloader will retrieve installation bundles
FROM registry.access.redhat.com/ubi8/ubi as downloader
ARG SONARQUBE_VERSION=8.7.0.41497
ARG SONAR_JAVA_PLUGIN_VERSION=6.13.0.25138

ENV SONARQUBE_VERSION=$SONARQUBE_VERSION \
    SONAR_JAVA_PLUGIN_VERSION=$SONAR_JAVA_PLUGIN_VERSION

WORKDIR /download
COPY scripts/sonar-download.sh ./
RUN dnf -y install unzip curl gpg \
 && ./sonar-download.sh

# Final image will have Sonarqube installed
FROM registry.access.redhat.com/ubi8/ubi
ARG SONARQUBE_VERSION=8.7.0.41497
ARG SONAR_JAVA_PLUGIN_VERSION=6.13.0.25138

ENV SONARQUBE_VERSION=$SONARQUBE_VERSION \
    SONAR_JAVA_PLUGIN_VERSION=$SONAR_JAVA_PLUGIN_VERSION

LABEL name="SonarQube" \
      vendor="Sonatype" \
      io.k8s.display-name="SonarQube" \
      io.openshift.expose-services="9000:http" \
      io.openshift.tags="sonarqube" \
      org.sonarqube.version=$SONARQUBE_VERSION \
      org.sonarqube.plugins.sonar-java.version=$SONAR_JAVA_PLUGIN_VERSION \
      release="2" \
      maintainer="James Harmison <jharmison@redhat.com>"

COPY --from=downloader /download/opt /opt
RUN dnf -y install java-11-openjdk nodejs \
 && dnf clean all \
 && rm -rf /var/cache/yum /var/cache/dnf \
 && chown -R 1001:0 /opt/sonarqube \
 && chmod -R u=rwX,g=rX,o=rX /opt/sonarqube \
 && chmod -R u=rwX,g=rwX,o=rX /opt/sonarqube/{extensions,temp,logs,data}
COPY root /

USER 1001
WORKDIR /opt/sonarqube
VOLUME /opt/sonarqube/data
EXPOSE 9000
ENTRYPOINT ["/opt/sonarqube/bin/run_sonarqube.sh"]
