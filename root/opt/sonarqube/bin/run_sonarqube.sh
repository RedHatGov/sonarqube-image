#!/bin/bash

function on_error() {
  echo "Command on line $1 exited with code $2" >&2
  debug_commands=(
    'ls -halF /opt/sonarqube'
    'stat /opt/sonarqube'
    'ls -halF /opt/sonarqube/data'
    'stat /opt/sonarqube/data'
    'echo $UID'
    'echo $EUID'
    'echo ${GROUPS[@]}'
  )
  for command in "${debug_commands[@]}"; do
    echo "EXECUTING: $command" >&2
    ${command[@]} | sed 's/^/  /' >&2
  done
  exit $2
}

trap 'on_error $LINENO $?' ERR

if [ "${1:0:1}" != '-' ]; then
  exec "$@"
fi

echo "**** Setting up SonarQube Data Volume"
echo "**** Checking if extensions directory exists in data"
if [ ! -d "/opt/sonarqube/data/extensions" ];
then
  echo "**** Initial Setup"
  # For initial setup move extensions into the data directory (on a PVC)
  mv /opt/sonarqube/extensions /opt/sonarqube/data
else
  echo "**** Secondary Setup"
  # For secondary setup just remove the extensions directory from /opt/sonarqube
  # The contents are already in /opt/sonarqube/data/extensions which will be linked
  # back into /opt/sonarqube
  rm -rf /opt/sonarqube/extensions
  if [ ! -f /opt/sonarqube/data/es5/nodes/0/node.lock ]
  then
    rm -f /opt/sonarqube/data/es5/nodes/0/node.lock
  fi
fi
# Now link the extensions from the PVC into the expected location
ln -s /opt/sonarqube/data/extensions /opt/sonarqube

#Added for 7.2 this code does not work, lib/bundled-plugins was moved to extensions/plugins
plugin_folder=""
if [ -d "/opt/sonarqube/lib/bundled-plugins" ];
then
  echo "**** Sonarqube Version < 7.2 Detected"
  plugin_folder="/opt/sonarqube/lib/bundled-plugins/*"
else
  echo "**** Sonarqube Version > 7.2 Detected"
  plugin_folder="/opt/sonarqube/extensions/plugins/*"
fi

# Now make sure all plugins are in the plugins directory - this is especially
# important after adding a PVC.
# Sonarqube ships a selection of plugins in the /opt/sonarqube/lib/bundled-plugins directory.
for plugin in $plugin_folder
do
  # Get the name of the plugin without any version number.
  # E.g. sonar-java-plugin instead of sonar-java-plugin-4.12.0.11033.jar
  plugin_base_name=$(basename ${plugin%-*})

  # For each plugin make sure it doesn't already exist in the data/extensions
  # directory. If it doesn't then copy it to the data/extensions directory.
  echo "  ++++ checking if plugin ${plugin_base_name} is already installed"
  if [ $(ls /opt/sonarqube/data/extensions/plugins/${plugin_base_name}* 2>/dev/null|wc -l) == 0 ];
  then
    echo "  ++++ Installing plugin ${plugin}..."
    cp ${plugin} /opt/sonarqube/data/extensions/plugins
  else
    echo "  ++++ Plugin ${plugin_base_name} already installed."
  fi
done
echo "**** Setting up Data Volume complete"

# Finally start SonarQube
exec java -jar lib/sonar-application-$SONARQUBE_VERSION.jar \
-Dsonar.log.console=true \
-Dsonar.jdbc.username="$SONARQUBE_JDBC_USERNAME" \
-Dsonar.jdbc.password="$SONARQUBE_JDBC_PASSWORD" \
-Dsonar.jdbc.url="$SONARQUBE_JDBC_URL" \
-Dsonar.web.javaAdditionalOpts="$SONARQUBE_WEB_JVM_OPTS -Djava.security.egd=file:/dev/./urandom" \
"$@"
