#!/usr/bin/env bash

#
# Notes:
#   - This script uses MacPorts
#   - This script requires Gradle 6 & 7 depending on your build.gradle mix

# Set org to the GH/GHE organization you want to scan
org=newrelic-experimental
#org=FIT

# If you're not scanning GitHub set the hostname here
#export GH_HOST=source.datanerd.us

# Only look for Java repos
gh repo list $org --limit 1000 --language java | while read -r repo _; do
  gh repo clone "$repo" "$repo" 2>/dev/null
  echo "Processing repository: $repo"
  # Step into the cloned repo
  cd $repo

  unset direct
  unset indirect
  unset failed

  # If gradle
  if [[ -f build.gradle ]] ; then
    direct=$(grep log4j build.gradle)

    # If old gradle
    if grep -q compile build.gradle ; then
      sudo port -q activate gradle @6.8.2_0 >/dev/null
    else
      sudo port -q activate gradle @7.3.2_0 >/dev/null
    fi
    #
    # DIRE WARNING
    #   -- Gradle will try to read from stdin, you MUST redirect stdin to /dev/null for this to work due to the `while read` above
    depend=$(gradle --console plain -q dependencies < /dev/null 2>&1 )
    failed=$(echo "${depend}" | grep FAIL)
    indirect=$(echo "${depend}" | grep log4j)
  fi

  # if maven
  if [[ -f pom.xml ]] ; then
    #echo "Maven"
    direct=$(grep log4j pom.xml)
    indirect=$(mvn dependency:tree | grep log4j)
  fi

  if [[ -z "${direct}" && -z "${indirect}" && -z "${failed}" ]] ; then
    echo "  repo is clean"
  else
    if ! [[ -z "${failed}" ]] ; then
      echo "  repo has build failures, indirect references not detectable"
    fi
    if ! [[ -z "${direct}" ]] ; then
      echo "  repo has direct references: $direct"
    fi
    if ! [[ -z "${indirect}" ]] ; then
      echo "  repo has indirect references: $indirect"
    fi
  fi

  # step back
  cd - > /dev/null
done
