#!/usr/bin/python3

from jinja2 import Environment, FileSystemLoader

jinja_env = Environment(loader=FileSystemLoader('template'))
dbname = 'certdb'
user = 'me'
appname = 'cfssl'
dbconfpath = 'cloudflare/cfssl/certdb/pg'
envs = [ 'development', 'test', 'staging', 'production' ]

jinja_template = jinja_env.get_template('init_app_db.sh')
print(
  jinja_template.render(
    dbname=dbname,
    user=user,
    appname=appname,
    dbconfpath=dbconfpath,
    envs=envs
  )
)
