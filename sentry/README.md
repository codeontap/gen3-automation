# Managed sentry installation

It's okay to have single sentry per organisation and manage developers by teams and projects.

The good think about sentry is once you have database backup you may not worry abour persistency and fallbacks and multiple AZ - if it's broken then you just create another and load database dump there.

## Usage:

### Up

    $ cp sentry.env.sample sentry.env
    $ vim sentry.env
    $ docker-compose up
    $ control-c
    $ docker-compose up -d
    $ docker-compose exec sentry sentry upgrade

`up -d` starts service in background. `sentry upgrade` step asks for superuser, you can try to pass `--noinput` to avoid that.

installation uses ./var/pg_data directory as postgres database storage.

Then point your nginx with https to 127.0.0.1:8000 (port from docker-compose file, may be changed safely). HTTPS is easier to handle outside that installation.

If you want sentry to use RDS then remove postgresql mentions from docker-compose and point it to RDS as desribed at link in sentry.env file.

### Slack

To configure slack go to sentry project settings -> Integrations -> tick Slack on and save -> select Slack in left menu and configure it.


### Usage

To run commands inside the container:

    $ docker-compose exec sentry ....

Please add `sentry cleanup` command to your cron.

Also please add the next command to your cron:

    $ docker-compose exec postgres bash -c "mkdir -p /backups; pg_dump -U postgres postgres > /backups/pg-dump-`date +%F`.sql"

and copy fresh files from ./var/pg_dumps somewhere safe.

If you already have the database dump you may load it the same way, using pgdump and after putting the file to some location where inside of docker container may access it.
