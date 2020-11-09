FROM registry.access.redhat.com/ubi8/ubi
LABEL maintainer="James Harmison <jharmison@redhat.com>"

ARG SONAR_VERSION=7.9.4
ARG BUILD_DATE=2020-08-06

ENV SONAR_VERSION=$SONAR_VERSION \
    SONARQUBE_HOME=/opt/sonarqube

LABEL name="SonarQube" \
      io.k8s.display-name="SonarQube" \
      io.k8s.description="Provide a SonarQube image to run on Red Hat OpenShift" \
      io.openshift.expose-services="9000" \
      io.openshift.tags="sonarqube" \
      build-date=$BUILD_DATE \
      version=$SONAR_VERSION \
      release="1"


RUN yum -y install unzip java-11-openjdk nss_wrapper nodejs \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && cd /tmp \
    && curl -o sonarqube.zip -fSL https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip \
    && cd /opt \
    && unzip /tmp/sonarqube.zip \
    && mv sonarqube-$SONAR_VERSION sonarqube \
    && rm /tmp/sonarqube.zip* \
    && rm /opt/sonarqube/extensions/plugins/sonar-java-plugin-*.jar \
    && curl -o /opt/sonarqube/extensions/plugins/sonar-java-plugin-6.3.2.22818.jar https://binaries.sonarsource.com/Distribution/sonar-java-plugin/sonar-java-plugin-6.3.2.22818.jar

ADD root /

RUN useradd -r sonar \
    && chmod 775 $SONARQUBE_HOME/bin/run_sonarqube.sh \
    && /usr/bin/fix-permissions /opt/sonarqube

USER sonar
WORKDIR $SONARQUBE_HOME
VOLUME $SONARQUBE_HOME/data
EXPOSE 9000
ENTRYPOINT ["./bin/run_sonarqube.sh"]
