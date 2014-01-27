#!/bin/csh

set current = `dirname $0`

if($# == 0) then
  echo "Please input the appname you want to reload static files:"
  set appname=$<
else
    set appname=$1
endif



#copy the static files
sed 's/^/set /g' $current/deploy.properties > $current/deploy.properties.tmp
source $current/deploy.properties.tmp 1> /dev/null
rm -f $current/deploy.properties.tmp

set is_local = ""
if($nginx_server_ip == "localhost" || $nginx_server_ip == "127.0.0.1") then
    set is_local = "local";
endif

set nginx_error = "false"
if($is_local == "local") then
    sudo service nginx test
    if($? != 0) then
        set nginx_error = "true"
    endif
else
    ssh -tq $nginx_server_ip "sudo service nginx test"
    if($? != 0) then
        set nginx_error = "true"
    endif
endif

set static_root = /var/www/$appname
set web_dir = $current/$appname/src/main/webapp

if($is_local == "local") then
    sudo mkdir -p $static_root
    sudo rm -rf $static_root/*
    sudo cp -rf $web_dir/js $static_root/js
    sudo cp -rf $web_dir/css $static_root/css
    sed "s/@appname@/$appname/g" static.conf > /tmp/$appname/static.new
    set static = `cat /tmp/${appname}/static.new`
    sudo sed -i "/#static conf start/a $static" /usr/local/nginx/conf/vhost/$appname.conf
    rm -f /tmp/${appname}/static.new
    sudo service nginx test

    if($nginx_error == "true") then
        echo "local nginx test error, please check the conf files..."
    else
        sudo service nginx reload
    endif
else
    ssh -tq $nginx_server_ip "sudo rm -rf $static_root/*"
    ssh -tq $nginx_server_ip "mkdir -p ~/static"

    rsync -a $web_dir/js ${nginx_server_ip}:~/static
    rsync -a $web_dir/css ${nginx_server_ip}:~/static
    ssh -tq $nginx_server_ip "sudo mkdir -p $static_root;sudo rm -rf $static_root/*;sudo mv -f ~/static/js $static_root/js;sudo mv -f ~/static/css $static_root/css; sudo rm -rf ~/static"
    sed "s/@appname@/$appname/g" $current/static.conf > /tmp/$appname/static.new
    set static = `cat /tmp/${appname}/static.new`
    ssh -tq $nginx_server_ip "sudo sed -i '/#static conf start/a $static' /usr/local/nginx/conf/vhost/${appname}.conf"
    rm -f /tmp/${appname}/static.new
    if($nginx_error == "false") then
        ssh -tq $nginx_server_ip "sudo service nginx reload"
    endif
endif

exit $?
