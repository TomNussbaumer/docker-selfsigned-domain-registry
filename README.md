# Automatically setup a self-signed Docker Domain Registry

Setting up a self-signed Docker Domain Registry is cumbersome. There are many steps involved like generating a certificate, moving the files around, setting up authentication and so on. Couldn't this be nicely packaged up with just a minimum on configuration effort?

**Well, yes, it can.**

First of all: [here](https://github.com/docker/distribution/blob/master/docs/deploying.md) and [here](https://github.com/docker/distribution/blob/master/docs/insecure.md) are the manual step explained. Give it at least a quick read to understand what's going on.

## Improvement Number 1: Separating the Data Volume from the Registry

If you don't know what Data Volumes are, read [this](https://docs.docker.com/userguide/dockervolumes/) first.

Most of the official demos of the various features of Docker are too much simplied when it comes down to data volumes. That's a real pity, because you will ron into troubles much sooner than you think.

Let's explain the problem in regards to the Registry. If not set up differently the Registry will automatically generate a data volume mounted at `/var/lib/registry`. This data volume will live as long the registry container lives. If the registry gets destroyed, the data volume is also gone. Well, not really gone, but you will have no direct access anymore to the data volume. It's an orphan.

The only way to get at least the data back is manually search it in /var/lib/docker/volumes.

There real pity here is, if the data volume is directly bound to the software container, you cannot update the software container without loosing the data volume (or without exporting and importing).

The solution is to separate the data volume from the software container. Here is a simple example:

```shell
## this busybox container creates the data volume and functions as reference holder
docker run --name=data-container -dti -v /var/lib/registry busybox sh
## it's not necessary that it is running
docker stop data-container

## the registry container doesn't create the data volume anymore
## you are free to destroy it and use another version without loosing the data container
docker run -d --volume-from=data-container -v 5000:5000 registry:2.1.1 .... more parameters ....
```

The busybox container here functions as pure reference holder. It could also contain no OS at all, but by using a small linux distro you get a kind of swiss knife which can be used for all kind of utility operations like to backup the data volume and similiar. That's the reason it was generated with interactive terminal settings and command sh.

Whenever you want to explore the container (or make a backup), just start the container and attach or run some command via `docker exec`. 

Simple and useful.

## Improvement Number 2: Keep all the Data in one Place

The demo from the official Docker project stores the certificate files and the htpasswd file for user authentication on the host's local filesystem and uses bind mounts. **This is again an Anti Pattern.**

Data should be always stored in Data Volumes, not via bind mounts somewhere else.

Since the Registry has already a Data Volume, it make sense that the certification files and the htpasswd file gets also stored there. Of course we could use an additional Data Volume, but for this demo I want to keep things simple: one service (the registry) and one Data Volume. This way it's also easy to backup everything and/or transfer it to another server.

The certificate files will be stored in `/var/lib/registry/certs` and the authorization file in `/var/lib/registry/auth`. 

## Improvement Number 3: Automate the whole Shebang

Well, there is not much to say about the automation part. It's just boring scripting. 

Before you run `create-registry.sh` make sure you have modified the configuration in file `settings` to your requirements. At least replace the "example.com" part of variable CERTIFICATE_DETAILS to match your domain name. Otherwise you will not be able to connect.

Changing the generated user and password is also a good idea ;)

Then run `./create-repository.sh`. This bootstrap everything and start the registry. It will also generate a `ca.crt` file next to the script. 

### Distributing file ca.crt

The drawback of self-signed certificates is, that every Docker host requires the file domain.crt to be installed in a special place. In details you have to copy it here:

```
## replace example.com with your domain name!
/etc/docker/certs.d/example.com:5000/ca.crt
```

Restarting the docker daemon (`service docker restart`) was not even necessary on my side (docker v1.8.1).

## Improvement Number 4: Utility methods

Script `control-registry.sh` implements various utility methods related to the registry.

```shell
USAGE: ./control-registry.sh command [command-options]
       utility methods for running the registry

commands:

  help                           ... print this page
  start                          ... starts registry
  stop                           ... stops registry
  pause                          ... pauses registry
  unpause                        ... unpauses registry
  restart                        ... restarts registry to pickup changes
  adduser <username> <password>  ... add a new authorized user
  deluser <username>             ... delete an authorized user
  outauth <filename>             ... outputs htpasswd file (use '-' for stdout)
  backup  <filename>             ... backup to tarfile (use '-' for stdout)
  restore <filename>             ... restore from tarfile (use '-' for stdin)
  outcrt  <filename>             ... outputs certificate (use '-' for stdout)
  setup-new-cert                 ... configures registry with new cert
                                     this will automatically generate a new 
                                     ca.cert file along this script

## examples for backup and restore (with files or through piping)

./control-registry.sh backup backup.tar      # directly writing to pipe
./control-registry.sh backup - | tar t       # pipe it to tar to view content

./control-registry.sh restore backup.tar          # restore from file
cat backup.tar | ./control-registry.sh restore -  # restore via pip
```

## What's missing?

Feature-wise I think it's more or less complete, but it can still be, of course, improved.

### Possible (and future?) improvements

  1. **Move everything into containers:** Yet you'll need commandline access to the host which is nice for demonstration but doesn't really work in a cloud environment. By packaging everything into containers it would become cloud-ready.
  2. **Access to start parameters of registry:** Yet the registry is started with hardcoded parameters. Some are required (path to certs, for example), others are just a 'good guess'. IMHO all possible start parameters should be accessible through an external configuration mechanism (file or environment variables).
  3. **Support for a REAL certificate:** Yeah, I hear you ...
  4. **Tests, tests, tests:** Yeap, - actually there is no test suite
  5. **Load balancing support:** would be also a nice feature ...
  6. **Different storage backends:** ... of course, a must have for a real solution.

## Important Notice

This is in no way a production ready piece of software. It's just a proof of concept.

