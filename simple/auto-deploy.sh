#!/bin/csh

if($# == 0 || $1 == "help") then
        echo "Command syntax error"
        echo "Usage: `basename $0` [qa|prod] "
        echo ""
        exit 1
endif

echo "Please input the appname you want to deploy:"
set appname=$<

echo "\n Building Project $appname ..."

set current = `pwd`

rm -rf $current/$appname

if($1 == "qa" || $1 == "prod") then
        rm -f $1.properties
        rm -f $current/build.properties
        sed "s/@appname@/$appname/g" $current/general.properties > $current/build.properties
else
        echo "Only `basename $0` qa|prod is allowed."
        exit 1
endif


echo "Please input the svn target: (head|branch|tag name)"
set target=$<

if($target == "head") then
    set svn_path_target = "trunk"
    set svn_app_path = $appname
else if($target == "branch") then
    set svn_path_target = "branches"
    set svn_app_path = $appname
else 
    set svn_path_target = "tags"
    set svn_app_path = $target 
endif

sed "s/@appname@/$appname/g; s/@target@/$svn_path_target/g; s/@path@/$svn_app_path/g" $current/general.properties > /tmp/temp-build.properties

set build_svn = `grep svn.repository /tmp/temp-build.properties | awk -F= '{printf $2}'`
set build_path =  `echo $build_svn|awk -F"/" '{print $1, $2, $3, $4, $5, $6, $7}' OFS="/"`
set is_path_exist = `svn ls $build_path | grep $svn_app_path`

if($#is_path_exist == 0) then
    echo "the tag dose not exist."
    exit 1
endif

svn export $build_svn/deploy/$1.properties --username pwan --password 123456
sed "s/@instance@/$appname/g" /tmp/temp-build.properties > $current/build.properties
rm -f /tmp/temp-build.properties
echo "\n Building Project $appname from $svn_path_target/$svn_app_path ..."
  
set CATALINA_HOME = /usr/local/$appname

sleep 2

sudo service $appname stop

sleep 5

#Clean history deployment
sudo rm -f $CATALINA_HOME/webapps/$appname.war
sudo rm -rf $CATALINA_HOME/webapps/$appname
#Clean finished

ant -f build.xml -Dtarget=$1

#distribute war to tomcat cluster
sudo cp /home/sdb/deploy/build/$appname.war $CATALINA_HOME/webapps/
echo "Deploy Finished"
sleep 3

sudo service $appname start

rm -f $current/build.properties

sleep 3 

exit $?

