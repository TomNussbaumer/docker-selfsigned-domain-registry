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

Before you run `create-registry.sh` make sure you have modified the first 4 variables to your requirements. At least replace the "example.com" part of variable CERTIFICATE_DETAILS to match your domain name. Otherwise you will not be able to connect.

Changing the generated user and password is also a good idea ;)

Then run `./create-repository.sh`. This bootstrap everything and start the registry. It will also generate a `ca.crt` file next to the script. 

### Distributing file ca.crt

The drawback of self-signed certificates is, that every Docker host requires the file domain.crt to be installed in a special place. In details you have to copy it here:

```
## replace example.com with your domain name!
/etc/docker/certs.d/example.com:5000/ca.crt
```

Restarting the docker daemon (`service docker restart`) was not even necessary on my side (docker v1.8.1).


## Improvement Number 4: Utility functionalities

This is an incomplete list of possible (and future?) improvements:

  * add another user
  * delete a user
  * generate a new certificate
  * output the ca.crt File again
  * backup and restore

Beside backup, restore and delete a user the rest of the features is already there, but not nicely accessable. Here is a quick and dirty list how to do it yet:

```shell
docker start registry-data
## add a new user
docker exec registry-data add-user the_user_name the_password

# generate a new certificate
docker exec registry-data gen-cert number_of_days CERTIFICATE_DETAILS_string

# output ca.crt again
docker exec -ti registry-data output-cert > ca.crt
docker stop registry-data
```

## Important Notice

This is in no way a production ready piece of software. It's just a proof of concept.


