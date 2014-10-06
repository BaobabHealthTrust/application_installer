#!/bin/bash
# check if stacktrace is passed and set it to true
# stacktrace gives useful debug information
set -x

# set colors and message
red='\e[0;31m'
green='\e[0;32m'
NC='\e[0m'
MSG="and run $0 [ ENVIRONMENT SITE SU_PASSWORD] again"
ENV=$1
SITE=$2

# check if application requirements file is available then set it  
if [ ! -f config/app_requirements.yml ] ; then
	cp config/app_requirements.yml.example config/app_requirements.yml
fi
   
# read application configuration file
IFS=$'\n' read -d '' -r -a requirements < config/app_requirements.yml

# initialize variables
RB_VERSION=`echo "${requirements[0]}" | cut -d':' -f2`
RG_VERSION=`echo "${requirements[1]}" | cut -d':' -f2`
DB_NAME=`echo "${requirements[2]}" | cut -d':' -f2`
BD_VERSION=`echo "${requirements[3]}" | cut -d':' -f2`

#### check already installed requirements
   
#check for ruby version
RB_INSTALLED_VERSION=`echo "$(ruby -e 'print RUBY_VERSION')"` 

#check for rubygems version
RG_INSTALLED_VERSION=`echo "$(gem -v)"`

#check for mysql
if [ -f /etc/init.d/mysql* ]; then
    FIRST_DB_INSTALLED_NAME='mysql'
else 
    FIRST_DB_INSTALLED_NAME='mysql not installed'
fi

#check for couchdb
if [ -f /usr/bin/couchdb ]; then
    SECOND_DB_INSTALLED_NAME='couchdb'
else 
    SECOND_DB_INSTALLED_NAME='couchdb not installed'
fi

#check for bundler gem
BUNDLER_INSTALLED_VERSION=`echo "$(gem list -i bundler --version $BD_VERSION)"`
if $BUNDLER_INSTALLED_VERSION; then
    BD_INSTALLED_VERSION=$BD_VERSION
else 
    BD_INSTALLED_VERSION='not correct version'
fi

#check if nginx is installed
if [ -f /opt/nginx/conf/nginx.conf ] || [ -f /usr/nginx/conf/nginx.conf ] || [ -f /etc/nginx/conf/nginx.conf ]; then
    echo "Nginx installed"
else 
    echo -e "${red}Nginx not installed${NC}"
    echo "Please install nginx with passenger $MSG"
    echo "Run sudo apt-get install passenger to install passenger then run"
    echo "Run sudo passenger-install-nginx-module to install nginx"
    exit 0
fi 
    
#compare installed ruby with specified ruby
if [ "$RB_VERSION" == "$RB_INSTALLED_VERSION" ] ; then
    echo "ruby $RB_INSTALLED_VERSION already installed"
else 
    echo -e "${red}ruby $RB_VERSION not installed${NC}"
    echo "Please install ruby $RB_VERSION $MSG"
    echo "Install ruby using ruby-install,rvm or rbenv"
    echo "Follow either of these"
    echo "ruby-Install: https://github.com/postmodern/ruby-install"
    echo "rvm: http://rvm.io/"
    echo "rbenv: https://github.com/sstephenson/rbenv"
    exit 0
fi
#compare installed rubygems with specified rubygems
if [ "$RG_VERSION" == "$RG_INSTALLED_VERSION" ] ; then
    echo "rubygems $RG_INSTALLED_VERSION already installed"
else 
    echo -e "${red}rubygems $RG_VERSION not installed${NC}"
    echo "Please install rubygems $RG_VERSION $MSG"
    echo "Run sudo apt-get install rubygems to install rubygems"
    echo "The run sudo apt-get update rubygems=$RG_VERSION"
    exit 0
fi

#compare installed databases with specified database
if [ "$FIRST_DB_INSTALLED_NAME" == "$DB_NAME" ] || [ "$SECOND_DB_INSTALLED_NAME" == "$DB_NAME" ] ; then
    echo "$DB_NAME database already installed"
else 
    echo -e "${red}$DB_NAME database not installed${NC}"
    echo "Please install $DB_NAME database $MSG"
    if ["$DB_NAME"=='mysql']; then
        echo "run sudo apt-get install mysql-client mysql-server"
    fi
    
    if ["$DB_NAME"=='couchdb']; then
        echo "run sudo apt-get install couchdb"
    fi
    
    exit 0
fi

#compare bundler versions
if [ "$BD_VERSION" == "$BD_INSTALLED_VERSION" ] ; then
    echo "bundler $BD_VERSION already installed"
else 
    echo -e "${red}bundler $BD_VERSION not installed${NC}"
    #installing bundler
    echo 'Installing now'
    BN_INSTALL=`echo "$(gem install bundler -v $BD_VERSION)"`
    echo "Successfully installed bundler-$BD_VERSION"
fi

###installing application dependencies and gems
#installing application dependencies
echo 'Installing application dependencies'
DP_INSTALL=`echo "$3" | sudo -S apt-get -y install build-essential libopenssl-ruby git-core libmysql-ruby libmysqlclient-dev libxslt-dev libxml2-dev`
echo "$DP_INSTALL"
echo 'Finished installing application dependencies'
#installing gems   
echo 'Installing required gems'
BD_INSTALL=`bundle install`
echo 'Finished installing gems'

#setting up database and application
if [ "mysql" == "$DB_NAME" ] ; then
    usage(){
        echo "Usage: $0 ENVIRONMENT SITE SU_PASSWORD STACKTRACE=true"
        echo
        echo "ENVIRONMENT should be: development|test|production"
    } 

    if [ -z "$ENV" ] || [ -z "$SITE" ] ; then
        usage
        exit 0
    fi

    if [ ! -f config/database.yml ] ; then
        cp config/database.yml.example config/database.yml
    fi
  
  USERNAME=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['username']"`
  PASSWORD=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['password']"`
  DATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['database']"`

  #echo "DROP DATABASE $DATABASE;" | mysql --user=$USERNAME --password=$PASSWORD
  #echo "CREATE DATABASE $DATABASE;" | mysql --user=$USERNAME --password=$PASSWORD

  #mysql --user=$USERNAME --password=$PASSWORD $DATABASE < db/initialization_script

  #check the database initialization script
  if [ -f script/initial_database_setup.sh ]; then
      echo "database initialization"
       RAILS_ENV=${ENV}
       ./script/initial_database_setup.sh ${ENV} ${SITE}

       bundle exec rake db:migrate
  else
    if [ -f bin/initial_database_setup.sh ]; then
      RAILS_ENV=${ENV}
       ./bin/initial_database_setup.sh ${ENV} ${SITE}

       bundle exec rake db:migrate
    fi
  fi

  ###to be done
  
  ##echo bundle exec rake db:migrate
  
elif [ "couchdb" == "$DB_NAME" ] ; then
    rake dde:setup
    echo "Succesfully created and configured couchdb database"
else 
    exit 0
fi

if [ -f config/application.yml.example ] && [ ! -f config/application.yml ]; then
  cp config/application.yml.example config/application.yml
  echo 'Please set your application settings in config/application.yml'
fi

if [ -f /opt/nginx/conf/nginx.conf ]; then
    echo 'Please set your application configuration in /opt/nginx/conf/nginx.conf'
fi

if [ -f /usr/nginx/conf/nginx.conf ]; then
  echo 'Please set your application configuration in /usr/nginx/conf/nginx.conf'
fi

if [ -f /etc/nginx/conf/nginx.conf ]; then
  echo 'Please set your application configuration in /etc/nginx/conf/nginx.conf'
fi

echo 'Succesfully finished setting up your application'
