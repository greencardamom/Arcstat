#!/usr/bin/awk -bE

#
# Generate archive statistics
# https://tools-static.wmflabs.org/botwikiawk/arcstat.html
# /data/project/botwikiawk/www/static/arcstat.html
#

# The MIT License (MIT)
#
# Copyright (c) 2019 by User:GreenC (at en.wikipedia.org)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

BEGIN { # Bot cfg

  _defaults = "home      = /home/greenc/toolforge/arcstat/ \
               email     = dfgf56greencard93@nym.hush.com \
               version   = 1.0 \
               copyright = 2024"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
  BotName = "arcstat"
  Home = G["home"]
  Agent = "Ask me about " BotName " - " G["email"]
  Engine = 3

  IGNORECASE = 1

}

@include "botwiki.awk"
@include "library.awk"
@include "json.awk"

@include "/home/greenc/toolforge/arcstat/definearcs.awk"  # load R[] with archive definitions
@include "/home/greenc/toolforge/arcstat/trans.awk"       # load R[] with translation definitions

#
# File descriptions:
#
#   ~/db/en.wikipedia.org.allpages.db        - raw list of all article names (5.5M). Rebuilt once all names are processed.
#   ~/db/en.wikipedia.org.index.db           - same as allpages but with additional info as discovered by bot. This is from the LAST run not the current.
#      name ---- date ---- 0|0|0|0           - date is date checked. Numbers are number of links in that article. See below for order meaning
#   ~/db/en.wikipedia.org.journal.db         - same as index.db but from the CURRENT run thus under construction. When done, it will be renamed .index.db
#   ~/db/en.wikipedia.org.journal-offset.db  - rather than appening 1 line per loop in journal.db, we append them here, then every P["blsize"] lines append this to journal.db and start offset over
#   ~/db/en.wikipedia.org.master.db          - summary results table used to build front-end
#
#   ~/log/en.wikipedia.org.allpages.done     - batch numbers and running total of P["numbers"]
#      50-100 date8 0|0|0|0
#   ~/log/en.wikipedia.org.allpages.offset   - last article number processed from the batch in allpages.done
#      456 0|0|0|0
#

BEGIN {

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "h:d:")) != -1) {
      opts++
      if(C == "h")                 #  -h <hostname>   Hostname eg. "en"
        Hostname = verifyval(Optarg)
      if(C == "d")                 #  -d <domain>     Domain eg. "wikipedia.org"
        Domain = verifyval(Optarg)
  }

  if(opts == 0 || empty(Domain) || empty(Hostname) ) {
    print "Problem with arguments"
    exit(0)
  }

  delete P
  P["log"] = G["home"] "log/"               # journal logging
  P["db"]  = G["home"] "db/"                # article name database files
  P["iadetails"]  = G["home"] "iadetails/"  # dump of archive/org/details links
  P["key"] = Hostname "." Domain
  P["zeros"] = "0|0|0|0|0|0|0|0|0|0|0|0|0|0|0"
  P["numbers"] = P["zeros"]  # intialize
  P["runlog"] = G["home"] "runlog.txt"

  P["blsize"] = 10000

  # batch mode. 0 = for testing small batch or single page.
  #             1 = for production of allpages.db
  # If BM = 0, further adjustments needed below
  P["BM"]       = 1

  main()

}

function main() {

  if( isRunning() )  # Check prior to anything else
    exit

  if( startup() ) 
    runSearch()

  runlog("remove")

}

