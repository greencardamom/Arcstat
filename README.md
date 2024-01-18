Arcstat
===========
Arcstat creates statistics of archive URL usage on Wikipedia. The output:

* https://tools-static.wmflabs.org/botwikiawk/dashboard.html

The product is "Dashboard Classic" and the program is "Arcstat".

Overview
==========

Arcstat downloads each article once a month and counts and sums the number of archive URLs. It does an API check to see if the page has been edited since the last check, if not it doesn't download, since no change happened it uses the stats from last month.

By default it is configured for 60 Wikipedia language-sites which represents about 80% of Wikipedia by volume eg. there are about 65 million articles on all Wikipedias, and these 60 sites contain about 50 million articles, or 80% of all the articles.

The task must be broken into at least two VMs. Each VM uses a VPN with its own IP number. 

Setup
==========

I use this setup:

* 1 computer with 24 CPU and 32GB RAM (that is 12 core x2 with hyperthread)

* A VPN provider with at least 2 IPs, preferably with gateways nearby Ashburn, VA where MediaWiki hosts. Low network latency is key.

* Oracle VirtualBox

        Guest additions
        Networking->Bridged adapter

* 2 VMs of 8 CPU and 3 GB RAM each

* VMs and host are Linux Mint (Ubuntu)

* The host is 'argos' and the VMs are 'quepasa' and 'luego'

* In all three machines install BotWikiAwk library:

        cd ~ 
        git clone 'https://github.com/greencardamom/BotWikiAwk'
        export AWKPATH=.:/home/user/BotWikiAwk/lib:/usr/share/awk
        export PATH=$PATH:/home/user/BotWikiAwk/bin
        cd ~/BotWikiAwk
        ./setup.sh
        read SETUP for further instructions like setting up email

* Other software: tcsh (sudo apt-get install tcsh)

* Clone arcstat to ~/arcstatData on argos

        cd ~
        git clone 'https://github.com/greencardamom/Arcstat' arcstatData

* In VirtualBox (VB) create a shared directory for quepasa and luego, where /media/sf_arcstatData maps to /home/user/arcstatData on argos ie. for each quepasa and luego in VirtualBox:

        Settings->Edit->Shared Folders
          Folder path: /home/user/arcstatData
          Folder name: arcstatData
          Checkbox: automount
          Checkbox: make permanent

	In each VM create a directory /home/user/arcstat .. it should contain:

         lrwxrwxrwx 1 user user    29 Jan 13 13:45 app.css -> /media/sf_arcstatData/app.css
         lrwxrwxrwx 1 user user    11 Jan 10 16:39 arcstat -> arcstat.awk
         lrwxrwxrwx 1 user user    33 Jan 13 13:01 arcstat.awk -> /media/sf_arcstatData/arcstat.awk
         lrwxrwxrwx 1 user user    24 Jan 10 16:38 db -> /media/sf_arcstatData/db
         lrwxrwxrwx 1 user user    36 Jan 13 13:45 definearcs.awk -> /media/sf_arcstatData/definearcs.awk
         lrwxrwxrwx 1 user user    33 Jan 13 13:45 footer.html -> /media/sf_arcstatData/footer.html
         lrwxrwxrwx 1 user user    33 Jan 13 13:45 header.html -> /media/sf_arcstatData/header.html
         lrwxrwxrwx 1 user user    31 Jan 10 16:38 iadetails -> /media/sf_arcstatData/iadetails
         lrwxrwxrwx 1 user user    25 Jan 10 16:38 log -> /media/sf_arcstatData/log
         lrwxrwxrwx 1 user user     7 Jan 13 12:49 run -> run.awk
         lrwxrwxrwx 1 user user    29 Jan 13 12:49 run.awk -> /media/sf_arcstatData/run.awk
         lrwxrwxrwx 1 user user    30 Jan 13 13:45 start.db -> /media/sf_arcstatData/start.db
         lrwxrwxrwx 1 user user    39 Jan 13 13:45 table1header.html -> /media/sf_arcstatData/table1header.html
         lrwxrwxrwx 1 user user    39 Jan 13 13:45 table2header.html -> /media/sf_arcstatData/table2header.html
         lrwxrwxrwx 1 user user    39 Jan 13 13:45 templateNames.txt -> /media/sf_arcstatData/templateNames.txt
         lrwxrwxrwx 1 user user    31 Jan 13 13:45 trans.awk -> /media/sf_arcstatData/trans.awk
         lrwxrwxrwx 1 user user    25 Jan 10 16:38 www -> /media/sf_arcstatData/www

	Manually create above symbolic links, in each VM

	The program push.csh on argos is a tcsh script that is called from makehtml.awk .. it pushes the HTML file to Toolforge using rsync. Login to your toolforge web account and setup your ssh credentials for passwordless login, typically copy the contents of ~/.ssh/id_rsa.pub via the Toolforge web interface.
       
	Exe["push"] needs to be defined somewhere so makehtml.awk knows where to find push.csh I prefer defining in ~/BotWikiAwk/lib/syscfg.awk but you could also add the definition in makehtml.awk in the BEGIN{} section. For example add this in either place:

         Exe["push"] = "/home/user/arcstatData/push.csh"

	push.csh contains path-specific information for Toolforge and argos it needs adjustment.

	The files crontab-argos.txt, crontab-quepasa.txt and crontab-luego.txt are the crontabs for each machine. Adjust the paths.

Notes
=========

* There is also an awk program in the ~/db directory called deletename.awk
* Most of the programs contain hard-coded path(s), defined at the top of the program, typically a path to the Home directory. Check each and make the changes.
* The program run.awk can start, stop and view running processes on the VMs. Normally processes are started via cron. 'run -s' shows running processes and progress.
* The file runpage.txt is a list of running processes. If arcstat is killed via "kill pid" this file is used by run.awk to restart. If restarted, arcstat will pick up where it left off during its long run through every page on-wiki.

Credits
==================
by User:GreenC (en.wikipedia.org)

MIT License Copyright 2024

Arcstat uses the BotWikiAwk framework of tools and libraries for building and running bots on Wikipedia

https://github.com/greencardamom/BotWikiAwk
