# API Rest server environment of diolinux
[![Docker Automated build](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](https://hub.docker.com/r/gerardojunior/tap.api.environment)

Docker image to run [phalcon](https://phalconphp.com/) framework projects

> The project must be in the **/usr/local/src** (with "public" folder) folder container folder and will be available on port **:80** of the container

## Tags available

- stable
  - [php](https://php.net): 7.2.5 
  - [apache](https://www.apache.org/): 2.4.33
  - [php mongodb driver](https://docs.mongodb.com/ecosystem/drivers/php/): 1.4.3
  - [phalcon](https://phalconphp.com/): 3.3.2
  - [composer](https://getcomposer.org/): 1.6.5
  - [xdebug](https://xdebug.org/): 2.6.0 **only by rebuilding with arg DEBUG=true*
- latest
  - [php](https://php.net): 7.2.5 
  - [apache](https://www.apache.org/): 2.4.33
  - [php mongodb driver](https://docs.mongodb.com/ecosystem/drivers/php/): 1.4.3
  - [phalcon](https://phalconphp.com/): 3.3.2
  - [composer](https://getcomposer.org/): 1.6.5
  - [xdebug](https://xdebug.org/): 2.6.0 **only by rebuilding with arg DEBUG=true*

## Come on, do your tests

```bash
docker pull gerardojunior/tap.api.environment:stable
```
## How to build

to build the image you need install the [docker engine](https://www.docker.com/) only

> You can try building with different versions of software with docker args, for example: PHP_VERISON=7.2.5

> you can install with [xdebug](https://xdebug.org/) with the argument: DEBUG=true

```bash
git clone https://github.com/gerardo-junior/tap.api.environment.git
cd tap.api.environment
docker build . --tag gerardojunior/tap.api.environment
```

## How to use

##### Only with docker command:

```bash
# in your project folder
docker run -it --rm -v $(pwd):/usr/share/src -p 1234:80 gerardojunior/tap.api.environment:stable [command]
```
##### With [docker-compose](https://docs.docker.com/compose/)

Create the docker-compose.yml file  in your project folder with:

```yml
# (...)

  api: 
    image: gerardojunior/tap.api.environment:stable
    restart: on-failure
    volumes:
      - type: bind
        source: ./
        target: /usr/share/src
    ports:
      - 1234:80
    links:
      - mongodb
    depends_on:
      - mongodb

  mongodb:
    image: mongo:3.6.4
    restart: on-failure
    environment:
      - MONGO_DATA_DIR=/data/db
    volumes:
      - type: volume
        source: dbdata
        target: /data/db
        volume:
          nocopy: true
    command: mongod --smallfiles --logpath=/dev/null

# (...)

volumes:
  dbdata:
    name: "tap-dbdata"

# (...)
```

## How to enter image shell
 
```bash
docker run -it --rm gerardojunior/tap.api.environment /bin/sh

# or with docker-compose
docker-compose run api /bin/sh
```

### License  
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
