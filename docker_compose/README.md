# How to Build DayTrader Images
Inside the `docker` folder you will find three Dockerfiles: `Docker-JMeter`, `Dockerfile-DB2` and `Dockerfile-Derby`. `Dockerfile-DB2` and `Dockerfile-Derby`, allows
the user to pick between two different setups for running DayTrader. Currently, DayTrader supports a DB2 based database 
either hosted on Linux or z/OS. Alternatively you can use Derby as a database which runs beside the DayTrader web application. 
For a more *"production"* like environment is recommended to use the DB2 image.

The other Dockerfile in the `docker` folder is `Docker-JMeter`. This Dockerfile builds and runs the JMeter stress test 
against the DayTrader application set up with DB2 or Derby. The build instructions for `Docker-JMeter` are slightly different
as it has unique build arguments that relate to JMeter and not DayTrader.

To build `Dockerfile-DB2` or `Dockerfile-Derby` manually, you can hop into the `docker` folder. Once inside, you can issue a docker build command
like:

```commandline
docker build -f Dockerfile-DB2 -t daytrader:8-openliberty-db2 . --build-arg DAYTRADER_TAG=master --build-arg DAYTRADER_TAG=open-liberty --build-arg LIBERTY_TAG=full --build-arg OPT_PATH=ol
```

Please note this command will build the `open-liberty` based DayTrader image with DB2. 

When building either Docker image there are 4 build arguments you need to be aware of as they will impact the final image.

1. `DAYTRADER_TAG` - This build arg controls which tag/branch the container will pull down for building DayTrader. 
    Currently, all testing has been done with `master` as the DayTrader maintainers have not published a new release yet.
   
2. `DAYTRADER_TAG` - This build arg controls which image DayTrader will run with. The two choices are either `open-liberty`
    or `websphere-liberty`. 
   
3. `LIBERTY_TAG` - This build arg controls which tag of the liberty images you will be using. Please refer to `open-liberty` or 
   `websphere-liberty` official DockerHub pages for more information on tags. The current values we use are `full` for `open-liberty` 
    based images and `kernel` for `websphere-liberty` based images.
   
4. `OPT_PATH` - This build arg needs to be set to either `ol` or `ibm` depending on which liberty image you choose. For 
   `open-liberty` you need to set it to `ol` and for `websphere-liberty` you need to set it to `ibm`
   
To build `Docker-JMeter` you want to be in the root of the repo and not `docker`. Once you in the root of the repo, you can issue
a docker build command like:

```commandline
docker build -f docker/Dockerfile-JMeter . --build-arg JMETER_VERSION=5.3 --build-arg JMETER_PLUGIN_LIST=websocket-samplers
```

There a couple other build arguments inside the JMeter container which you can customize but `JMETER_VERSION` and `JMETER_PLUGIN_LIST`
are the most important. 

**Note: Building images are not needed as we have TravisCI build all the variants of DayTrader, but it can be helpful 
when debugging.**

# Running a DayTrader Application
Currently, we support running the DayTrader application via `docker-compose` and native installation.

## Deploying via Docker-Compose
In the `docker_compose` folder you will fine two folders called: `db2` and `derby`. As the name implies these are different
configurations for deploying either `DB2` or `Derby`. 

In each folder you will fine the main `docker-compose.yml` file along with two folders `config` and `env`. The `config`
folder just holds any needed files/configs for DayTrader to operate. On the other hand `env` contains an environment file
where you can customize parts of the application. Such as database connection details, max number of users and max number
of quotes. 

When deploying `derby` most of these environment variables should be left as default. Currently, the DayTrader application,
at least for Derby, needs certain names for users, passwords, etc. 

When deploying `db2` you can customize the environment variables, so they fit your needs. By default, the `docker-compose` file
is set up to spin up three containers. One for DayTrader, one for JMeter and one for DB2 on Linux. If you wanted to connect to an external
DB2 instance on z/OS or on another Linux host you can remove the db2 section in the `docker-compose.yml` file. You will 
need to set the environment variables to connect with your remote database in the environment file. 

One you have configured the environment file to your liking all you need to do to start the DayTrader application is to
issue:

```commandline
docker-compose up -d
```

You should be able to access the DayTrader UI by visiting `YOUR_IP:9080/daytrader`.

If you want to change the JMX file being ran you can change it in the `env` file for said deployment. Additionally, if you
care about the results of the JMeter run, you can adjust the volume mount in the `docker-compose.yml` file to mount to your system for the `driver` service.
Currently, the results get output to `/tmp/results` on your local system. 
