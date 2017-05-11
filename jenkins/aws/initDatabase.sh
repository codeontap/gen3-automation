#!/bin/bash -x

# This script needs work - the content below was just captured here as a starting point
# It is based on  a very old codeontap setup

region="ap-southeast-2"
aws s3 cp s3://configuration.immi01.gosource.com.au/immiaccount/$ENVIRONMENT/cf/solution-${region}-stack.json . --region $region

db_host=`JSON.sh -b < solution-${region}-stack.json |grep -A 1 rdsXdbXmySQLXdns|grep Value|cut -f 2 |xargs`
db_user=`JSON.sh -b < solution-${region}-stack.json |grep -A 1 rdsXdbXmySQLXusername|grep Value|cut -f 2 |xargs`
db_pass=`JSON.sh -b < solution-${region}-stack.json |grep -A 1 rdsXdbXmySQLXpassword|grep Value|cut -f 2 |xargs`
db_name=`JSON.sh -b < solution-${region}-stack.json |grep -A 1 rdsXdbXmySQLXdatabasename|grep Value|cut -f 2 |xargs`
db_port=`JSON.sh -b < solution-${region}-stack.json |grep -A 1 rdsXdbXmySQLXport|grep Value|cut -f 2 |xargs`

rm solution-${region}-stack.json

git clone https://alm%40immi01.gosource.com.au:CTZH3R8tX2BRqYXmm8yj@git.immi01.gosource.com.au/r/immiaccount/$ENVIRONMENT-config.git

cd $ENVIRONMENT-config

if [ -d initialdata ]
  then
    cd initialdata
      for i in `ls`
        do
          mysqlimport -h $db_host -u $db_user -p $db_pass -P $db_port $db_name $i
            if [ "$?" -ne 0 ]
              then
              echo "$i file has been failed to load, exiting..."
              cd ../../
              rm -rf $ENVIRONMENT-config
              exit 1
            fi  
        done
    cd ../
  else
    echo "initialdata directory doesn't exist, exiting..."
fi

cd ../
rm -rf $ENVIRONMENT-config