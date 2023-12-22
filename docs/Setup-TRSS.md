# TRSS Setup

This page will document the setup of the TRSS service running at [trss.adoptium.net](https://trss.adoptium.net).

## Setup

#### Prerequisites:
- Install [docker and docker-compose-plugin](https://docs.docker.com/compose/install/linux/)
- Install `npm`
- Install [`nginx`](https://www.nginx.com/resources/wiki/start/topics/tutorials/install/)

#### Pre setup recommendations:
- Dedicate a separate disk for `/var/lib/docker` (>30G) and one for the directory in which you kick off the TRSS service (>60G), the latter will be where TRSS stores its data.
- Run the TRSS service with a non root user.

### Before running the service:

#### Connecting to Jenkins

- Before you start the service, create a file named `trssConf.json`. This file will be stored in `aqa-test-tools/TestResultSummaryService/` once you clone the [aqa-test-tools](https://github.com/adoptium/aqa-test-tools) repository.
- This file will contain the credentials needed by the TRSS service to connect to your Jenkins instance. It should look like this:
```
{
	"https://yourjenkinsserver.com": {
		"user" : "abc@example.com",
		"password" : "123"   <=== the value can be token
	}
}
```

#### Nginx config

A basic `/etc/nginx/nginx.conf` should include 
```
include /etc/nginx/sites-enabled/*;
```
which should include a symlink to `/etc/nginx/sites-enabled/defaults`.

The file `/etc/nginx/sites-enabled/defaults` should contain a code block which passes all inbound traffic to `http://localhost:4000`. It should look something like this:
```
    location / {
                proxy_pass http://localhost:4000;
    }
```

`http://localhost:4000` runs another `nginx` service in a docker container. Its purpose is to redirect traffic to the appropriate TRSS docker container.

#### Installing Certbot (requires root access)

To enable `https` install `certbot`. Follow the instructions [here](https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal) or those below:

1. Install [`snapd`](https://snapcraft.io/docs/installing-snapd), may already be installed on Ubuntu

2. Install `certbot` with `snap`
```
snap install --classic certbot
```
3. Prepare `certbot`
```
ln -s /snap/bin/certbot /usr/bin/certbot
```
4. Install certificates
```
certbot --nginx
```

### Steps to run the service

1. Clone the [aqa-test-tools](https://github.com/adoptium/aqa-test-tools) repository and `cd` into it

2. Move the `trssConf.json` file you created [earlier](https://github.com/adoptium/infrastructure/blob/master/docs/Setup-TRSS.md#Connecting-to-Jenkins) into `aqa-test-tools/TestResultSummaryService/`

3. From the top level directory of the repository run `npm run docker &`

4. If your `nginx` configuration is setup correctly, run `nginx -s reload`.

If you would like to stop the service run `npm run docker-down`, then run `docker system prune` before rerunning the service with step 2.

If `npm run docker-down` does not fully stop the service, check which containers of the service are still running and stop them manually with `docker stop`.
