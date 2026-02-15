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
               emailfp   = /home/greenc/scripts/secrets/greenc.email \
               userid    = User:GreenC \
               version   = 1.5 \
               copyright = 2026"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
  BotName = "arcstat"
  Home = G["home"]
  Engine = 3

  # Agent string format non-compliance could result in 429 (too many requests) rejections by WMF API
  Agent = BotName "-" G["version"] "-" G["copyright"] " (" G["userid"] "; mailto:" strip(readfile(G["emailfp"])) ")"

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
  while ((C = getopt(ARGC, ARGV, "xh:d:")) != -1) {
      opts++
      if(C == "h")                 #  -h <hostname>   Hostname eg. "en"
        Hostname = verifyval(Optarg)
      if(C == "d")                 #  -d <domain>     Domain eg. "wikipedia.org"
        Domain = verifyval(Optarg)
      if(C == "x")                 #  -x              Ignore runpage.txt
        skiprunpage = 1
  }

  if(opts == 0 || empty(Domain) || empty(Hostname) ) {
    print "Problem with arguments"
    exit(0)
  }

  if(checkexists("runpage.txt") && skiprunpage != 1) {
    rp = readfile("runpage.txt")
    if(rp ~ "STOP") {
      stdErr("runpage.txt reports STOP")
      exit
    }
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
                     al,artblock,done,batch_str,batch_results,b_ts,b_content,art_blocks,x,parts,
                     curr_art,ls,inx_date,enc) {

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
        loadindex(bl)

        # Iterate through the 1..P["blsize"] individual articles in artblock
        delete article
        c = split(artblock, article, "\n")
        artblock = ""

        for(al = offset; al <= c; al += 50) {
            # 1. Build Batch String (Individual encoding)
            batch_str = ""
            for (j = 0; j < 50 && (al + j) <= c; j++) {
                if (empty(article[al+j])) continue
                enc = urlencodeawk(article[al+j], "rawphp")
                if (empty(batch_str)) 
                  batch_str = enc
                else 
                  batch_str = batch_str "|" enc
            }

            # 2. Fetch all Timestamps AND Content
            batch_results = check_batch(batch_str)

            # 3. Map Results
            delete b_ts
            delete b_content
            split(batch_results, art_blocks, "\034")
            for (x in art_blocks) {
                split(art_blocks[x], parts, "\035")
                b_ts[parts[1]] = parts[2]
                b_content[parts[1]] = parts[3]
            }

            # 4. Process Batch 
            for (j = 0; j < 50 && (al + j) <= c; j++) {
                curr_art = article[al + j]
                if (empty(curr_art)) continue

                # Log to offset file so the bot can resume if it crashes
                parallelWrite((al + j) " " P["numbers"], P["log"] P["key"] ".allpages.offset", Engine)

                ls = b_ts[curr_art]

                # Safety check. If batch failed for this specific title, 
                # fall back to sequential download.
                if (empty(ls)) {
                    nfromart(curr_art)
                } 
                else if (P["index"] && !empty(Index[curr_art]["numbers"])) {
                    inx_date = d82unix(Index[curr_art]["date"])
                    
                    if (int(inx_date) >= int(ls)) {
                        # No change: use cached numbers
                        nfromindex(curr_art, Index[curr_art]["date"], Index[curr_art]["numbers"])
                    } else {
                        # Page changed: Use the content we already have from the batch
                        nfromart_batched(curr_art, b_content[curr_art])
                    }
                } else {
                    # New page or blank slate: Use batched content
                    nfromart_batched(curr_art, b_content[curr_art])
                }
            }
        }

        # Flush journal-offset.db -> journal.db every P["blsize"] articles
        flushjournal()

        # Log the block complete at allpages.done
        # parallelWrite(bl "-" bl+999 " " date8() " " P["numbers"], P["log"] P["key"] ".allpages.done", Engine)
        P["totalcache"] += P["misscache"]
        parallelWrite(bl "-" bl + (P["blsize"] - 1) " " date8() " " P["numbers"] " " datehms() " " P["misscache"] " (" P["misscache"] / P["blsize"] ") " P["totalcache"], P["log"] P["key"] ".allpages.done", Engine)

        # Reached end of allpages.db, prepare for next run and exit
        if(int(c) < int(P["blsize"] ) ) {
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
# Get timestamps and wiki content for up to 50 articles in one API call
# Returns a string: "Title1=Timestamp|Title2=Timestamp..."
#
# Get timestamps for up to x# articles.
# ONLY download content for articles that have changed since the last index.
# Returns a string: "Title\035Timestamp\035Content\034..."
#
function check_batch(titles_string,    urlBase, urlQuery, jsonin, jsona, i, results, id, ts, title, content, ts_map, content_map, inx_date, fetch_str, enc, urlQuery2, jsonin2, jsona2, t2, c2) {

    urlBase = "https://" Hostname "." Domain "/w/api.php"

    # =========================================================================
    # STAGE 1: Fetch Timestamps Only (Very Fast / Low Bandwidth)
    # =========================================================================
    urlQuery = "action=query&prop=revisions&titles=" titles_string "&rvprop=timestamp&format=json&formatversion=2&maxlag=10&origin=*"
        
    if(length(urlBase) + length(urlQuery) + 1 > 8000) {
      sub("[&?]origin=[*]", "", urlQuery) 
      jsonin = getjsonin(urlBase, urlQuery)
    } else {
      jsonin = getjsonin(urlBase "?" urlQuery)
    }

    if (empty(jsonin)) return ""
                
    if (query_json(jsonin, jsona) >= 0) {
        for (i = 1; ; i++) {
            id = "query" SUBSEP "pages" SUBSEP i
            if (!((id SUBSEP "title") in jsona)) break
            
            title = jsona[id SUBSEP "title"]
            ts = jsona[id SUBSEP "revisions" SUBSEP 1 SUBSEP "timestamp"]
            
            if (!empty(ts)) {
                ts = d82unix(gsubi("[-]", "", substr(ts, 1, 10)))
            } else { 
                ts = 0 
            }
            # Store the timestamp locally
            ts_map[title] = ts
        }
    }

    # =========================================================================
    # STAGE 2: Compare with local Index to build a "Needs Download" list
    # =========================================================================
    fetch_str = ""
    for (title in ts_map) {
        inx_date = 0
        if (P["index"] && !empty(Index[title]["date"])) {
            inx_date = d82unix(Index[title]["date"])
        }
        
        # If the API timestamp is newer than our index (or it's a new article)
        if (int(ts_map[title]) > int(inx_date)) {
            enc = urlencodeawk(title, "rawphp")
            if (empty(fetch_str)) fetch_str = enc
            else fetch_str = fetch_str "|" enc
        }
    }

    # =========================================================================
    # STAGE 3: Fetch Content ONLY for the changed articles
    # =========================================================================
    if (!empty(fetch_str)) {
        urlQuery2 = "action=query&prop=revisions&titles=" fetch_str "&rvprop=content&rvslots=main&format=json&formatversion=2&maxlag=10&origin=*"
        
        if(length(urlBase) + length(urlQuery2) + 1 > 8000) {
          sub("[&?]origin=[*]", "", urlQuery2)
          jsonin2 = getjsonin(urlBase, urlQuery2)
        } else {
          jsonin2 = getjsonin(urlBase "?" urlQuery2)
        }

        if (!empty(jsonin2) && query_json(jsonin2, jsona2) >= 0) {
            for (i = 1; ; i++) {
                id = "query" SUBSEP "pages" SUBSEP i
                if (!((id SUBSEP "title") in jsona2)) break
                
                t2 = jsona2[id SUBSEP "title"]
                c2 = jsona2[id SUBSEP "revisions" SUBSEP 1 SUBSEP "slots" SUBSEP "main" SUBSEP "content"]
                content_map[t2] = c2
            }
        }
    }

    # =========================================================================
    # STAGE 4: Build the final formatted string for runSearch()
    # =========================================================================
    results = ""
    for (title in ts_map) {
        # Unchanged articles will safely have an empty string for content_map[title]
        if (empty(results)) {
            results = title "\035" ts_map[title] "\035" content_map[title]
        } else {
            results = results "\034" title "\035" ts_map[title] "\035" content_map[title]
        }
    }

    return results
}


function check_batch_old(titles_string,    urlBase, urlQuery, jsonin, jsona, i, results, id, ts, title, content) {

    urlBase = "https://" Hostname "." Domain "/w/api.php"
    urlQuery = "action=query&prop=revisions&titles=" titles_string "&rvprop=timestamp|content&rvslots=main&format=json&formatversion=2&maxlag=10&origin=*"
        
    if(length(urlBase) + length(urlQuery) + 1 > 8000) {
      sub("[&?]origin=[*]", "", urlQuery)  # this breaks WMF POST for some reason but is good for GET
      jsonin = getjsonin(urlBase, urlQuery)
    }
    else 
      jsonin = getjsonin(urlBase "?" urlQuery)

    if (empty(jsonin)) return ""
               
    if (query_json(jsonin, jsona) >= 0) {
        for (i = 1; ; i++) {
            id = "query" SUBSEP "pages" SUBSEP i
            if (!((id SUBSEP "title") in jsona)) break
            
            title = jsona[id SUBSEP "title"]
            ts = jsona[id SUBSEP "revisions" SUBSEP 1 SUBSEP "timestamp"]
            # Get the actual page content from the slots
            content = jsona[id SUBSEP "revisions" SUBSEP 1 SUBSEP "slots" SUBSEP "main" SUBSEP "content"]
            
            if (!empty(ts)) {
                ts = d82unix(gsubi("[-]", "", substr(ts, 1, 10)))
            } else {
                ts = 0 
            }

            # We use a special separator \035 (Group Separator) for title/ts/content 
            # and \034 (File Separator) between articles to avoid conflicts with pipes
            if (empty(results)) {
                results = title "\035" ts "\035" content
            } else {
                results = results "\034" title "\035" ts "\035" content
            }
        }
    }
    return results
}

function check_batch_orig(titles_string,    url, jsonin, jsona, i, results, id, ts, title) {
    url = "https://" Hostname "." Domain "/w/api.php?action=query&prop=revisions&titles=" urlencodeawk(titles_string, "rawphp") "&rvprop=timestamp&format=json&formatversion=2&maxlag=10&origin=*"
               
    jsonin = getjsonin(url)
    if (empty(jsonin)) return ""
               
    if (query_json(jsonin, jsona) >= 0) {
        for (i = 0; ; i++) {
            # You must use SUBSEP here because id is a variable
            id = "query" SUBSEP "pages" SUBSEP i
            
            # Now we check if this page exists in the results
            if (!((id SUBSEP "title") in jsona)) break
            
            title = jsona[id SUBSEP "title"]
            ts = jsona[id SUBSEP "revisions" SUBSEP 0 SUBSEP "timestamp"]
            
            if (!empty(ts)) {
                ts = d82unix(gsubi("[-]", "", substr(ts, 1, 10)))
            } else {
                ts = 0 
            }

            if (empty(results)) {
                results = title "=" ts
            } else {
                results = results "|" title "=" ts
            }
        }
    }
    return results
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
          P["numbers"] = (b[1] + a[1]) "|"  (b[2] + a[2]) "|" (b[3] + a[3]) "|" (b[4] + a[4]) "|" (b[5] + a[5]) "|" (b[6] + a[6]) "|" (b[7] + a[7]) "|" (b[8] + a[8]) "|" (b[9] + a[9]) "|" (b[10] + a[10]) "|" (b[11] + a[11]) "|" (b[12] + a[12]) "|" (b[13] + a[13]) "|" (b[14] + a[14]) "|" (b[15] + a[15]) "|" (b[16] + a[16]) 
          parallelWrite(article " ---- " dateeight " ---- " numbers, P["db"] P["key"] ".journal-offset.db", Engine)

}

function nfromart(article,    a) {
    tup(getwikisource2(article, Domain, Hostname), a)
    if(empty(a[1])) {
        sleep(1)
        tup(getwikisource2(article, Domain, Hostname), a)
    }

    if (!empty(a[1])) {
        analyze_article(article, a[1])
    } else {
        parallelWrite(article " ---- " date8() " ---- " P["zeros"] " ---- fubar42 ", P["db"] P["key"] ".journal-offset.db", Engine)
    }
}
function nfromart_batched(article, content) {
    if (!empty(content)) {
        analyze_article(article, content)
    } else {
        parallelWrite(article " ---- " date8() " ---- " P["zeros"] " ---- fubar42 ", P["db"] P["key"] ".journal-offset.db", Engine)
    }
}

#
# Given an article name, increase P["numbers"] with counts from it
#  Update journal.db
#
function analyze_article(article, content,    a,g,c,cc,b,i,field,field2,iat) {

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
          #16 = number of Internet Archive items that are "dark"

    delete g

    # 1. Initialize g[1..16] array
    for(i = 1; i <= 16; i++) 
      g[i] = 0

    # 2. Wayback counts
    c = patsplit(content, field, R["iasearchre"])
    if(c > 0) { 
      g[1] = c
      g[2] = 1 
    }

    # 3. Your Alt-archive counts
    c = patsplit(content, field, R["noiasearchre"])
    if(c > 0) { 
      g[3] = c
      g[4] = 1 
    }

    c = patsplit(content, field, R["issearchre"])    # archive.is
    if(c > 0) {
      g[5] = c
      g[6] = 1
    }

    c = patsplit(content, field, R["wcsearchre"])    # webcite
    if(c > 0) {
      cc = patsplit(content, field2, "/" R["wcsearchre"])    # webcite as part of another archive URL typically archive.today
      if(cc > 0)
        c = c - cc
      if(c > 0) {
        g[7] = c
        g[8] = 1
      }
    }

    # 4. Your Google Books and IA calls
    g[9] = googleBooks(article, content)
    
    split(iaType(article, content), iat, "|")
    g[10] = int(iat[1])
    g[11] = int(iat[2])
    g[12] = int(iat[3])
    g[13] = int(iat[4])
    g[14] = int(iat[5])
    g[15] = int(iat[6])
    g[16] = int(iat[7])

    # 5. Your Final aggregation and ParallelWrite
    split(P["numbers"], b, "|")
    P["numbers"] = (b[1] + g[1]) "|" (b[2] + g[2]) "|" (b[3] + g[3]) "|" (b[4] + g[4]) "|" (b[5] + g[5]) "|" (b[6] + g[6]) "|" (b[7] + g[7]) "|" (b[8] + g[8]) "|" (b[9] + g[9]) "|" (b[10] + g[10]) "|" (b[11] + g[11]) "|" (b[12] + g[12]) "|" (b[13] + g[13]) "|" (b[14] + g[14]) "|" (b[15] + g[15])  "|" (b[16] + g[16])
    
    P["journalnumb"] = g[1] "|" g[2] "|" g[3] "|" g[4] "|" g[5] "|" g[6] "|" g[7] "|" g[8] "|" g[9] "|" g[10] "|" g[11] "|" g[12] "|" g[13] "|" g[14] "|" g[15] "|" g[16]
    
    parallelWrite(article " ---- " date8() " ---- " P["journalnumb"], P["db"] P["key"] ".journal-offset.db", Engine)
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
function allPages(    url,results,apfilterredir,aplimit,apiURL) {

        apfilterredir = "nonredirects"
        aplimit = 500
        apiURL = "https://" Hostname "." Domain "/w/api.php?"

        # Updated maxlag to 10 and added origin=*
        url = apiURL "action=query&list=allpages&aplimit=" aplimit "&apfilterredir=" apfilterredir "&apnamespace=0&format=json&formatversion=2&maxlag=10&origin=*"

        if(checkexists(P["db"] P["key"] ".allpages.db.save"))
          removefile2(P["db"] P["key"] ".allpages.db.save")

        if(! getallpages(url, apiURL, apfilterredir, aplimit) )
          return 0

        sys2var(Exe["mv"] " " P["db"] P["key"] ".allpages.db.save " P["db"] P["key"] ".allpages.db")

        return 1
}

function getallpages(url,apiURL,apfilterredir,aplimit,         jsonin,jsonout,continuecode,count,i,res_snippet,flag) {

        jsonin = getjsonin(url)
        continuecode = getcontinue(jsonin, "apcontinue")
        jsonout = json2var(jsonin)

        # Initial validation
        if (! empty(jsonin)) {
            if (! empty(jsonout))
                parallelWrite(jsonout, P["db"] P["key"] ".allpages.db.save", Engine)
        } else {
            res_snippet = "[EMPTY STRING]"
            parallelWrite("API error in getallpages (Init): Response=" res_snippet " for " url, P["log"] P["key"] ".syslog", Engine)
        }

        while ( continuecode != "-1-1!!-1-1" ) {
            url = apiURL "action=query&list=allpages&aplimit=" aplimit "&apfilterredir=" apfilterredir "&apnamespace=0&apcontinue=" urlencodeawk(continuecode, "rawphp") "&continue=" urlencodeawk("-||") "&format=json&formatversion=2&maxlag=10&origin=*"
            
            flag = 0
            # We use a small internal retry loop for stability
            for(i = 1; i <= 3; i++) {
                if(flag) break
                jsonin = getjsonin(url)
                continuecode = getcontinue(jsonin, "apcontinue")
                jsonout = json2var(jsonin)

                if (! empty(jsonin)) {
                    if (! empty(jsonout))
                        parallelWrite(jsonout, P["db"] P["key"] ".allpages.db.save", Engine)
                    flag = 1
                }
            }

            if (flag == 0) {
                res_snippet = empty(jsonin) ? "[EMPTY STRING]" : substr(jsonin, 1, 100)
                parallelWrite("API error in getallpages (Loop): Response=" res_snippet " for " url, P["log"] P["key"] ".syslog", Engine)
                break 
            }
        }
        return 1
}

#
# Get jsonin with max lag/error retries
#
function getjsonin(urlBase, urlQuery,  i,jsonin,pre,res,retries) {

            retries = 10 

            pre = "API error: "

            for(i = 1; i <= retries; i++) {

              if(empty(urlQuery)) 
                  jsonin = http2var(urlBase)  # GET
              else 
                  jsonin = http2varPOST(urlBase, urlQuery) 

              res = apierror(jsonin, "json")
              
              if( res ~ "maxlag") {
                if(i == retries) {
                  parallelWrite(pre jsonin " for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
                  email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName " Maxlag timeout in getjsonin() after " retries " tries", "")
                  runlog("remove")
                  exit
                }
                sleep(5, "unix") # Increased sleep for maxlag
              }
              else if( res ~ "error") {
                if(i == 5) {
                  parallelWrite(pre jsonin " for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
                  email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName " Error in getjsonin() after 5 tries", "")
                  runlog("remove")
                  exit
                }
                sleep(10, "unix")
              }
              else if( res ~ "empty") {
                if(i == 5) {
                  parallelWrite(pre " Received empty response for " P["key"] " ---- " curtime(), P["log"] P["key"] ".syslog", Engine)
                  email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName " Empty response in getjsonin() after 5 tries", "")
                  runlog("remove")
                  exit
                }
                sleep(15, "unix") # Jittered wait for empty responses
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
  if(match(url, /https?[:][\/]{2}(www[.])?archive[.]org[\/]details[\/][^\/ \|\]\[}{=*#<$',:;?&]+[^\/ \|\]\[}{=*#<$',:;?&]*/, d) > 0) {
    a = splitx(d[0], "[/]", 5)
    if(a ~ "https?$") sub("https?$", "", a)
    if(a ~ "[.]$") sub("[.]$", "", a)
    return strip(gsubi("\n", "", a))
  }
}

#
# Parse, count and classify archive.org/details
#
function iaType(article,fp,     url,jsonin,i,a,c,e,d,dd,r,field,sep,result,ID,mediatype,query_ids,jsona,id_idx,curr_id_raw,curr_id_norm,p_id,p_mt,res_code,meta_url,meta_json) {

  #1 = number of Internet Archive mediatype texts
  #2 = number of Internet Archive mediatype audio
  #3 = number of Internet Archive mediatype movies
  #4 = number of Internet Archive mediatype image
  #5 = number of Internet Archive mediatype other/none
  #6 = number of Internet Archive texts with page numbers
  #7 = number of Internet Archive that are "dark"

  if(fp !~ /archive.org[\/]details/) return "0|0|0|0|0|0|0"
            
  # Remove waybacks
  c = patsplit(fp, field, /web[.]archive[.]org([\/]web)?[\/][^\/]+[\/]https?[:][\/]{2}(www[.])?archive[.]org[\/]details/, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++) field[i] = ""; fp = unpatsplit(field, sep)
  }

  delete ID
  delete result
  for(i = 1; i <= splitn("texts\naudio\nmovies\nimage\nother\npages\ndark", a, i); i++) result[a[i]] = 0

  # Parse {{cite book}} templates 
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
      else if(match(field[i], /https?[:][\/]{2}(www[.])?archive[.]org[\/]details[\/][^\/ \|\]}<$,:;?&]+[^\/ \|\]}<$,:;?&]*/, d) > 0) {
        ID[++r]["id"] = getIAID(d[0])
        ID[r]["page"] = 0
      }
      field[i] = ""
    }
    fp = unpatsplit(field, sep)
  }

  # Parse everything else
  c = patsplit(fp, field, /https?[:][\/]{2}(www[.])?archive[.]org[\/]details[\/][^\/ \|\]}<$,:;?&]+[\/ \|\]}<$,:;?&]*(page[\/]n?[0-9xiv]{1,})?/, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++) {
      if(field[i] ~ /[\/]page[\/]/) {
        ID[++r]["id"] = getIAID(field[i])
        if(match(field[i], /page[\/]n?[0-9xiv]{1,}/, e) > 0) {
          ID[r]["page"] = subs("page/", "", e[0])
          ++result["pages"]
        }
      } else {
        ID[++r]["id"] = getIAID(field[i])
        ID[r]["page"] = 0
      }
      field[i] = ""
    }
    fp = unpatsplit(field, sep)
  }

  # BUILD BATCH QUERY
  if(length(ID) > 0) {
    delete seen
    query_ids = ""
    for(num in ID) {
      curr_id = ID[num]["id"]
      if (seen[tolower(curr_id)]++) continue  # Skip if we already added this ID to the string
    
      if (empty(query_ids)) 
        query_ids = "identifier%3A" curr_id
      else 
        query_ids = query_ids "+OR+identifier%3A" curr_id
    }

    url = "https://archive.org/advancedsearch.php?q=(" query_ids ")&fl%5B%5D=identifier&fl%5B%5D=mediatype&rows=50&output=json"
    jsonin = http2var(url)

    delete m_map 
    res_code = query_json(jsonin, jsona)
    
    if (res_code >= 0) {
      for (id_idx = 1; ; id_idx++) {
        p_id = "response" SUBSEP "docs" SUBSEP id_idx SUBSEP "identifier"
        p_mt = "response" SUBSEP "docs" SUBSEP id_idx SUBSEP "mediatype"
        
        if (!(p_id in jsona)) {
          if (id_idx == 1 && (("response" SUBSEP "docs" SUBSEP 0 SUBSEP "identifier") in jsona)) {
            id_idx = 0; continue
          }
          break
        }
        m_map[tolower(jsona[p_id])] = jsona[p_mt]
      }
    } 

    # RE-PROCESS ORIGINAL ID LIST
    for(num in ID) {
      curr_id_raw = ID[num]["id"]
      curr_id_norm = tolower(curr_id_raw)
      
      # 1. Try Batch Result First
      if (curr_id_norm in m_map) {
        mediatype = m_map[curr_id_norm]
      } 
      # 2. Fallback: Check Metadata API for "Dark" items
      else {
        # Check authoritative metadata API
        meta_url = "https://archive.org/metadata/" curr_id_raw
        meta_json = http2var(meta_url)

        # Check for "is_dark":true (Explicitly Dark)
        if (meta_json ~ /"is_dark":true/) {
            mediatype = "dark"
        } 
        # Check if it has a mediatype anyway (Hidden public item)
        else if (match(meta_json, /"mediatype":"([^"]+)"/, dd) > 0) {
            mediatype = dd[1]
        }
        # Fallback for restricted items that might not say "dark" but exist
        else if (meta_json ~ /"server"/) {
            mediatype = "other" 
        }
        else {
            mediatype = "error"
        }
      }

      # 3. TALLY RESULTS (Added "dark" bucket)
      if (mediatype == "texts") ++result["texts"]
      else if (mediatype == "audio") ++result["audio"]
      else if (mediatype == "movies") ++result["movies"]
      else if (mediatype == "image") ++result["image"]
      else if (mediatype == "dark") ++result["dark"]
      else {
        ++result["other"]
        if (empty(strip(mediatype))) mediatype = "error"
      }

      parallelWrite(article " ---- " strip(curr_id_raw) " ---- " strip(mediatype) " ---- " strip(ID[num]["page"]), P["db"] P["key"] ".iadetails-journal.db", Engine)

    }
  }

  return result["texts"] "|" result["audio"] "|" result["movies"] "|" result["image"] "|" result["other"] "|" result["pages"] "|" result["dark"]

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

