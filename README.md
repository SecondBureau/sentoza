# Sentoza

***Sentoza*** install and deploy rails applications on AWS Beijing.

****

## Prerequisites

* NGinx
* Puma
* User `deploy`

## Install

### Clone repository

    git clone https://github.com/SecondBureau/sentoza.git

### Generate config file

	cd sentoza
	sentoza g config [options]
	
example :

	bin/sentoza g config -a myapp -s staging -R user/repo -b master -v staging.myhost.org -n myapp_stagging -u deploy:secret -H fff.rds.cn-north-1.amazonaws.com.cn  --replace
	
for details, use	
    
    sentoza g config -h 

### Config applications

You can also edit the `YAML` file
 
    nano config/sentoza.yml

**params**

    myapp:
      github: 
        repository: my_user/my_repository
        remote:     'origin'
      stages:
        production:
        	branch: production
        	vhost: example.com
        	db:
        	  name:
        	  username:
        	  password:
        	  hostname:
        	  port:
        staging: 
        	branch: master
        	vhost: staging.example.com
        	db:
        	  name:
        	  username:
        	  password:
        	  hostname:
        	  port:
        

### NGinx Vhosts

	sentoza g nginx

## Available commands


### Install

***Sentoza*** will create 

- deploy
- rbenv

**Prerequisites**


**Syntax**

    Sentoza install my_app

**rbenv**

`install` command will generate `.rbenv-vars` in the rails directory

    # POSTGRESQL 
	DB_NAME:     db_name
	DB_USERNAME: db_username
	DB_PASSWORD: db_secret
	DB_HOSTNAME: localhost
	DB_PORT:     5432

	# RAILS
	SECRET_KEY_BASE:          # generate with rake secret
	RAILS_ENV:                production
	RAILS_SERVE_STATIC_FILES: true
	
	# puma
	WEB_CONCURRENCY: 2  # one per cpu
	MAX_THREADS: 5
	
	# Server 
	IP: 1.2.4.5 # public ip

