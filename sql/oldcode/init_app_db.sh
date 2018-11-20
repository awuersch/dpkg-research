#!/bin/bash

set -euf -o pipefail

# an instance of template <TemplateReference 'init_app_db.sh'>
# variables:
#   dbname = 'certdb'
#   user = 'me'
#   appname = 'cfssl'
#   dbconfpath = 'cloudflare/cfssl/certdb/pg'
#   envs = ['development', 'test', 'staging', 'production']

# create per-env databases and user role
sudo -u postgres bash -lc '
  cd
  psql <<EOF
  DROP DATABASE IF EXISTS certdb_development;
  DROP DATABASE IF EXISTS certdb_test;
  DROP DATABASE IF EXISTS certdb_staging;
  DROP DATABASE IF EXISTS certdb_production;
  DROP USER IF EXISTS me;
  CREATE USER me;
  CREATE DATABASE certdb_development OWNER me;
  CREATE DATABASE certdb_test OWNER me;
  CREATE DATABASE certdb_staging OWNER me;
  CREATE DATABASE certdb_production OWNER me;
EOF
'

# use -i flag so interactive mode will source ~/.bashrc for $GOPATH
sudo -u me bash -lic '
  # goose uses go "lib/pq" package;
  # we replace "lib/pq" default host=localhost in YAML with local socket;
  # local access uses "peer" method authentication.
  TMPDIR=$(mktemp -d)
  path=$TMPDIR/pg
  trap "rm -rf \$TMPDIR" INT QUIT EXIT
  cp -r $GOPATH/src/github.com/cloudflare/cfssl/certdb/pg $path
  sed -i -e "/dbname/s,dbname,host=/var/run/postgresql &," $path/dbconf.yml

  db=certdb
  user=me
  # we put app tables in an app-specific postgresql schema
  schema=cfssl

  cd

  for env in development test staging production
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
