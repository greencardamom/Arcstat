Arcstat
===========
Arcstat creates a table showing the number of archive URLs currently on Wikipedia, seen here:

* https://tools-static.wmflabs.org/botwikiawk/dashboard.html

The product is "Dashboard Classic" and the program is "Arcstat".

Overview
==========

Arcstat downloads each article on each wiki once a month and counts and sums the number of archive URLs. 

By default it is configured for 60 Wikipedia language-sites, which represents about 80% of Wikipedia by volume eg. as of January 2024, there are about 65 million articles on all Wikipedias, and these 60 sites contain about 50 million articles, or 80% of the total.

The task strains both CPU and API. It needs at least two VMs. Each VM requires a VPN with its own IP number. 

The program is entirely MediaWiki API, it can run from any location and computer(s).

Requirements
============
* A computer with at least 16 CPU and 16GB RAM. Or multiple computers with a shared a directory.
* VirtualBox although it is possible to use other VM software, these instructions are for VB.
* A VPN provider
* An account on Toolforge (WikiMedia)

Setup
==========

I run with the following setup:

* 1 computer with 24 CPU and 32GB RAM (that is 12 core x2 with hyperthread)

* A VPN provider with at least 2 IPs, preferably with gateways nearby Ashburn, VA where MediaWiki hosts. Ask me which. 

* Install 2 VMs in VirtualBox, allocating 6 to 8 CPU and 3 GB RAM each. I prefer Linux Mint (Ubuntu).

* The host is 'argos' and the VMs are 'quepasa' and 'luego'

* VirtualBox setup for the guests:

        Guest additions
        Networking->Bridged adapter
        Adapter type->virtio

* On argos, clone arcstat to ~/arcstatData

        cd ~
        git clone 'https://github.com/greencardamom/Arcstat' arcstatData

* In VirtualBox create a shared directory for quepasa and luego, where /media/sf_arcstatData maps to /home/user/arcstatData on argos ie. for each quepasa and luego in VirtualBox:

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
         lrwxrwxrwx 1 user user    24 Jan 10 16:38 crontab-argos.txt -> /media/sf_arcstatData/crontab-argos.txt
         lrwxrwxrwx 1 user user    24 Jan 10 16:38 crontab-luego.txt -> /media/sf_arcstatData/crontab-luego.txt
         lrwxrwxrwx 1 user user    24 Jan 10 16:38 crontab-quepasa.txt -> /media/sf_arcstatData/crontab-quepasa.txt
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

* In all three machines install BotWikiAwk library:

        cd ~ 
        git clone 'https://github.com/greencardamom/BotWikiAwk'
        export AWKPATH=.:/home/user/BotWikiAwk/lib:/usr/share/awk
        export PATH=$PATH:/home/user/BotWikiAwk/bin
        cd ~/BotWikiAwk
        ./setup.sh
        read SETUP for further instructions eg. setting up email

* Other software: tcsh (sudo apt-get install tcsh) on argos

* The program push.csh on argos is a tcsh script that is called from makehtml.awk .. it pushes the HTML file to Toolforge using rsync. Login to your toolforge web account and setup your ssh credentials for passwordless login, typically copy the contents of ~/.ssh/id_rsa.pub to the Toolforge web interface.
       
	Exe["push"] needs to be defined somewhere so makehtml.awk knows where to find push.csh I prefer defining in ~/BotWikiAwk/lib/syscfg.awk but you could also add the definition in makehtml.awk in the BEGIN{} section. For example add this in either place:

         Exe["push"] = "/home/user/arcstatData/push.csh"

	push.csh contains path-specific information for Toolforge and argos, it will require adjustment.

* Most of the programs contain hard-coded path(s), defined at the top of the program, typically for the Home directory. Check each .awk and .csh file

        There are hard coded paths in the hash-bang first line of each program, for awk and tcsh .. adjust these or make symlinks
        There are hard coded paths in some @include statements in arcstat.awk and makehtml.awk .. adjust these
        There are hard coded paths in ~/db/deletename.awk for external program paths .. adjust these

* Startup the crontabs for each machine. First modify the paths in the crontab-*.txt files. For example while logged into luego run:

        nano -w /media/sf_arcstatData/crontab-luego.txt  (modify the paths)
        crontab /media/sf_arcstatData/crontab-luego.txt

How it works
=========
Once a month, for a given wiki, arcstat.awk downloads a list of all article titles that are currently in existence. It iterates through this list downloading the page, parsing, counting and summing the number of links. The stats are saved to a cache file, so future runs of arcstat remember the stats - in case the page is unchanged since the last run, it doesn't need to download and parse it again. When complete, the total results are summed and saved to ~/db/master.db which is 1 line for 1 run (month) for 1 wiki site. Once a day or so, makehtml.awk takes as input master.db and formats the HTML page and uploads the results to Toolforge, via push.csh

The program is designed to fail well. If the process is killed or the computer reboots, it will pick up where it left off. Because it can take weeks to complete large wikis it is essential, versus starting from the beginning.

Notes
=========

* There is also an awk program in the ~/db directory called deletename.awk
* The program run.awk can start, stop and view running processes on the VMs. Normally processes are started via cron. 'run -s' shows running processes and progress.
* The file runpage.txt is a list of running processes. If arcstat stops this file is used by run.awk to restart. If restarted, arcstat will pick up where it left off during its long run through every page on-wiki.

Credits
==================
by User:GreenC (en.wikipedia.org)

MIT License Copyright 2024

Arcstat uses the BotWikiAwk framework of tools and libraries for building and running bots on Wikipedia

https://github.com/greencardamom/BotWikiAwk
