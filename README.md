Stack DB Migrator Helper
========================

Wraps the mvn command for the [LDS Stack DB Migrator][1] to make it easier to use.

Installation
------------

    [sudo] gem install sdm

Commands
--------

    envs              Show available environments to run migrations on.
    status    st      Display status of database. See pending migrations.
    migrate   mi      Apply scripts in queue to bring database to target.
    execute   exec x  Run specified script ad hoc. Without logging.
    new               Create a new blank script with timestamp in name.
    drop              Delete all objects in the database.

See `sdm <command> -h` to get additional help and usage on a specific command.

[1]: http://code.lds.org/maven-sites/stack/module.html?module=db-migrator