#
#
#
function startup() {

  delete R
  loadarcs() # from definearcs.awk into R[]

  runlog("add")

  if(!checkexists(P["log"]))
    sys2var(Exe["mkdir"] " " P["log"])
  if(!checkexists(P["iadetails"]))
    sys2var(Exe["mkdir"] " " P["iadetails"])
  if(!checkexists(P["db"]))
    sys2var(Exe["mkdir"] " " P["db"])
  if(!checkexists(P["db"] "masterbak/"))
    sys2var(Exe["mkdir"] " " P["db"] "masterbak")

  if(checkexists(P["db"] P["key"] ".index.db.gz"))
    sys2var(Exe["gunzip"] " " P["db"] P["key"] ".index.db.gz")
  if(checkexists(P["db"] P["key"] ".iadetails.db.gz"))
    sys2var(Exe["gunzip"] " " P["db"] P["key"] ".iadetails.db.gz")

  if(! loadtrans(Hostname, Domain)) { # from trans.awk into R[]
    parallelWrite("Error in loadtrans() for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    return 0
  }

  # Download allpages.db if missing
  if( newallpages() ) {

    # Flush .journal-offset.db if exists
    flushjournal()

    # Flag if index.db exists, needed info later
    if (checkexists(P["db"] P["key"] ".index.db") )
      P["index"] = 1
    else
      P["index"] = 0
  }
  else {            # error creating/finding allpages.db
    return 0
  }

  return 1

}

#
# Check all articles, runbot() on each, stop when ["tags"] limit is reached
#  Runs in different modes, 2 debugging and 1 production, set by P[project]["BM"] in BEGIN{}
#
function runSearch(  i,a,c,j,bz,sz,ez,sp,z,command,dn,la,startpoint,offset,endall,bl,article,
                     al,artblock,inxblock,inxa,inxaa,done) {

  # batch mode. 0 = for testing small batch or single page. 1 = for production of allpages.db
  # BM = 0

  if(P["BM"] == 0) {

    # Single page mode. Set to 0 to disable single page mode, or set to name of article
    # sp = 0
    # sp = "Wikipedia talk:Bots/Requests for approval/GreenC bot 8"
    # sp = "Hydraulic fracturing by country"
    # sp = "ᛒ"

    # batch size.
    bz = 50

    # Start location. Set sz = "0" for first batch, "1000" for second etc..
    sz = 100

    # End location. Set ez = "1000" for first batch, "2000" for second etc..
    ez = 150

    for(z = sz + 1; z <= ez; z = z + bz) {

      if(!sp) { # batch mode

        command = Exe["tail"] " -n +" z " " P["db"] P["key"] ".allpages.db | " Exe["head"] " -n " bz " > " P["db"] P["key"] ".runpages.db"
        sys2var(command)

        if( checkexists(P["db"] P["key"] ".runpages.db") ) {
          for(i = 1; i <= splitn(P["db"] P["key"] ".runpages.db", a, i); i++) {
            stdErr("Processing " a[i] " (" i ")" )
            runbot(a[i])
          }
          flushjournal()
          dn = z "-" z + (bz - 1)
          print dn " of " ez " " date8() " " P["numbers"] >> P["log"] P["key"] ".batch-done"
          close(P["log"] P["key"] ".batch-done")
        }

      }

      else {  # single page mode

        # Run bot on given article title
        print runbot(sp)
        break

      }
    }

  }

  # Run allpages.db
  #  Below method of processing allpages.db (5+ million lines) is designed to minimize memory on Toolforge grid,
  #  keep log files small, and gracefully handles frequent stops by the grid. But also works on any server.
  #   allpages.db = file containing complete list of millions of article titles. See setup instructions.
  #   allpages.done = permanent log. One line equates to P["blsize"] articles processed.
  #   allpages.offset = temporary log. One line equates to one article processed. This resets to 0-len with
  #                      each new P["blsize"] block. If the bot halts mid-way through, it will pick up where left off.

  else if(P["BM"] == 1) {

    # Establish startpoint ie. the line number in allpages.db where processing will begin

    # To manually set startpoint. Set along a P["blsize"] boundary ending in 1 eg. 501001 OK. 501100 !OK
    # startpoint = 26000

    # To auto start where it left-off, use last entry in allpages.done as block startpoint
    if(empty(startpoint) && checkexists(P["log"] P["key"] ".allpages.done")) {

      startpoint = sys2var(Exe["tail"] " -n 1 " P["log"] P["key"] ".allpages.done | " Exe["grep"] " -oE \"^[^-]*[^-]\"")

      if(!isanumber(startpoint)) {  # log corrupted
        email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName "(" Hostname "." Domain ") unable to restart", "")
        runlog("remove")
        exit 0
      }

      parallelWrite(curtime() " ---- Bot (re)start (" startpoint "-" startpoint + (P["blsize"] - 1) ")", P["log"] P["key"] ".restart", Engine)

    }

    # All else fails (eg. first run) start at 1
    if(empty(startpoint))
      startpoint = 1

    if (checkexists(P["db"] P["key"] ".allpages.db") ) {

      # Check for offset ie. bot previously halted mid-way through a block
      if (checkexists(P["log"] P["key"] ".allpages.offset")) {
        offset = int(splitx(sys2var(Exe["tail"] " -n 1 " P["log"] P["key"] ".allpages.offset"), " ", 1)) + 1
        P["numbers"] = strip(splitx(sys2var(Exe["tail"] " -n 1 " P["log"] P["key"] ".allpages.offset"), " ", 2))
        verifypn("break 1: " startpoint " " offset)
        if(offset == 0 || empty(offset) ) {
          offset = 1
          if( checkexists(P["log"] P["key"] ".allpages.done") ) {
            P["numbers"] = strip(splitx(sys2var(Exe["tail"] " -n 1 " P["log"] P["key"] ".allpages.done"), " ", 3))
            verifypn("break 2: " startpoint)
          }
        }
        if(offset > P["blsize"])
          offset = P["blsize"]
        removefile2(P["log"] P["key"] ".allpages.offset")
      }
      else {
        offset = 1
        if( checkexists(P["log"] P["key"] ".allpages.done") ) {
          P["numbers"] = strip(splitx(sys2var(Exe["tail"] " -n 1 " P["log"] P["key"] ".allpages.done"), " ", 3))
          verifypn("break 3: " startpoint)
        }
      }

      # Iterate through allpages.db creating blocks of P["blsize"] articles each
      for(bl = startpoint; bl > 0; bl += P["blsize"]) {

        # Retrieve a P["blsize"] block from allpages.db - unix tail/head is most efficient
        command = Exe["tail"] " -n +" bl " " P["db"] P["key"] ".allpages.db | " Exe["head"] " -n " P["blsize"]
        artblock = sys2var(command)

        # Retrieve a 70000k block from index.db and load Index[][]
        loadindex(sp)

        # Iterate through the 1..P["blsize"] individual articles in artblock
        delete article
        c = split(artblock, article, "\n")
        artblock = ""
        for(al = offset; al <= c; al++) {

          # Log to offset file
          parallelWrite(al " " P["numbers"], P["log"] P["key"] ".allpages.offset", Engine)

          # Log debug file (optional)
          # print bl "-" bl+999 " " al >> P[project]["log"] "allpages.debug"
          # close(P[project]["log"] "allpages.debug")

          # Run bot on given article title
          runbot(article[al])

        }

        # Flush journal-offset.db -> journal.db every P["blsize"] articles
        flushjournal()

        # Log the block complete at allpages.done
        # parallelWrite(bl "-" bl+999 " " date8() " " P["numbers"], P["log"] P["key"] ".allpages.done", Engine)
        P["totalcache"] += P["misscache"]
        parallelWrite(bl "-" bl + (P["blsize"] - 1) " " date8() " " P["numbers"] " " datehms() " " P["misscache"] " (" P["misscache"] / P["blsize"] ") " P["totalcache"], P["log"] P["key"] ".allpages.done", Engine)

        # Reached end of allpages.db, prepare for next run and exit
        if(int(al) < int(P["blsize"] + 1) ) {
          finished()
          return
        }

        # Successful completion of P["blsize"] articles, clear offset file
        removefile2(P["log"] P["key"] ".allpages.offset")

        # Reset offset to 1
        offset = 1

      }
    }
  }
}

