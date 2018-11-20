#!/bin/bash

set -euf -o pipefail

# an instance of template {{ self }}
# variables:
#   dbname = '{{ dbname }}'
#   user = '{{ user }}'
#   appname = '{{ appname }}'
#   dbconfpath = '{{ dbconfpath }}'
#   envs = [{{ '\'' + envs|join('\', \'') + '\'' }}]

# create per-env databases and user role
sudo -u postgres bash -lc '
  cd
  psql <<EOF
  {%- for env in envs %}
  DROP DATABASE IF EXISTS {{ dbname }}_{{ env }};
  {%- endfor %}
  DROP USER IF EXISTS {{ user }};
  CREATE USER {{ user }};
  {%- for env in envs %}
  CREATE DATABASE {{ dbname }}_{{ env }} OWNER {{ user }};
  {%- endfor %}
EOF
'

# use -i flag so interactive mode will source ~/.bashrc for $GOPATH
sudo -u {{ user }} bash -lic '
  # goose uses go "lib/pq" package;
  # we replace "lib/pq" default host=localhost in YAML with local socket;
  # local access uses "peer" method authentication.
  TMPDIR=$(mktemp -d)
  path=$TMPDIR/pg
  trap "rm -rf \$TMPDIR" INT QUIT EXIT
  cp -r $GOPATH/src/github.com/{{ dbconfpath }} $path
  sed -i -e "/dbname/s,dbname,host=/var/run/postgresql &," $path/dbconf.yml

  db={{ dbname }}
  user={{ user }}
  # we put app tables in an app-specific postgresql schema
  schema={{ appname }}

  cd

  for env in {{ envs|join(' ') }}
  do
    dbname=${db}_${env}
    # create schema
    psql -d $dbname -c "CREATE SCHEMA $schema"
    # initialize via goose
    goose -env $env -path $path -pgschema $schema up
    # set schema search path
    psql -d $dbname -c "ALTER ROLE $user SET search_path TO $schema,public"
  done
'
