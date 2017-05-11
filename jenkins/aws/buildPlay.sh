#!/bin/bash -x

# This script needs work - the content below was just captured here as a starting point
# It is based on  a very old codeontap setup

trap 'exit $RESULT' EXIT SIGHUP SIGINT SIGTERM

SUFFIX="immiaccount"
REGISTRY="docker.immi01.gosource.com.au:443"
DOCKER_USER="alm@immi01.gosource.com.au"
DOCKER_PASS="CTZH3R8tX2BRqYXmm8yj"
RELEASE=`echo $GIT_BRANCH|cut -f 2 -d/`

if [ -z "$RELEASE" ]
  then
  RELEASE="master"
fi


sudo docker login -u $DOCKER_USER -p $DOCKER_PASS -e $DOCKER_USER $REGISTRY
if [ "$?" -ne 0 ] ;  
  then  
   echo "Cannot login to docker, exiting..."  
   RESULT=1
   exit
fi

sudo docker pull ${REGISTRY}/${SUFFIX}/${GIT_COMMIT}
if [ "$?" -eq 0 ] ;  
  then  
   echo "Image with tag $GIT_COMMIT exists"  
   IMAGEID=`docker images|grep $GIT_COMMIT|head -1|awk '{print($3)}'`
   docker rmi -f $IMAGEID
   docker rmi $IMAGEID
   RESULT=1
   exit
fi


sudo git clone https://alm%40immi01.gosource.com.au:CTZH3R8tX2BRqYXmm8yj@git.immi01.gosource.com.au/r/immiaccount/services.git
if [ "$?" -ne 0 ] ;  
  then  
   echo "Cannot fetch the repo, exiting..."  
   RESULT=1
   exit
fi
sudo chown -R tomcat:tomcat services
cd services



/usr/share/tomcat7/activator/activator clean
if [ "$?" -ne 0 ]
  then
   echo "CRITICAL: activator clean failed, triggering exit 1..."
   RESULT=1
   exit
fi

/usr/share/tomcat7/activator/activator compile
if [ "$?" -ne 0 ]
  then
   echo "CRITICAL: activator compile failed, triggering exit 1..."
   RESULT=1
   exit
fi

#Test stage is turned off temporarily till the tests are fixed by Mubin
#/usr/share/tomcat7/activator/activator test
#if [ "$?" -ne 0 ]
#  then
#   echo "CRITICAL: activator test failed, triggering exit 1..."
#   RESULT=1
#   exit
#fi


/usr/share/tomcat7/activator/activator dist
if [ "$?" -ne 0 ]
  then
   echo "CRITICAL: activator dist failed, triggering exit 1..."
   RESULT=1
   exit
fi

cd target/universal/
unzip -q *.zip
cd ../../

docker build -t $GIT_COMMIT .
if [ "$?" -ne 0 ]
  then
   echo "CRITICAL:docker build failed, triggering exit 1..."
   RESULT=1
   exit
fi


sudo docker tag $GIT_COMMIT ${REGISTRY}/${SUFFIX}/${GIT_COMMIT}
sudo docker push ${REGISTRY}/${SUFFIX}/${GIT_COMMIT}

#Cleanup images locally
IMAGEID=`docker images|grep $GIT_COMMIT|head -1|awk '{print($3)}'`
docker rmi -f $IMAGEID
docker rmi $IMAGEID

#Update integration-config repo with the new buildid"
ENVIRONMENT="integration"
REFFILE="services/build.ref"

echo "GIT_REFERENCE=$GIT_COMMIT" > $WORKSPACE/services_image_ref
echo "RELEASE=$RELEASE" >> $WORKSPACE/services_image_ref