#
# Completed run. Update master.db and reshuffle files.
#
function finished( i,a,b,c,fp,names) {

  parallelWrite("Ending arcstat for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)

  P["date"]    = strip(splitx(sys2var(Exe["tail"] " -n 1 " P["log"] P["key"] ".allpages.done"), " ", 2))
  P["numbers"] = strip(splitx(sys2var(Exe["tail"] " -n 1 " P["log"] P["key"] ".allpages.done"), " ", 3))

  if( ! empty(P["numbers"]) && P["numbers"] !~ /^0[|]0[|]/ && ! empty(P["date"]) ) {  # all looks good..

    # Count number of articles
    P["totalarts"] = strip(sys2var("awk 'END{print NR}' " shquote(P["db"] P["key"] ".allpages.db")))

    # write to master.db / save backup
    sys2var(Exe["cp"] " " P["db"] "master.db " P["db"] "masterbak/master.db." date8() )
    sys2var(Exe["cp"] " " P["db"] "start.db " P["db"] "masterbak/start.db." date8() )
    parallelWrite(Hostname "." Domain " " P["date"] " " P["totalarts"] " " P["numbers"], P["db"] "master.db", Engine)

    # log-file removals
    sys2var(Exe["mv"] " " P["log"] P["key"] ".allpages.done " P["log"] P["key"] ".allpages.done.save"  )
    removefile2(P["log"] P["key"] ".allpages.offset")
    if( checkexists(P["log"] P["key"] ".syslog") )
      sys2var(Exe["mv"] " " P["log"] P["key"] ".syslog " P["log"] P["key"] ".syslog.save"  )
    removefile2(P["log"] P["key"] ".syslog")

    # db-file removals and gzip
    removefile2(P["db"] P["key"] ".allpages.db")
    removefile2(P["db"] P["key"] ".index.db")
    if( checkexists(P["db"] P["key"] ".journal.db"))
      sys2var(Exe["mv"] " " P["db"] P["key"] ".journal.db " P["db"] P["key"] ".index.db"  )
    sys2var(Exe["gzip"] " " P["db"] P["key"] ".index.db")

  }

  else { # got a problem
    sys2var(Exe["cp"] " " P["db"] "master.db " P["db"] "masterbak/master.db.error." date8() )
    parallelWrite("Error: unable to determine master.db data in finished() for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)

    # Log file backups

    if( checkexists(P["log"] P["key"] ".allpages.done") )
      sys2var(Exe["mv"] " " P["log"] P["key"] ".allpages.done " P["log"] P["key"] ".allpages.done." date8() )
    if( checkexists(P["log"] P["key"] ".allpages.offset") )
      sys2var(Exe["mv"] " " P["log"] P["key"] ".allpages.offset " P["log"] P["key"] ".allpages.offset." date8() )
    if( checkexists(P["log"] P["key"] ".syslog") )
      sys2var(Exe["mv"] " " P["log"] P["key"] ".syslog " P["log"] P["key"] ".syslog." date8() )

    # db file backups

    if( checkexists(P["db"] P["key"] ".allpages.db") )
      sys2var(Exe["mv"] " " P["db"] P["key"] ".allpages.db " P["db"] P["key"] ".allpages.db." date8() )
    if( checkexists(P["db"] P["key"] ".index.db"))
      sys2var(Exe["mv"] " " P["db"] P["key"] ".index.db " P["db"] P["key"] ".index.db." date8() )
    if( checkexists(P["db"] P["key"] ".journal.db"))
      sys2var(Exe["mv"] " " P["db"] P["key"] ".journal.db " P["db"] P["key"] ".journal.db." date8()  )
  }


  # Sync iadetails.db with iadetails-journal.db, citebook.db with citebook-journal.db, etc..

  syncDumps("iadetails")
  # syncDumps("citebook")

}

#
# Run deletename.awk on the <dump>.db files eg. iadetails.db, citebook.db etc..
#
function syncDumps(db) {

  if(checkexists(P["db"] P["key"] "." db "-journal.db") && checkexists(P["db"] P["key"] "." db ".db") ) {
    for(i = 1; i <= splitn(P["db"] P["key"] "." db "-journal.db", a, i); i++) {
      if( countsubstring(a[i], "----") > 1) {
        split(a[i], b, "----")
        names[strip(b[1])] = 1
      }
    }
    if(length(names) > 0) {
      if(checkexists(P["db"] P["key"] "." db "-auth1.db")) removefile2(P["db"] P["key"] "." db "-auth1.db")
      if(checkexists(P["db"] P["key"] "." db ".db.new")) removefile2(P["db"] P["key"] "." db ".db.new")
      for(c in names) 
        print c >> P["db"] P["key"] "." db "-auth1.db"
      close(P["db"] P["key"] "." db "-auth1.db"); system("") # double sure
      sys2var(P["db"] "deletename.awk -n " shquote(P["db"] P["key"] "." db "-auth1.db") " -l " shquote(P["db"] P["key"] "." db ".db") " -o " shquote(P["db"] P["key"] "." db ".db.new")); system("")
      if(checkexists(P["db"] P["key"] "." db "-journal.db"))
        print readfile2(P["db"] P["key"] "." db "-journal.db") >> P["db"] P["key"] "." db ".db.new"
      close(P["db"] P["key"] "." db ".db.new")
      if(checkexists(P["db"] P["key"] "." db ".db.new"))
        sys2var(Exe["mv"] " " P["db"] P["key"] "." db ".db.new " P["db"] P["key"] "." db ".db"  )
      removefile2(P["db"] P["key"] "." db "-auth1.db")
      removefile2(P["db"] P["key"] "." db "-journal.db")
    }
    else {
      removefile2(P["db"] P["key"] "." db "-journal.db")
    }
  }
  else if(checkexists(P["db"] P["key"] "." db "-journal.db") )
    sys2var(Exe["mv"] " " P["db"] P["key"] "." db "-journal.db " P["db"] P["key"] "." db ".db"  )

  # (outdated) cp iadetails to dump: /data/project/botwikiawk/www/static/iadetails/als.wikipedia.org.iadetails.202006.csv
  # cp iadetails to dump: /home/greenc/toolforge/arcstat/iadetails/als.wikipedia.org.iadetails.202006.csv
  # rm previous years dump

  if(checkexists(P["db"] P["key"] "." db ".db") ) {
    sys2var(Exe["gzip"] " " P["db"] P["key"] "." db ".db")
    dd = strip(sys2var(Exe["date"] " \"+%Y%m\""))
    sys2var(Exe["cp"] " " P["db"] P["key"] "." db ".db.gz " P["iadetails"] P["key"] "." db "." dd ".csv.gz")
    dd = int(strip(sys2var(Exe["date"] " \"+%Y\""))) - 1
    dd = dd strip(sys2var(Exe["date"] " \"+%m\""))
    if(checkexists(P["iadetails"] P["key"] "." db "." dd ".csv"))
      removefile2(P["iadetails"] P["key"] "." db "." dd ".csv")
    if(checkexists(P["iadetails"] P["key"] "." db "." dd ".csv.gz"))
      removefile2(P["iadetails"] P["key"] "." db "." dd ".csv.gz")
  }

}

#
# Check if last article revision is older than date in index.db (last date of check) - if so skip downloading and searching article
#  Otherwise download and search article
#  Update journal-offset.db
#
function runbot(article,  ls,inx) {

  if(P["index"] && ! empty(Index) ) {
    if(! empty(Index[article]["numbers"]) && ! empty(Index[article]["date"]) ) {
      ls = laststamp(article)
      if(! empty(ls)) {
        inx = d82unix(Index[article]["date"])
        if( int(inx) >= int(ls) ) {         # article's last revision is same as index revision date
          nfromindex(article, Index[article]["date"], Index[article]["numbers"])
        }
        else {                              # article's last revision is newer than last check-date
          nfromart(article)
        }
      }
      else {                      # trouble getting laststamp
        nfromart(article)
      }
    }
    else {                        # article doesn't exist in index.db
      nfromart(article)
    }
  }
  else {                          # index.db doesn't exist
    nfromart(article)
  }

}


#
# Given a index.db set of numbers, increase P["numbers"] from it
#  Update journal-offset.db
#
function nfromindex(article, dateeight, numbers,  a,b) {

          split(numbers, a, "|")
          split(P["numbers"], b, "|")
          P["numbers"] = (b[1] + a[1]) "|"  (b[2] + a[2]) "|" (b[3] + a[3]) "|" (b[4] + a[4]) "|" (b[5] + a[5]) "|" (b[6] + a[6]) "|" (b[7] + a[7]) "|" (b[8] + a[8]) "|" (b[9] + a[9]) "|" (b[10] + a[10]) "|" (b[11] + a[11]) "|" (b[12] + a[12]) "|" (b[13] + a[13]) "|" (b[14] + a[14]) "|" (b[15] + a[15]) 
          parallelWrite(article " ---- " dateeight " ---- " numbers, P["db"] P["key"] ".journal-offset.db", Engine)

}

#
# Given an article name, increase P["numbers"] with counts from it
#  Update journal.db
#
function nfromart(article,  a,g,c,b,i,field,iat) {

          # 1|2|3|4|5|6|7|8|9|10|11|12|13|14|15
          # 1 = number of wayback links
          # 2 = number of articles with 1+ wayback links
          # 3 = number of alt-archive links (not including archive.is or webcite)
          # 4 = number of articles with 1+ alt-archive links
          # 5 = number of archive.is links
          # 6 = number of articles with 1+ archive.is links
          # 7 = number of webcite links
          # 8 = number of articles with 1+ webcite links
          # 9 = number of Google Books links in a cite web|book|journal with an ISBN
          #10 = number of Internet Archive mediatype texts
          #11 = number of Internet Archive mediatype audio
          #12 = number of Internet Archive mediatype movies
          #13 = number of Internet Archive mediatype image
          #14 = number of Internet Archive mediatype other/none
          #15 = number of Internet Archive texts with page numbers

          delete a
          delete g

          tup(getwikisource2(article, Domain, Hostname), a)
          if(empty(a[1])) {
            sleep(1)
            tup(getwikisource2(article, Domain, Hostname), a)
          }

          if( ! empty(a[1])) {

            for(i = 1; i <= 15; i++)
              g[i] = 0

            #print "iasearchre"
            #print "awk -ilibrary 'BEGIN{c=patsplit(readfile(\"t.wk\"), field, /" R["iasearchre"] "/); print c}'"

            c = patsplit(a[1], field, R["iasearchre"])   # wayback
            if(c > 0) {
              g[1] = c
              g[2] = 1
            }

            #print "noiasearchre"
            #print "awk -ilibrary 'BEGIN{c=patsplit(readfile(\"t.wk\"), field, /" R["noiasearchre"] "/); print c}'"

            c = patsplit(a[1], field, R["noiasearchre"])  # alt-archives
            if(c > 0) {
              g[3] = c
              g[4] = 1
            }

            #print "issearchre"
            #print "awk -ilibrary 'BEGIN{c=patsplit(readfile(\"t.wk\"), field, /" R["issearchre"] "/); print c}'"

            c = patsplit(a[1], field, R["issearchre"])    # archive.is
            if(c > 0) {
              g[5] = c
              g[6] = 1
            }
            c = patsplit(a[1], field, R["wcsearchre"])    # webcite
            if(c > 0) {
              g[7] = c
              g[8] = 1
            }

            # parse and count Google Books
            g[9] = googleBooks(article, a[1])

            # parse and count archive.org/details
            split(iaType(article, a[1]), iat, "|")
            g[10] = int(iat[1])
            g[11] = int(iat[2])
            g[12] = int(iat[3])
            g[13] = int(iat[4])
            g[14] = int(iat[5])
            g[15] = int(iat[6])

            # parse {{cite book}}
            # citeBook(article, a[1])

            split(P["numbers"], b, "|")
            P["numbers"] = (b[1] + g[1]) "|"  (b[2] + g[2]) "|" (b[3] + g[3]) "|" (b[4] + g[4]) "|" (b[5] + g[5]) "|" (b[6] + g[6]) "|" (b[7] + g[7]) "|" (b[8] + g[8]) "|" (b[9] + g[9]) "|" (b[10] + g[10]) "|" (b[11] + g[11]) "|" (b[12] + g[12]) "|" (b[13] + g[13]) "|" (b[14] + g[14]) "|" (b[15] + g[15])
            P["journalnumb"] = g[1] "|" g[2] "|" g[3] "|" g[4] "|" g[5] "|" g[6] "|" g[7] "|" g[8] "|" g[9] "|" g[10] "|" g[11] "|" g[12] "|" g[13] "|" g[14] "|" g[15]
            parallelWrite(article " ---- " date8() " ---- " P["journalnumb"], P["db"] P["key"] ".journal-offset.db", Engine)

          }
          else {  # Can't get article make a dummy entry to keep index.db in sync with allpages.db
            parallelWrite(article " ---- " date8() " ---- " P["zeros"] " ---- fubar42 ", P["db"] P["key"] ".journal-offset.db", Engine)
          }

}

#
# Return last revision timestamp (unix time UTC) for given article
#  Has 2 seconds and 1 try to get it, otherwise return ""
#  No error-checking, fast as possible
#
function laststamp(article,  jsonin,url,d,a) {

  url = "https://" Hostname "." Domain "/w/api.php?action=query&prop=revisions&titles=" urlencodeawk(article) "&rvslots=*&rvprop=timestamp&format=json"
  jsonin = http2var(url)
  # "timestamp":"2019-09-11T16:02:20Z"
  if(match(jsonin, /"timestamp":"[^"]+["]/, d)) {
    split(d[0], a, /"/)
    return d82unix(gsubi("[-]", "", substr(a[4],1,10)))
  }
  parallelWrite("Warning: timeout revisions API (" article ") in " P["key"] " for (" command ") ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
  return ""

}

#
# Concat .journal-offset.db to .journal.db and delete .journal-offset.db
#
function flushjournal(  lc,i) {

    close(P["db"] P["key"] ".journal-offset.db")
    sys2var("echo z > " P["db"] P["key"] "z")  # seems to help flush Grid buffers
    sys2var("echo z > " P["log"] P["key"] "z")
    removefile2(P["db"] P["key"] "z")
    removefile2(P["log"] P["key"] "z")

    if( checkexists(P["db"] P["key"] ".journal-offset.db") && checkexists(P["db"] P["key"] ".journal.db") ) {
      printf("%s", readfile(P["db"] P["key"] ".journal-offset.db")) >> P["db"] P["key"] ".journal.db"
      close(P["db"] P["key"] ".journal.db")
      removefile2(P["db"] P["key"] ".journal-offset.db")
      # sys2var(Exe["cat"] " " P["db"] P["key"] ".journal.db " P["db"] P["key"] ".journal-offset.db > " P["db"] P["key"] ".o ; " Exe["mv"] " " P["db"] P["key"] ".o "  P["db"] P["key"] ".journal.db")
      # sys2var(Exe["rm"] " " P["db"] P["key"] ".journal-offset.db")
    }
    else if( checkexists(P["db"] P["key"] ".journal-offset.db") && ! checkexists(P["db"] P["key"] ".journal.db") ) {
      sys2var(Exe["mv"] " " P["db"] P["key"] ".journal-offset.db " P["db"] P["key"] ".journal.db")
    }
}

#
# create allpages.db
#
function newallpages(  sort) {

  if(checkexists(P["db"] P["key"] ".allpages.db.save")) {   # arcstat.awk aborted during allPages() - start over
    parallelWrite("Found allpages.db.save restarting allPages() for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    if(! allPages() )
      return 0
    if(! sortdb("allpages.db") )
      return 0
  }
  else if( ! checkexists(P["db"] P["key"] ".allpages.db"))  {
    parallelWrite("Starting arcstat for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    if(! allPages() )
      return 0
    if(! sortdb("allpages.db") )
      return 0
  }
  else if( filesize(P["db"] P["key"] ".allpages.db") == 0) {
    parallelWrite("Starting arcstat for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    if(! allPages() )
      return 0
    if(! sortdb("allpages.db") )
      return 0
  }
  else
    parallelWrite("Re-starting arcstat for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)

  if( ! checkexists(P["db"] P["key"] ".allpages.db"))  {
    parallelWrite("Error: missing allpages.db in newallpages() for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    return 0
  }
  if( filesize(P["db"] P["key"] ".allpages.db") == 0) {
    parallelWrite("Error: zero-length allpages.db in newallpages() for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    return 0
  }
  if(checkexists(P["db"] P["key"] ".allpages.db.save")) {  
    parallelWrite("Error: allpages.db.save exists for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    return 0
  }

  return 1

}

#
# Sort large file, 50MB memory 1 parallel process
#
function sortdb(dbname,  sort,tempFile,mainFile) {

  tempFile = P["db"] P["key"] ".sorted.db"
  mainFile = P["db"] P["key"] "." dbname

  if( checkexists(tempFile) )
    removefile2(tempFile)

  sort = Exe["sort"] " --temporary-directory=" P["db"] " --output=" tempFile " --buffer-size=50M --parallel=1 " mainFile
  sys2var(sort)

  # Try 3 times
  if( filesize(tempFile) != filesize(mainFile) ) {
    removefile2(tempFile)
    sleep(5)
    sys2var(sort)
    if( filesize(tempFile) != filesize(mainFile) ) {
      removefile2( tempFile)
      sleep(30)
      sys2var(sort)
      if( filesize(tempFile) != filesize(mainFile) ) {
        removefile2(tempFile)
        parallelWrite("Error: unable to sort " mainFile " in sortdb() ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
        parallelWrite(sort " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
        return 0
      }
    }
  }

  # Make sure it sorted (better method?)
  #if( sys2var(Exe["tail"] " -n 1 " tempFile) == sys2var(Exe["tail"] " -n 1 " mainFile) ) {
  #  # removefile2(tempFile)
  #  parallelWrite("Error: unable to sort file " mainFile " in sortdb() ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
  #  return 0
  #}

  sys2var(Exe["mv"] " " tempFile " " mainFile)
  if( checkexists(tempFile) ) {
    parallelWrite("Error: unable to move sorted file " tempFile " in sortdb() ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    removefile2(tempFile)
    return 0
  }
  if( ! checkexists(mainFile)) {
    parallelWrite("Error: unable to find sorted file " mainFile " in sortdb() ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    return 0
  }

  return 1

}

#
# Convert a date-eight (20120101) to Unix timestamp (UTC)
#
function d82unix(s) {
  return strftime("%s", mktime(substr(s, 1, 4) " " substr(s, 5, 2) " " substr(s, 7, 2) " 0 0 0"), 1)
}

#
# Return current date-eight (20120101) in UTC
#
function date8() {
  return strftime("%Y%m%d", systime(), 1)
}

#
# Current time in UTC
#
function curtime() {
  return strftime("%Y%m%d-%H:%M:%S", systime(), 1)
}

#
# Return current date-eight with dash (2012-01-01) in UTC
#
function date8dash() {
  return strftime("%Y-%m-%d", systime(), 1)
}

#
# Return current H:M:S in UTC
#
function datehms() {
  return strftime("%H:%M:%S", systime(), 1)
}

function verifypn(s) {

  if( empty(P["numbers"]) ) 
    parallelWrite("Error: empty P[numbers] in " s " for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
  else if( P["numbers"] == P["zeros"] )
    parallelWrite("Error: 0|0|0|0 P[numbers] in " s " for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)

}

#
# getwikisource2 - download plain wikisource.
#
# streamlined version. Skips redirect check since it used wikiget -A for allpages.db which already skips them. Short timeout
#
# . Returns a proto-tuple see tup() in library.awk
#
function getwikisource2(namewiki,domain,hostname,    f,urlencoded,url,b) {

  urlencoded = urlencodeawk(strip(namewiki))

  # See notes on action=raw at: https://phabricator.wikimedia.org/T126183#2775022

  url = "https://" hostname "." domain "/w/index.php?title=" urlencoded "&action=raw"
  f = http2var(url)
  if(length(f) < 5 ) {                                    # Bug in ?action=raw - sometimes it returns a blank page
    url = "https://" hostname "." domain "/wiki/Special:Export/" urlencoded
    f = http2var(url)
    split(f, b, /<text (xml|bytes)[^>]*>|<\/text/)
    f = convertxml(b[2])
  }
  if(length(f) < 5)
    parallelWrite("Warning: empty article returned (" namewiki ") in " P["key"] " for (" command ") ---- " curtime(), P["log"] P["key"] ".syslog", Engine)

  return strip(f) SUBSEP ""

}

# ___ All pages (-A)

# adapted from wikiget.awk writes real-time instead of uniq - this saves memory
#  write to allpages.db
#
# MediaWiki API: Allpages
#  https://www.mediawiki.org/wiki/API:Allpages
#
function allPages(   url,results,apfilterredir,aplimit,apiURL) {

        apfilterredir = "nonredirects"
        aplimit = 500
        apiURL = "https://" Hostname "." Domain "/w/api.php?"

        url = apiURL "action=query&list=allpages&aplimit=" aplimit "&apfilterredir=" apfilterredir "&apnamespace=0&format=json&formatversion=2&maxlag=4"

        # save output to temporary file .save in case arcstat aborts part way through it will get detected by newallpages() to start over
        if(checkexists(P["db"] P["key"] ".allpages.db.save"))
          removefile2(P["db"] P["key"] ".allpages.db.save")

        if(! getallpages(url, apiURL, apfilterredir, aplimit) )
          return 0

        sys2var(Exe["mv"] " " P["db"] P["key"] ".allpages.db.save " P["db"] P["key"] ".allpages.db")

        return 1

}
function getallpages(url,apiURL,apfilterredir,aplimit,         jsonin,jsonout,continuecode,count,i) {

        jsonin = getjsonin(url)
        continuecode = getcontinue(jsonin, "apcontinue")
        if ( ! empty(json2var(jsonin))) {
            jsonout = json2var(jsonin)
            parallelWrite(jsonout, P["db"] P["key"] ".allpages.db.save", Engine)
        }

        while ( continuecode != "-1-1!!-1-1" ) {
            url = apiURL "action=query&list=allpages&aplimit=" aplimit "&apfilterredir=" apfilterredir "&apnamespace=0&apcontinue=" urlencodeawk(continuecode, "rawphp") "&continue=" urlencodeawk("-||") "&format=json&formatversion=2&maxlag=4"
            jsonin = getjsonin(url)
            continuecode = getcontinue(jsonin,"apcontinue")
            if ( ! empty(json2var(jsonin))) {
              jsonout = json2var(jsonin)
              parallelWrite(jsonout, P["db"] P["key"] ".allpages.db.save", Engine)
            }
        }
        return 1
}

#
# Get jsonin with max lag/error retries
#
function getjsonin(url,  i,jsonin,pre,res,retries) {

            retries = 200

            pre = "API error: "

            for(i = 1; i <= retries; i++) {
              jsonin = http2var(url)
              res = apierror(jsonin, "json")
              if( res ~ "maxlag") {
                if(i == retries) {
                  parallelWrite(pre jsonin " for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
                  email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName "(" Hostname "." Domain ") Maxlag timeout in getjsonin() after " retries " tries aborting script", "")
                  runlog("remove")
                  exit
                }
                sleep(3)
              }
              else if( res ~ "error") {
                if(i == 5) {
                  parallelWrite(pre jsonin " for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
                  email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName "(" Hostname "." Domain ") Error in getjsonin() after 5 tries aborting script", "")
                  runlog("remove")
                  exit
                }
                sleep(10)
              }
              else if( res ~ "empty") {
                if(i == 5) {
                  parallelWrite(pre " Received empty response for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
                  email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName "(" Hostname "." Domain ") Empty response in getjsonin() after 5 tries aborting script", "")
                  runlog("remove")
                  exit
                }
                sleep(10)
              }
              else if( res ~ "OK")
                break
            }
            return jsonin

}

#
# Parse continue code from JSON input
#
function getcontinue(jsonin, method,    jsona,id) {

        if( query_json(jsonin, jsona) >= 0) {
          id = jsona["continue", method]
          if(!empty(id))
            return id
        }
        return "-1-1!!-1-1"
}

#
# Basic check of API results for error
#
function apierror(input, type,   pre, code) {

        if (length(input) < 5)
            return "empty"

        if (type == "json") {
            if (match(input, /"error"[:]{"code"[:]"[^"]*","info"[:]"[^"]*"/, code) > 0) {
                if(input ~ "maxlag")
                  return "maxlag"
                else
                  return "error"
            }
            else
              return "OK"
        }
}


#
# json2var - given raw json extract field "title" and convert to \n seperated string
#
function json2var(json,  jsona,arr) {
    if (query_json(json, jsona) >= 0) {
        splitja(jsona, arr, 3, "title")
        return join(arr, 1, length(arr), "\n")
    }
}


# Retrieve a 70,000 block of names from index.db and load Index[][]
#  Block sequence is -30000 to 0 to P["blsize"] to +30000
# Note: a 70k-line block is about 3-4MB memory
#
function loadindex(sp,   inxblock,alp,inxa,command,a,c,cacheW,cacheS,cacheE) {

        cacheW = 30000  # Size of cache windows on both sides of the index block
        cacheS = 0      # Startpoint minus this number is where to start loading cache
        cacheE = P["blsize"] + (int(cacheW) * 2)  # Cache end point

        P["misscache"] = 0  # running total number of missed cache hits.

        if(P["index"]) {

          delete Index

          if( int(sp - cacheW) > 0)
            cacheS = sp - cacheW
          else {
            cacheS = 1
          }

          command = Exe["tail"] " -n +" cacheS " " P["db"] P["key"] ".index.db | " Exe["head"] " -n " cacheE
          if(debug1) parallelWrite("loadindex command = " command " (" datehms() ")", "/dev/stdout", 0)
          inxblock = sys2var(command)
          if(debug1) parallelWrite("loadindex end command and start parse" " (" datehms() ")", "/dev/stdout", 0)
          c = split(inxblock, inxa, "\n")
          for(alp = 1; alp <= c; alp++) {
            if(! empty(inxa[alp])) {
              split(inxa[alp], a, " ---- ")
              Index[strip(a[1])]["date"] = strip(a[2])
              Index[strip(a[1])]["numbers"] = strip(a[3])
            }
          }
          if(debug1) parallelWrite("loadindex end parse. Length of inxa = " length(inxa) " (" datehms() ")", "/dev/stdout", 0)
        }

}

#
# Return number of Google Book links
#
function googleBooks(article,fp,  c,i,field,sep,dest,found) {

  # Default in most cases. "~" is 2x faster than match()

  if(fp !~ /books[.]google[.]/)
    return 0

  # Remove waybacks

  c = patsplit(fp, field, /web[.]archive[.]org([\/]web)?\/[^\/]+[\/]https?[:][\/]{2}books[.]google[\/]/, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++)
      field[i] = ""
    fp = unpatsplit(field, sep)
  }

  # Parse and count

  c = patsplit(fp, field, /https?[:]\/\/books[.]google[.]/, sep)
  return c

# Return number of Google Book links in a cite web|book|journal that have an ISBN
#
#  found = 0
#  c = patsplit(fp, field, R["bookre"], sep)
#  for(i = 1; i <= c; i++) {
#    if(field[i] ~ /https?[:]\/\/books[.]google[.]/) {
#      if(match(field[i], /[|][[:space:]]*isbn[[:space:]]*[=][^|}]*[^|}]/,dest)) {
#        sub(/^[|][[:space:]]*isbn[[:space:]]*[=][[:space:]]*/, "", dest[0])
#        dest[0] = strip(stripwikicomments(dest[0]))
#        if(length(dest[0] > 9)) {
#          found++
#          parallelWrite(article " ---- " field[i], P["db"] P["key"] ".gbooks.db", Engine)
#        }
#      }
#    }
#  }
#  return found

}

#
# Given an archive.org/details URL return it's ID, clean garbage from parsing
#
function getIAID(url,  d,a) {
  if(match(url, /https?[:][\/]{2}(www[.])?archive[.]org[\/]details[\/][^\/ \|\]\[}{=*#<$',:;-]+[^\/ \|\]\[}{=*#<$',:;-]*/, d) > 0) {
    a = splitx(d[0], "[/]", 5)
    if(a ~ "https?$") sub("https?$", "", a)
    if(a ~ "[.]$") sub("[.]$", "", a)
    return strip(gsubi("\n", "", a))
  }
}

#
# Parse and count archive.org/details URLs
#
function iaType(article,fp,   url,command,jsonin,i,a,c,e,d,dd,r,field,sep,result,ID,mediatype) {

  #1 = number of Internet Archive mediatype texts
  #2 = number of Internet Archive mediatype audio
  #3 = number of Internet Archive mediatype movies
  #4 = number of Internet Archive mediatype image
  #5 = number of Internet Archive mediatype other/none
  #6 = number of Internet Archive texts with page numbers

  # Default in most cases. "~" is 2x faster than match()

  if(fp !~ /archive.org[\/]details/)
    return "0|0|0|0|0|0"

  # Remove waybacks

  c = patsplit(fp, field, /web[.]archive[.]org([\/]web)?[\/][^\/]+[\/]https?[:][\/]{2}(www[.])?archive[.]org[\/]details/, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++)
      field[i] = ""
    fp = unpatsplit(field, sep)
  }

  # Initialize

  delete ID
  delete result
  for(i = 1; i <= splitn("texts\naudio\nmovies\nimage\nother\npages", a, i); i++)
    result[a[i]] = 0

  # Parse and remove {{cite book}} templates

  c = patsplit(fp, field, R["bookre"], sep)
  if(c > 0) {
    for(i = 1; i <= c; i++) {
      if(match(field[i], /https?[:][\/]{2}(www[.])?archive[.]org[\/]details[\/][^\/]+[\/]page[\/]n?[0-9xiv]{1,}/, d) > 0) {
        ID[++r]["id"] = getIAID(d[0])
        if(match(d[0], /page[\/]n?[0-9xiv]{1,}/, e) > 0) {
          ID[r]["page"] = subs("page/", "", e[0])
          ++result["pages"]
        }
      }
      else if(match(field[i], /https?[:][\/]{2}(www[.])?archive[.]org[\/]details[\/][^\/ \|\]}<$,:;-]+[^\/ \|\]}<$,:;-]*/, d) > 0) {
        ID[++r]["id"] = getIAID(d[0])
        ID[r]["page"] = 0
      }
      field[i] = ""
    }
    fp = unpatsplit(field, sep)
  }

  # Parse everything else

  c = patsplit(fp, field, /https?[:][\/]{2}(www[.])?archive[.]org[\/]details[\/][^\/ \|\]}<$,:;-]+[\/ \|\]}<$,:;-]*(page[\/]n?[0-9xiv]{1,})?/, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++) {
      if(field[i] ~ /[\/]page[\/]/) {
        ID[++r]["id"] = getIAID(field[i])
        if(match(field[i], /page[\/]n?[0-9xiv]{1,}/, e) > 0) {
          ID[r]["page"] = subs("page/", "", e[0])
          ++result["pages"]
        }
      }
      else {
        ID[++r]["id"] = getIAID(field[i])
        ID[r]["page"] = 0
      }

      field[i] = ""
    }
    fp = unpatsplit(field, sep)
  }

  # Query API and determine mediatype
  # API: https://archive.org/advancedsearch.php?q=identifier%3Aagrammaritalian00cicigoog&fl%5B%5D=mediatype&sort%5B%5D=&sort%5B%5D=&sort%5B%5D=&rows=5&page=1&output=json&callback=callback

  if(length(ID) > 0) {
    for(num in ID) {
      url = "https://archive.org/advancedsearch.php?q=identifier%3A" ID[num]["id"] "&fl%5B%5D=mediatype&sort%5B%5D=&sort%5B%5D=&sort%5B%5D=&rows=5&page=1&output=json&callback=callback"
      jsonin = http2var(url)
      # Lazy parse, should be faster and reliable
      if(match(jsonin, /"mediatype":"[^"]*["]/, d) > 0) {
        split(d[0], dd, /"/)
        mediatype = dd[4]
        if(dd[4] == "texts")
          ++result["texts"]
        else if(dd[4] == "audio")
          ++result["audio"]
        else if(dd[4] == "movies")
          ++result["movies"]
        else if(dd[4] == "image")
          ++result["image"]
        else {
          ++result["other"]
          if(empty(strip(mediatype)))
            mediatype = "error"
        }
      }
      else {
        ++result["other"]
        mediatype = "error"
      }

      parallelWrite(article " ---- " strip(ID[num]["id"]) " ---- " strip(mediatype) " ---- " strip(ID[num]["page"]), P["db"] P["key"] ".iadetails-journal.db", Engine)
    }
  }
  return result["texts"] "|" result["audio"] "|" result["movies"] "|" result["image"] "|" result["other"] "|" result["pages"]

}

#
# Parse {{cite book}}
#
function citeBook(article,fp,  i,c) {

  # deprecated - also commented out above
  return ""

  # Parse and remove {{cite book}} templates

  c = patsplit(fp, field, R["bookre"], sep)
  if(c > 0) {
    for(i = 1; i <= c; i++)
      parallelWrite(article " ---- " strip(gsubi("\\n", "\\\\n", field[i])), P["db"] P["key"] ".citebook-journal.db", Engine)
  }

}

#
# Check ps aux, if processes is already running return 1 otherwise 0
#   Replacement for toolforge that ensures only 1 process running at a time.
#
function isRunning( i,command,ps,psa,psb,k) {

  # /usr/bin/ps aux | /usr/bin/grep arcstat.awk | /usr/bin/grep -v tcsh | /usr/bin/grep -v grep
  # greenc     93891  6.7  3.1 106728 96208 pts/3    S    00:52  48:35 /usr/bin/awk -bE /home/greenc/toolforge/arcstat/arcstat.awk -h ru -d wikipedia.org
  # greenc     95687  9.2  3.3 118928 103168 pts/3   S    00:52  66:31 /usr/bin/awk -bE /home/greenc/toolforge/arcstat/arcstat.awk -h te -d wikipedia.org
      
  command = Exe["ps"] " aux | " Exe["grep"] " arcstat.awk | " Exe["grep"] " -v tcsh | " Exe["grep"] " -v grep "
  ps = sys2var(command)
  for(i = 1; i <= splitn(ps "\n", psa, i); i++) {
    split(psa[i], psb, " ")
    if(strip(psb[15]) == Hostname && strip(psb[17]) == Domain) 
      k++  # first one is current process you dummy :) Need to see 2+
  }
  if(k > 1) {
    email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName "(" Hostname "." Domain ") - Error unable to start. Process isRunning()", psa[i])
    parallelWrite("Error unable to start. Process isRunning() for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
    stdErr("Error unable to start. Process isRunning() for " P["key"] " ---- " curtime())
    return 1
  }

  return 0

}

#
# Add/remove entries in ~/runlog.txt which tracks which processes are running so they can be restarted automatically after an abort
#   This is a replacement system for Toolforge's continuous pool that would automatically restart after an abort.
#   If you're running on Toolforge this function is harmless. It's needed for runlog.awk which runs from cron and looks at runlog.txt
#
function runlog(s,  command,res,fp,c,b,a,i,k) {

  if(s == "add") {
    if(checkexists(P["runlog"])) {
      command = Exe["grep"] " -Fcw -- " shquote(Hostname " ---- " Domain) " " shquote(P["runlog"])
      res = int(sys2var(command))
      if(res > 0) # already exists
        return
    }
    parallelWrite(Hostname " ---- " Domain " ---- " curtime(), P["runlog"], Engine)
  }
  else if(s == "remove" || s == "delete") {
    if(checkexists(P["runlog"])) {
      command = Exe["grep"] " -Fcw -- " shquote(Hostname " ---- " Domain) " " shquote(P["runlog"])
      res = int(sys2var(command))
      if(res > 0) {
        fp = readfile(P["runlog"])  # instead of splitn() not sure how that function will interact here
        c = split(fp, a, "\n")
        removefile2(P["runlog"])
        for(i = 1; i <= c; i++) {
          if(!empty(a[i])) {
            k = split(a[i], b, " ---- ")
            if(k == 3) {
              if(strip(b[1]) == Hostname && strip(b[2]) == Domain)
                continue
              parallelWrite(a[i], P["runlog"], Engine)
            }
          }
        }
      }
    }
  }
}
