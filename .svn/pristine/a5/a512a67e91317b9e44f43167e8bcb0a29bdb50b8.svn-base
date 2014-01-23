#!/bin/csh

set current = `pwd`

echo "Please input the appname you want to reload static files:"
set appname=$<

#copy the static files
sed 's/^/set /g' $current/deploy.properties > $current/deploy.properties.tmp
source $current/deploy.properties.tmp 1> /dev/null
rm -f $current/deploy.properties.tmp

set is_local = ""
if($nginx_server_ip == "localhost" || $nginx_server_ip == "127.0.0.1") then
    set is_local = "local";
endif

set static_root = /var/www/$appname
set web_dir = $current/$appname/src/main/webapp
sudo rm -rf $static_root/*
sudo cp -rf $web_dir/js $static_root/js
sudo cp -rf $web_dir/css $static_root/css

#open the static agent
if($is_local == "local") then
    sudo rm -rf $static_root/*
    sudo cp -rf $web_dir/js $static_root/js
    sudo cp -rf $web_dir/css $static_root/css
    sudo sed -i '/include vhost\/static.conf/c include vhost\/static.conf;' /usr/local/nginx/conf/vhost/$appname.conf
    sudo service nginx reload
else
    ssh -tq $nginx_server_ip "sudo rm -rf $static_root/*"
    ssh -tq $nginx_server_ip "mkdir ~/static"

    rsync -av $web_dir/js ${nginx_server_ip}:~/static
    rsync -av $web_dir/css ${nginx_server_ip}:~/static
    ssh -tq $nginx_server_ip "sudo mv -f ~/static/js $static_root/js;sudo mv -f ~/static/css $static_root/css; sudo rm -rf ~/static"
    ssh -tq $nginx_server_ip "sudo sed -i '/include vhost\/static.conf/c include vhost\/static.conf;' /usr/local/nginx/conf/vhost/$appname.conf;sudo service nginx reload"
endif

exit $?
