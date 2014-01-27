#!/bin/csh

if($# == 0 || $1 == "help") then
        echo "Command syntax error"
        echo "Usage: `basename $0` [qa|prod] "
        echo ""
        exit 1
endif

set current = `dirname $0`

echo "Please input the appname you want to deploy:"
set appname=$<

if($1 == "qa" || $1 == "prod") then
        rm -f $1.properties
        rm -f $current/build.properties
else
        echo "Illegal input, only "qa","prod" is allowed."
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

sed 's/^/set /g' $current/deploy.properties > $current/deploy.properties.tmp
source $current/deploy.properties.tmp 1> /dev/null
rm -f $current/deploy.properties.tmp

sed "s/@appname@/$appname/g; s/@target@/$svn_path_target/g; s/@path@/$svn_app_path/g" $current/general.properties > /tmp/temp-build.properties

set build_svn = `grep svn.repository /tmp/temp-build.properties | awk -F= '{printf $2}'`
set build_path =  `echo $build_svn|awk -F"/" '{print $1, $2, $3, $4, $5, $6, $7}' OFS="/"`
set is_path_exist = `svn ls $build_path --username $svn_username --password $svn_account | grep $svn_app_path`

#exit if the tag name does not exist
if($#is_path_exist == 0) then
    echo "the tag dose not exist."
    exit 1
endif

#classify the clusters
@ error_count = 0
while(1 == 1)
    if($error_count > 2) then
        echo "you must input something, program is going to quit now."
        exit 1
    endif

    set string = `ls /usr/local | grep ${appname}-node `

    if($#string == 0) then
        echo "please input the cluster instance name you want to deploy: ${appname}-node[0...n] "
    else
        echo "please input the cluster instance name you want to deploy: $string | all"
    endif

    set clusters = ($<)
    
    set not_exist_clusters = ()
    if("x$clusters" == "x") then
        echo "input error."
        @ error_count++
        continue
    endif

    set dir_all = `ls /usr/local`
    if(`echo $clusters[1] | awk '{print tolower($1)}'` == "all") then
        set exist_clusters = ($string) 
    else
        set exist_clusters = ()
        foreach model ($clusters)
            foreach exist ($exist_clusters)
                if($model == $exist) then
                    goto skip
                endif
            end
            @ count = 0 
            foreach var ($dir_all)
                if($model == $var) then
                    set exist_clusters = ($exist_clusters $model)
                    @ count --
                endif
                @ count ++
            end
            if($#dir_all == $count) then
                set not_exist_clusters = ($not_exist_clusters $model)
            endif
            skip:
        end
    endif
    break
end

set is_local = ""
if($nginx_server_ip == "localhost" || $nginx_server_ip == "127.0.0.1") then
    set is_local = "local";
endif

# create not exist clusters
if($#not_exist_clusters != 0) then
    # N(default)：create a http instance; 
    # y: create a https instance; 
    # cancle: do not create any instances.
    echo "do you want to create a https instance[N/y/cancle]:"
    set is_https = $<

    set nginx_path = /usr/local/nginx/conf/vhost

    if(`echo $is_https | awk '{print tolower($1)}'` == "cancle") then
        goto pass
    else if(`echo $is_https | awk '{print tolower($1)}'` == "y") then
        set port_type = "https"
    else 
        set port_type = "http"
    endif
    
    sed "s/@appname@/$appname/g" $current/${port_type}.conf > $current/${appname}.conf.tmp 
    if($is_local == "local") then
        set is_path_exist = `ls $nginx_path | grep ${appname}.conf`
        if($#is_path_exist == 0) then
            sudo mv -f $current/${appname}.conf.tmp $nginx_path/${appname}.conf
            sudo sed -i "s/include files here/include files here\n    include vhost\/$appname.conf;/g" /usr/local/nginx/conf/nginx.conf
        endif
    else
        set is_path_exist = `ssh -tq $nginx_server_ip "ls $nginx_path | grep ${appname}.conf"`
        if($#is_path_exist == 0) then
            rsync $current/${appname}.conf.tmp ${nginx_server_ip}:~/${appname}.conf.tmp
            ssh -tq $nginx_server_ip "sudo mv -f ~/${appname}.conf.tmp $nginx_path/${appname}.conf; sudo sed -i 's/include files here/include files here\n    include vhost\/$appname.conf;/g' /usr/local/nginx/conf/nginx.conf"
        endif
    endif
    rm $current/${appname}.conf.tmp
endif

foreach new_app ($not_exist_clusters)
    mkdir /tmp/$appname
    set new_tomcat = /tmp/$appname/${new_app}
    
    sed 's/^/set /g' $current/deploy.properties > $current/deploy.properties.tmp
    source $current/deploy.properties.tmp
    rm -f $current/deploy.properties.tmp

    if($port_type == "https") then
        cp -rf $tomcat_https_template $new_tomcat
    else
        cp -rf $tomcat_template $new_tomcat
    endif

    sed -i "s/@http.port@/$http_port/g; s/@https.port@/$https_port/g; s/@server.port@/$server_port/g; s/@connector.port@/$connector_port/g; s/@appname@/$appname/g" $new_tomcat/conf/server.xml
    sed -i "s/@appname@/$new_app/g" $new_tomcat/bin/setenv.sh $new_tomcat/lib/pkgconfig/tcnative-1.pc $new_tomcat/bin/myshutdown.sh
    
    echo "**************************************************************" 
    echo "*******  Initing a $port_type instance:  $new_app  ***********" 
    echo "**************************************************************" 
    
    if($port_type == "https") then
        set port = $https_port
    else
        set port = $http_port
    endif

    set repeat_port = `grep $new_app $current/cluster.instance`

    if($#repeat_port == 0 || $? != 0) then
        echo "$new_app=$port" >> $current/cluster.instance
    else
        sed -i "/$new_app=/c $new_app=$port" $current/cluster.instance
    endif

    sudo mv -f $new_tomcat /usr/local/$new_app 
    sudo chown -R tomcat:tomcat /usr/local/$new_app 
    sudo chkconfig --add $new_app
    sudo chkconfig --level 2345 $new_app on
    
    sed "s/@http.port@/$http_port/g; s/@appname@/$new_app/g" $service_template > $current/service.tmp
    sudo mv -f $current/service.tmp /etc/init.d/$new_app
    sudo chmod a+x /etc/init.d/$new_app
    
    awk -F= '{if($1 ~ /port/) print $1,$2+1 > "deploy.properties";else print $1,$2 > "deploy.properties"}' OFS="=" $current/deploy.properties

    if($is_local == "local") then
        sudo sed -i "s/upstream $appname {/upstream $appname {\n    server 127.0.0.1:$port weight=1;/g" /usr/local/nginx/conf/vhost/$appname.conf
    else
        set remote_ip = `/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
        ssh -tq $nginx_server_ip "sudo sed -i 's/upstream $appname {/upstream $appname {\n    server ${remote_ip}:${port} weight=1;/g' /usr/local/nginx/conf/vhost/$appname.conf"
    endif

    set exist_clusters = ($exist_clusters $new_app)

end

pass:

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


# reload nginx , effect the new added clusters
if($#not_exist_clusters != 0) then
    if($is_local == "local") then
        sudo service nginx test

        if($nginx_error == "true") then
            echo "local nginx test error, please check the conf files..."
        else
            sudo service nginx reload
        endif
    else
        ssh -tq $nginx_server_ip "sudo service nginx test"

        if($nginx_error == "true") then
            echo "remote ${nginx_server_ip} nginx test error, please check the conf files..."
        else
            ssh -tq $nginx_server_ip "sudo service nginx reload"
        endif
    endif
else if($#exist_clusters == 0) then
    echo "no instance. the deploy program quits."
    exit 1
endif


sed "s/@instance@/$exist_clusters[1]/g" /tmp/temp-build.properties > $current/build.properties
rm -f /tmp/temp-build.properties
echo "\n Building Project $appname from $svn_path_target/$svn_app_path ..."

svn export $build_svn/deploy/$1.properties --username $svn_username --password $svn_account
  
ant -f $current/build.xml -Dtarget=$1
rm -f $current/build.properties

#stop the static nginx agent
if($is_local == "local") then
    #sudo sed -i "/include vhost\/static.conf/c #include vhost\/static.conf;" /usr/local/nginx/conf/vhost/$appname.conf
    @ startline = `sed -n '/#static conf start/=' /usr/local/nginx/conf/vhost/${appname}.conf | tr -d '\r\n'`
    @ endline = `sed -n '/#static conf end/=' /usr/local/nginx/conf/vhost/${appname}.conf | tr -d '\r\n'`

    if($startline == 0 || $endline == 0) then
    	echo "/usr/local/nginx/conf/vhost/${appname}.conf is invalid; please add static start/end flag."
    	exit 1
    endif

    @ startline ++
    @ endline --

    if($endline >= $startline) then
    	sed -i "${startline},${endline}d" /usr/local/nginx/conf/vhost/${appname}.conf
    endif
    
    if($nginx_error == "false") then
        sudo service nginx reload
    endif
else
    @ startline = `ssh -tq $nginx_server_ip "sed -n '/#static conf start/=' /usr/local/nginx/conf/vhost/${appname}.conf" | tr -d '\r\n'`
    @ endline = `ssh -tq $nginx_server_ip "sed -n '/#static conf end/=' /usr/local/nginx/conf/vhost/${appname}.conf" | tr -d '\r\n'`

    if($startline == 0 || $endline == 0) then
    	echo "/usr/local/nginx/conf/vhost/${appname}.conf is invalid; please add static start/end flag."
    	exit 1
    endif

    @ startline ++
    @ endline --
    if($endline >= $startline) then
    	ssh -tq $nginx_server_ip "sudo sed -i '${startline},${endline}d' /usr/local/nginx/conf/vhost/${appname}.conf"
    endif
    if($nginx_error == "false") then
        ssh -tq $nginx_server_ip "sudo service nginx reload"
    endif
endif

# start all the clusters
foreach app ($exist_clusters)
    set CATALINA_HOME = /usr/local/$app

    sudo service $app stop

    sleep 5

    #Clean history deployment
    sudo rm -rf $CATALINA_HOME/webapps/$appname*
    sudo rm -f $CATALINA_HOME/logs/*
    #Clean finished

    #distribute war to tomcat cluster
    sudo cp $current/build/$appname.war $CATALINA_HOME/webapps/

    sleep 5

    sudo service $app start
    
    echo "waiting for $app start..."
    sleep 5
    set port = `grep $app= $current/cluster.instance | awk -F= '{printf $2}'`

    # test starting suc.
    if($#exist_clusters == 1) then
        continue
    endif

    while(1 == 1)
        sleep 5
        @ http_status_code = `curl -s -o /dev/null -I -w '%{http_code}' http://localhost:${port}/$appname`
        @ https_status_code = `curl -s -k -o /dev/null -I -w '%{http_code}' https://localhost:${port}/$appname`
        @ status_code = ${http_status_code} + ${https_status_code}
        if($status_code < 400 && $status_code > 0) then
            echo "Ping localhost:$port/$appname ===> status: $status_code  ${app}: suc"
            break
        endif
        echo "Ping localhost:$port/$appname ===> status: $status_code, try accessing after 5s......"
    end
    echo "Deploy $appname at $app  finished"
end

if($clusters[1] == "all" || $clusters[1] == "ALL") then
    
    #copy the static files
    set static_root = /var/www/$appname 
    set web_dir = $current/$appname/src/main/webapp

    #open the static agent
    if($is_local == "local") then
        sudo mkdir -p $static_root
        sudo rm -rf $static_root/*
        sudo cp -rf $web_dir/js $static_root/js
        sudo cp -rf $web_dir/css $static_root/css
        sed "s/@appname@/$appname/g" static.conf > /tmp/$appname/static.new
        set static = `cat /tmp/${appname}/static.new`
        sudo sed -i "/#static conf start/a $static" /usr/local/nginx/conf/vhost/$appname.conf

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
endif

echo "Auto deploy $appname finished"

exit $?
