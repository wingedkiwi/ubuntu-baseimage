# A minimal Ubuntu base image that is Predictable and stays Up To Date

_ubuntu-baseimage_ is a docker base image based on the work of [phusion/baseimage-docker](https://github.com/phusion/baseimage-docker) and inherits the following features:

  * [A correct Init system solving the PID 1 problem](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/).
  * Scripts in `/etc/my_init.d/` are started in lexical order.
  * `rc.local` is executed after the _Init Scripts_.
  * Fixes APT incompatibilities with Docker See https://github.com/dotcloud/docker/issues/1024.
  * A mechansim to simplify work with _Environment Variables_.
  * Provides a `cron` and `syslog-ng` with `logotate` daemon per default.
  * Ability to define additonal daemons in `/etc/service`.
  * Lightweight sudo alternative at `/sbin/setuser`

Moreover _ubuntu-baseimage_ brings the following improvements:

 * Provides an [Automated Build](https://hub.docker.com/r/wingedkiwi/ubuntu-baseimage/) that stays up to date and
 eleminates the need to run `apt-get upgrade`. (See [dockerfile best-practices](https://docs.docker.com/articles/dockerfile_best-practices/#run))
 * Services are started in lexical order.
 * Services are terminated in reverse lexical order.
 * User command is executed after all services has been started.
 * If a `check` script for a service is provided, the init daemon will wait until service is fully started.
 * `/sbin/my_init` in `Dockerfile` is defined as `ENTRYPOINT` instead as `CMD`.

Changes due to personal choice:

 * Removes sshd service as it is not essential (see [nsenter](https://blog.docker.com/tag/nsenter/)).

_ubuntu-baseimage_ introduces backward-incompatible changes to [phusion/baseimage-docker](https://github.com/phusion/baseimage-docker).

## The problems _ubuntu-baseimage_ tries to solve

Even though [phusion/baseimage-docker](https://github.com/phusion/baseimage-docker) claims that it _does everything right_, it still leaves us with some unsolved problems:

  * The image is not updated regularly (Last push was 2 months ago, whereas _Ubuntu_ base Image was pushed 8 days ago. Status from 10th Sep 2015). Moreover it advocates the use of `apt-get upgrade` which is contrary to [dockerfile best-practices](https://docs.docker.com/articles/dockerfile_best-practices/#run))
  * Naturally services/daemons depend on each other. _phusion/baseimage-docker_ starts and stops all daemons at the same time causing unpredictable behavior and failure.
  * _phusion/baseimage-docker_ executes the user provided command without knowing if the required services/daemons are up and running.

_ubuntu-baseimage_ solves the above problems using an [Automated Build](https://hub.docker.com/r/wingedkiwi/ubuntu-baseimage/) and a predictable boot and shutdown mechanism.

## Using _ubuntu-baseimage_ as base image

 * [Getting started](#getting_started)
 * [Adding additional daemons](#adding_additional_daemons)
    * [Starting order](#starting_order)
    * [Wait until daemon is fully up](#wait_until)
 * [Disable daemons](#disable_daemons)
 * [Running scripts during container startup](#running_startup_scripts)
 * [Environment variables](#environment_variables)
    * [Centrally defining your own environment variables](#envvar_central_definition)
        * [Environment variable dumps](#envvar_dumps)
        * [Modifying environment variables](#modifying_envvars)
        * [Security](#envvar_security)
 * [Upgrading the operating system inside the container](#upgrading_os)

<a name="getting_started"></a>
### Getting started

The image is called `wingedkiwi/ubuntu-baseimage`, and is available on the [Docker registry](https://hub.docker.com/r/wingedkiwi/ubuntu-baseimage/).

    # Use wingedkiwi/ubuntu-baseimage as base image.
    FROM wingedkiwi/ubuntu-baseimage:<VERSION>

    # Put your own build instructions here.

    # Clean up APT when done.
    RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

    # Run your command or leave empty if only the daemons should be started.
    CMD ["your_command"]

<a name="adding_additional_daemons"></a>
### Adding additional daemons

You can add additional daemons (e.g. your own app) to the image by creating runit entries. You only have to write a small shell script which runs your daemon, and runit will keep it up and running for you, restarting it when it crashes, etc.

The shell script must be called `run`, must be executable, and is to be placed in the directory `/etc/service/<NAME>`.

Here's an example showing you how a memcached server runit entry can be made.

In `memcached.sh` (make sure this file is chmod +x):

    #!/bin/sh
    # `/sbin/setuser memcache` runs the given command as the user `memcache`.
    # If you omit that part, the command will be run as root.
    exec /sbin/setuser memcache /usr/bin/memcached >>/var/log/memcached.log 2>&1

In `Dockerfile`:

    RUN mkdir /etc/service/30-memcached
    ADD memcached.sh /etc/service/30-memcached/run

Note that the shell script must run the daemon **without letting it daemonize/fork it**. Usually, daemons provide a command line flag or a config file option for that.

<a name="starting_order"></a>
#### Starting order
Daemons are started in lexical order. System services are defined as `10-syslog-ng`, `10-syslog-forwarder` and `20-cron`, so you can define your daemons e.g. starting with 30 to start your daemon after the system services.

<a name="wait_until"></a>
#### Wait until daemon is fully up
You can add a `check` script to make the _Init System_ wait until daemon is fully up.

Example `memcached-check.sh` file:

    #!/bin/bash
    if [ $memcached_is_up = true ]; then
        exit 0
    fi
    exit 1

And in `Dockerfile`:

    ADD memcached-check.sh /etc/service/30-memcached/check

<a name="disable_daemons"></a>
### Disable Daemons
Any daemon can be disabled by adding a `disabled` file to the corresponding service folder.

    RUN touch /etc/service/30-memcached/disabled

<a name="running_startup_scripts"></a>
### Running scripts during container startup

The _ubuntu-baseimage_ init system, `/sbin/my_init`, runs the following scripts during startup, in the following order:

 * All executable scripts in `/etc/my_init.d`, if this directory exists. The scripts are run in lexicographic order.
 * The script `/etc/rc.local`, if this file exists.

All scripts must exit correctly, e.g. with exit code 0. If any script exits with a non-zero exit code, the booting will fail.

The following example shows how you can add a startup script. This script simply logs the time of boot to the file /tmp/boottime.txt.

In `logtime.sh` (make sure this file is chmod +x):

    #!/bin/sh
    date > /tmp/boottime.txt

In `Dockerfile`:

    RUN mkdir -p /etc/my_init.d
    ADD logtime.sh /etc/my_init.d/logtime.sh

<a name="environment_variables"></a>
### Environment variables

If you use `/sbin/my_init` as the main container command, then any environment variables set with `docker run --env` or with the `ENV` command in the Dockerfile, will be picked up by `my_init`. These variables will also be passed to all child processes, including `/etc/my_init.d` startup scripts, Runit and Runit-managed services. There are however a few caveats you should be aware of:

 * Environment variables on Unix are inherited on a per-process basis. This means that it is generally not possible for a child process to change the environment variables of other processes.
 * Because of the aforementioned point, there is no good central place for defining environment variables for all applications and services. Debian has the `/etc/environment` file but it only works in some situations.
 * Some services change environment variables for child processes. Nginx is one such example: it removes all environment variables unless you explicitly instruct it to retain them through the `env` configuration option. If you host any applications on Nginx then they will not see the environment variables that were originally passed by Docker.

`my_init` provides a solution for all these caveats.

<a name="envvar_central_definition"></a>
#### Centrally defining your own environment variables

During startup, before running any [startup scripts](#running_startup_scripts), `my_init` imports environment variables from the directory `/etc/container_environment`. This directory contains files who are named after the environment variable names. The file contents contain the environment variable values. This directory is therefore a good place to centrally define your own environment variables, which will be inherited by all startup scripts and Runit services.

For example, here's how you can define an environment variable from your Dockerfile:

    RUN echo Apachai Hopachai > /etc/container_environment/MY_NAME

You can verify that it works, as follows:

    $ docker run -t -i <YOUR_NAME_IMAGE> /sbin/my_init -- bash -l
    ...
    *** Running bash -l...
    # echo $MY_NAME
    Apachai Hopachai

**Handling newlines**

If you've looked carefully, you'll notice that the 'echo' command actually prints a newline. Why does $MY_NAME not contain a newline then? It's because `my_init` strips the trailing newline, if any. If you intended on the value having a newline, you should add *another* newline, like this:

    RUN echo -e "Apachai Hopachai\n" > /etc/container_environment/MY_NAME

<a name="envvar_dumps"></a>
#### Environment variable dumps

While the previously mentioned mechanism is good for centrally defining environment variables, it by itself does not prevent services (e.g. Nginx) from changing and resetting environment variables from child processes. However, the `my_init` mechanism does make it easy for you to query what the original environment variables are.

During startup, right after importing environment variables from `/etc/container_environment`, `my_init` will dump all its environment variables (that is, all variables imported from `container_environment`, as well as all variables it picked up from `docker run --env`) to the following locations, in the following formats:

 * `/etc/container_environment`
 * `/etc/container_environment.sh` - a dump of the environment variables in Bash format. You can source the file directly from a Bash shell script.
 * `/etc/container_environment.json` - a dump of the environment variables in JSON format.

The multiple formats makes it easy for you to query the original environment variables no matter which language your scripts/apps are written in.

Here is an example shell session showing you how the dumps look like:

    $ docker run -t -i \
      --env FOO=bar --env HELLO='my beautiful world' \
      wingedkiwi/ubuntu-baseimage:<VERSION> bash -l
    ...
    *** Running bash -l...
    # ls /etc/container_environment
    FOO  HELLO  HOME  HOSTNAME  PATH  TERM  container
    # cat /etc/container_environment/HELLO; echo
    my beautiful world
    # cat /etc/container_environment.json; echo
    {"TERM": "xterm", "container": "lxc", "HOSTNAME": "f45449f06950", "HOME": "/root", "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "FOO": "bar", "HELLO": "my beautiful world"}
    # source /etc/container_environment.sh
    # echo $HELLO
    my beautiful world

<a name="modifying_envvars"></a>
#### Modifying environment variables

It is even possible to modify the environment variables in `my_init` (and therefore the environment variables in all child processes that are spawned after that point in time), by altering the files in `/etc/container_environment`. After each time `my_init` runs a [startup script](#running_startup_scripts), it resets its own environment variables to the state in `/etc/container_environment`, and re-dumps the new environment variables to `container_environment.sh` and `container_environment.json`.

But note that:

 * modifying `container_environment.sh` and `container_environment.json` has no effect.
 * Runit services cannot modify the environment like that. `my_init` only activates changes in `/etc/container_environment` when running startup scripts.

<a name="envvar_security"></a>
#### Security

Because environment variables can potentially contain sensitive information, `/etc/container_environment` and its Bash and JSON dumps are by default owned by root, and accessible only by the `docker_env` group (so that any user added this group will have these variables automatically loaded).

If you are sure that your environment variables don't contain sensitive data, then you can also relax the permissions on that directory and those files by making them world-readable:

    RUN chmod 755 /etc/container_environment
    RUN chmod 644 /etc/container_environment.sh /etc/container_environment.json

<a name="upgrading_os"></a>
### Upgrading the operating system inside the container

Upgrading inside the container would violate docker best practices. _ubuntu-baseimage_ is always kept up to date using an [Automated Build](https://hub.docker.com/r/wingedkiwi/ubuntu-baseimage/) on Docker Hub. Simply rebuild your container using this base image.

