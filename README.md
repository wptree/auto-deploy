auto-deploy
===========

Java-web-cluster-auto-deployment

This shell/ant script tool will do the following things:
<p>
    <ul>
      <li>Initial the tomcat instance if it does not exist;</li>
      <li>Checkout source coude from svn server;</li>
      <li>Build the source code to war file;</li>
      <li>Deploy the war file to specified tomcat instance;</li>
      <li>Bring up/down tomcat instance;</li>
      <li>Compress js/css files;</li>
      <li>Make nginx reload to take updated static files;</li>
    </ul>
</p>


Features:

<p>
    <ul>
      <li>Auto detect the svn path, support check codes from trunk, branches and tags;</li>
      <li>Support http/https tomcat instance, the tomcat template is configurable;</li>
      <li>Auto create command file under /etc/init.d/ to enable new tomcat instance start/stop as service;</li>
      <li>Support quick re-deployment for both single tomcat instance or tomcat cluster;</li>
      <li>Paring the pom.xml to download the dependency jars from Manven center repository;</li>
      <li>No shutdown in cluster deployment process;</li>
      <li>Support Nginx reload static files manually or automatically;</li>
      <li>Support cross server deployment.</li>
    </ul>
</p>


Useage:
<p>To be filled...</p>
