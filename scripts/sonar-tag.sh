#!/bin/bash

# Dependencies to use this script
deps=(
    curl
    jq
)
missing=()
for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        missing+=("$dep")
    fi
done
if [ ${#missing[@]} -ne 0 ]; then
    echo "Missing dependencies (${missing[@]}), unable to continue." >&2
    exit 1
fi

function github_output {
    # Sets a variable for GitHub action outputs
    var_name="$1"
    shift
    var_value="$*"
    echo "::set-output name=$var_name::$var_value"
}

function component_version {
    # Determine the latest release version of a specific component from GitHub's
    #   API, used to grab the Distribution from SonarSource.
    component="${1:-sonarqube}"

    sonar_component_version=$(
        curl -s https://api.github.com/repos/SonarSource/$component/releases/latest \
            | jq -r .tag_name
    )
    # Set a variable for that component in GitHub actions
    github_output $component-version $sonar_component_version
}

# Set the GitHub Actions output for the latest version of SonarQube
component_version sonarqube
# Save the collected version separately for tags
sonarqube_version=$sonar_component_version
# We need the sonar-java-plugin version
component_version sonar-java

# Tagging outputs depends on branch and action
if [ "${GITHUB_REF}" == "refs/heads/main" -a "${GITHUB_EVENT_NAME}" != "pull_request" ]; then
    # We are in a regular commit on main and should publish the image with the sonarqube version and latest.
    tags=$(echo "$sonarqube_version" | sed \
        -e 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\)\..*/\1/' \
        -e 's/\(\(\([0-9]\+\)\.[0-9]\+\)\.[0-9]\+\)/\1,\2,\3,/' \
        -e 's/\([^,]\+\),/quay.io\/redhatgov\/sonarqube:\1,/g' \
        -e 's/$/quay.io\/redhatgov\/sonarqube:latest/')
    github_output tags "$tags"
else
    # We are in some branch other than main, or a pull request, and should just use the name of the branch
    branch=$(echo "$GITHUB_REF" | cut -d/ -f3- | tr '/' '_')
    github_output tags "quay.io/redhatgov/sonarqube:$branch"
fi
