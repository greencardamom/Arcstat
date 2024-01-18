#!/usr/bin/awk -bE

#
# Generate HTML for arcstats.awk
# https://tools-static.wmflabs.org/botwikiawk/dashboard.html
# /data/project/botwikiawk/www/static/dashboard.html

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

@include "/home/greenc/toolforge/arcstat/definearcs.awk"  # load R[] with archive definitions and RE search strings

#
# File descriptions:
#
#   ~/db/master.db          - summary results table used to build front-end 
#   ~/db/start.db           - summary results table for first month (start point)
#   

BEGIN {

  delete P
  P["db"]  = G["home"] "db/"
  P["html"] = G["home"] "www/dashclassic.html"

  main()

}

#
# Copy array from R[] -> RO[]
#
function copyArrays( i,j) {

  delete RO
  delete SO
  delete TO
  for(i in R) {
    for(j in R[i])
      RO[i][j]=R[i][j]
  }
  for(i in S) {
    for(j in S[i])
      SO[i][j]=S[i][j]
  }
  for(i in T) 
    TO[i]=T[i]

  delete R
  delete S
  delete T

}

function main() {

  # R0[] is the last entry in master.db .. created in the first invoke makeArrays()
  # R[] is the second to last  .. created in the second invoke

  if( makeArrays() ) {
    copyArrays()
    makeArrays()
    if(makePage()) {
      # Mirror output in directory on Toolforge
      sys2var(Exe["push"] " arcstat")
      sys2var(Exe["push"] " arcstat-iadetails")
    }
    else  {
      email(Exe["from_email"], Exe["to_email"], "NOTIFY: Error in makehtml.awk in makePage() - stats not uploaded.", "")
      print "Error in makehtml.awk in makePage()"
    }
  }
  else {
    email(Exe["from_email"], Exe["to_email"], "NOTIFY: Error in makehtml.awk in makeArrays() - stats not uploaded.", "")
    print "Error in makehtml.awk in makeArrays()"
  }
}


#
# Format each cell
#
function cell(arr, arri, arrv, ty,  diff,disp) {

  if(arr == "R") {
    if(ty == "int") {

      diff = int(RO[arri][arrv]) - int(R[arri][arrv])

      # If > 0 and not first run
      if(diff > 0 && diff != RO[arri][arrv]) {
        diff = "+" coma(diff)
      }
      # Add up total of first run cases so it can be subtracted below
      else if(diff > 0 && diff == RO[arri][arrv] ) {
        diff = "First run"
        firstRunTotal[arrv] = firstRunTotal[arrv] + int(RO[arri][arrv])
      }
      else if(diff < 0) {
        diff = coma(diff)
      }
      else {
        diff = "No change"
      }
      disp = coma(RO[arri][arrv])
      if(diff ~ /^(-|N|F)/)
        disp = "<span style=\"color:red;\" title=\"" diffHist(arri, arrv) "\">" disp "</span>"
      else
        disp = "<span title=\"" diffHist(arri, arrv) "\">" disp "</span>"

      diffCache = diff

    }
    else
      disp = RO[arri][arrv]

    return disp 
  }
  if(arr == "S") {
    if(ty == "int") {
      diff = int(SO[arri][arrv]) - int(S[arri][arrv])
      if(diff > 0 )
        diff = "+" coma(diff)
      else if(diff < 0)
        diff = "-" coma(diff)
      else
        diff = "No change"
      disp = coma(SO[arri][arrv])
      if(diff ~ /^(-|N)/ && arrv !~ "(iahits|althits)")
        disp = "<span style=\"color:red;\" title=\"" diff "\">" disp "</span>"
      else
        disp = "<span title=\"" diff "\">" disp "</span>"
    }
    else
      disp = SO[arri][arrv]
    return disp 
  }
  if(arr == "T") {
    if(ty == "int") {

      # Subtract prior month from current month, remove any first run data
      diff = int(TO[arri]) - int(T[arri]) - firstRunTotal[arri]

      # Show total as a cell value not a rollover
      if(arri == "iahits") 
        diffCache = coma(diff)

      if(diff > 0)
        diff = "+" coma(diff)
      else if(diff < 0)
        diff = "-" coma(diff)
      else
        diff = "No change"

      disp = coma(TO[arri])

      # disable rollover for now, try again when all start.db are in table
      if(arri ~ "(totalnew|ianew|altnew|pctia|pctalt)" && length(R) != length(SO)) 
        disp = disp
      else if(diff ~ /^(-|N)/ && arri !~ "(iahitsorigin|althitsorigin)")
        disp = "<span style=\"color:red;\" title=\"" diff "\">" disp "</span>"
      else
        disp = "<span title=\"" diff "\">" disp "</span>"

    }
    else
      disp = TO[arri]
    return disp 
  }
}


#
# Print HTML file. 
#  Return 0 on error. 1 on success.
#
function makePage( i,k) {

  if(checkexists(Home "header.html") && checkexists(Home "footer.html") ) 
    print readfile(Home "header.html") > P["html"]
  else
    return 0

  print "<center><h1><u>Dashboard Classic</u></h1></center>" >> P["html"]

  print "<center><h2>Archive Link Counts</h2></center>" >> P["html"]
#  print "<center><a href=\"https://tools-static.wmflabs.org/botwikiawk/iabotwatch.html\">Log-roll</a> - last 1,000 edits</center>" >> P["html"]
#  print "<center><a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily.html\">Daily edit calendar</a> - diffs and total</center>" >> P["html"]

  if(checkexists(Home "table1header.html") ) 
    print readfile(Home "table1header.html") >> P["html"]
  else
    return 0

  print "<tbody>" >> P["html"]

  print "<center>Each row updates once monthly on its own schedule (eg. enwiki runs on the 10th, frwiki on the 18th etc). Column C is when the row last completed. Roll-over cell for rate of change.</center><br>" >> P["html"]
  print "<center>Column headers sortable. Report by User:GreenC - This page last refreshed: " sys2var(Exe["date"] " \"+%e %B %Y\"") "</center><br>" >> P["html"]

  # print "<div class=\"highlight js\"><pre class=\"editor editor-colors\"><div class=\"line\"><span class=\"source js\"><span class=\"meta function-call js\"><span class=\"entity name function js\"><span>swal</span></span><span class=\"meta arguments js\"><span class=\"punctuation definition arguments begin bracket round js\"><span>(</span></span><span class=\"string quoted double js\"><span class=\"punctuation definition string begin js\"><span>\"</span></span><span>This modal will disappear soon!</span><span class=\"punctuation definition string end js\"><span>\"</span></span></span><span class=\"meta delimiter object comma js\"><span>,</span></span><span> </span><span class=\"meta brace curly js\"><span>{</span></span></span></span></span></div><div class=\"line\"><span class=\"source js\"><span class=\"meta function-call js\"><span class=\"meta arguments js\"><span>  buttons</span><span class=\"keyword operator js\"><span>:</span></span><span> </span><span class=\"constant language boolean false js\"><span>false</span></span><span class=\"meta delimiter object comma js\"><span>,</span></span></span></span></span></div><div class=\"line\"><span class=\"source js\"><span class=\"meta function-call js\"><span class=\"meta arguments js\"><span>  timer</span><span class=\"keyword operator js\"><span>:</span></span><span> </span><span class=\"constant numeric decimal js\"><span>3000</span></span><span class=\"meta delimiter object comma js\"><span>,</span></span></span></span></span></div><div class=\"line\"><span class=\"source js\"><span class=\"meta function-call js\"><span class=\"meta arguments js\"><span class=\"meta brace curly js\"><span>}</span></span><span class=\"punctuation definition arguments end bracket round js\"><span>)</span></span></span></span><span class=\"punctuation terminator statement js\"><span>;</span></span></span></div></pre></div><p><preview-button></preview-button></p>" >> P["html"]
    
  PROCINFO["sorted_in"] = "@ind_str_asc"
  for(k in RO) {

      #    <th>#</th>
      #    <th>Site</th>
      #    <th>Language</th>
      #    <th>Stats last updated</th>
      #    <th>Number of Articles</th>
      #    <th>Number of Wayback</th>
      #    <th>Number of Archive.is</th>
      #    <th>Number of WebCite</th>
      #    <th>Number of Other Archives</th>
      #    <th>Number of articles with Wayback links</th>
      #    <th>Number of articles with Archive.is links</th>
      #    <th>Number of articles with WebCite links</th>
      #    <th>Number of articles with Other Archive links</th>
      #    <th>IABot Origin Date</th>
      #    <th>Number of Wayback at Origin</th>
      #    <th>Number of Alt-Archives at Origin</th>

      print "  <tr>" >> P["html"]
      print "      <td>" ++i ".</td>" >> P["html"]

      print "      <td><a href=\"https://" RO[k]["site"] "/wiki/Special:Contributions/InternetArchiveBot\">" cell("R", k, "site", "str") "</a></td>" >> P["html"]
      print "      <td>" cell("S", k, "plainlang", "str") "</td>" >> P["html"]
      print "      <td>" cell("R", k, "lastdate", "str") "</td>" >> P["html"]
      print "      <td>" cell("R", k, "numberofarticles", "int") "</td>" >> P["html"]
      print "      <td>" cell("R", k, "iahits", "int") "</td>" >> P["html"]
      print "      <td>" diffCache "</td>" >> P["html"]
      print "      <td>" cell("R", k, "ishits", "int") "</td>" >> P["html"]
      print "      <td>" cell("R", k, "wchits", "int") "</td>" >> P["html"]
      print "      <td>" cell("R", k, "althits", "int") "</td>" >> P["html"]
      print "      <td>" cell("R", k, "iapages", "int") "</td>" >> P["html"]
      print "      <td>" cell("R", k, "ispages", "int") "</td>" >> P["html"]
      print "      <td>" cell("R", k, "wcpages", "int") "</td>" >> P["html"]
      print "      <td>" cell("R", k, "altpages", "int") "</td>" >> P["html"]
      print "      <td>" cell("S", k, "lastdate", "str") "</td>" >> P["html"]
      print "      <td>" cell("S", k, "iahits", "int") "</td>" >> P["html"]
      print "      <td>" cell("S", k, "althits", "int") "</td>" >> P["html"]

      print "  </tr>" >> P["html"]


  }
  print "</tbody>" >> P["html"]
  print "<tfoot>" >> P["html"]

  # Total line

  print "  <tr>" >> P["html"]
  print "      <td>TOTAL</td>" >> P["html"]                     #
  print "      <td></td>" >> P["html"]                          # 
  print "      <td></td>" >> P["html"]                          # 
  print "      <td></td>" >> P["html"]                          # 

  print "      <td>" cell("T", "numberofarticles", "", "int") "</td>" >> P["html"] # 
  print "      <td>" cell("T", "iahits", "", "int") "</td>" >> P["html"] # 
  print "      <td>" diffCache "</td>" >> P["html"]
  print "      <td>" cell("T", "ishits", "", "int") "</td>" >> P["html"] # 
  print "      <td>" cell("T", "wchits", "", "int") "</td>" >> P["html"] # 
  print "      <td>" cell("T", "althits", "", "int") "</td>" >> P["html"] # 
  print "      <td>" cell("T", "iapages", "", "int") "</td>" >> P["html"] # 
  print "      <td>" cell("T", "ispages", "", "int") "</td>" >> P["html"] # 
  print "      <td>" cell("T", "wcpages", "", "int") "</td>" >> P["html"] # 
  print "      <td>" cell("T", "altpages", "", "int") "</td>" >> P["html"] # 
  print "      <td></td>" >> P["html"]                          # 
  print "      <td>" cell("T", "iahitsorigin", "", "int") "</td>" >> P["html"] # 
  print "      <td>" cell("T", "althitsorigin", "", "int") "</td>" >> P["html"] # 
  print "  </tr>"  >> P["html"]

  print "</tfoot>" >> P["html"]
  print "</table>" >> P["html"]

  print "<br>" >> P["html"]
  # print "<p>Methods and assumptions: download each article and count number of archives therein. It can not differentiate who added the link (bot or person). Thus the \"origin date\" - when IABot first stated running on a wiki - is to help estimate the total number of links added by IABot by subtracting number of links that existed prior to IABot's origin. For example E-total minus O-total = \"Total Wayback links added since origin\" (in box below). Of this number, some additional % was added by editors manually during IAbots lifetime, estimate 50%. Thus \"Total links added by IABot\" represents \"Total links added since IABot origin\" minus 50%.</p>" >> P["html"]
  print "<p>Method: once a month, download each Wikipedia article, count the number of archive URLs therein, sum the totals. It can not differentiate who added the link (bot or person).</p>" >> P["html"]
  print "<br>" >> P["html"]

  print "<table id=\"summary\">" >> P["html"]
  print "<style type=\"text/css\">" >> P["html"]
  print "table#summary {" >> P["html"]
  print "  background-color: #f1f1c1;" >> P["html"]
  print "}" >> P["html"]
  print "table#summary tr, td {" >> P["html"]
  print "  border: 1px solid black;" >> P["html"]
  print "}" >> P["html"]
  print "</style>" >> P["html"]
  print "     <tr><td>Total archive links all providers: </td><td>" cell("T", "totalall", "", "int") "</td></tr>" >> P["html"]
  # print "     <tr><td>Total links added by IABot (est. w/ above assumptions): </td><td>" cell("T", "totalnewest", "", "int") "</td></tr>" >> P["html"]
  # print "     <tr><td>Total links added since IABot origin: </td><td>" cell("T", "totalnew", "", "int") "</td></tr>" >> P["html"]
  # print "     <tr><td>Total Wayback links added since IABot origin: </td><td>" cell("T", "ianew", "", "int") "</td></tr>" >> P["html"]
  # print "     <tr><td>Total Alt-Archive links added since IABot origin: </td><td>" cell("T", "altnew", "", "int") "</td></tr>" >> P["html"]
  print "     <tr><td>Percentage of all articles with Wayback links: </td><td>" cell("T", "pctia", "", "int") "</td></tr>" >> P["html"]
  print "     <tr><td>Percentage of all articles with Alt-Archive links: </td><td>" cell("T", "pctalt", "", "int") "</td></tr>" >> P["html"]
  print "</table>" >> P["html"]

  print "<br>" >> P["html"]
  print "<br>" >> P["html"]

  # ... Media Stats

  if(checkexists(Home "table2header.html") ) 
    print readfile(Home "table2header.html") > P["html"]
  else
    return 0

  print "<tbody>" >> P["html"]

  print "<center>Media Links https://archive.org/details/*</center><br>" >> P["html"]

  i = 0
  PROCINFO["sorted_in"] = "@ind_str_asc"
  for(k in RO) {

    #    <th><u>#</u></th>
    #    <th><u>A</u><br>Site</th>
    #    <th><u>B</u><br>Last stats update</th>
    #    <th><u>C</u><br>Mediatype texts</th>
    #    <th><u>D</u><br>Mediatype audio</th>
    #    <th><u>E</u><br>Mediatype movies</th>
    #    <th><u>F</u><br>Mediatype other</th>
    #    <th><u>G</u><br>texts with page#</th>
    #    <th><u>H</u><br>Google Books</th>

    print "  <tr>" >> P["html"]
    print "      <td>" ++i ".</td>" >> P["html"]
    print "      <td>" cell("R", k, "site", "str") "</td>" >> P["html"]
    print "      <td>" cell("S", k, "plainlang", "str") "</td>" >> P["html"]
    print "      <td>" RO[k]["lastdate"] "</td>" >> P["html"]
    print "      <td>" coma(RO[k]["iatexts"]) "</td>" >> P["html"]
    print "      <td>" coma(RO[k]["iaaudio"]) "</td>" >> P["html"]
    print "      <td>" coma(RO[k]["iamovies"]) "</td>" >> P["html"]
    print "      <td>" coma(RO[k]["iaother"]) "</td>" >> P["html"]
    print "      <td>" coma(RO[k]["iapagen"]) "</td>" >> P["html"]
    print "      <td>" coma(RO[k]["gbhits"]) "</td>" >> P["html"]
    print "  </tr>" >> P["html"]

  }

  print "</tbody>" >> P["html"]
  print "<tfoot>" >> P["html"]

  # Total line
  print "  <tr>" >> P["html"]
  print "      <td>TOTAL</td>" >> P["html"]                     #
  print "      <td></td>" >> P["html"]                          # 
  print "      <td></td>" >> P["html"]                          # 
  print "      <td></td>" >> P["html"]                          # 
  print "      <td>" coma(TO["iatexts"]) "</td>" >> P["html"]    # 
  print "      <td>" coma(TO["iaaudio"]) "</td>" >> P["html"]    # 
  print "      <td>" coma(TO["iamovies"]) "</td>" >> P["html"]   # 
  print "      <td>" coma(TO["iaother"]) "</td>" >> P["html"]    # 
  print "      <td>" coma(TO["iapagen"]) "</td>" >> P["html"]    # 
  print "      <td>" coma(TO["gbhits"]) "</td>" >> P["html"]     # 
  print "  </tr>"  >> P["html"]

  print "</tfoot>" >> P["html"]
  print "</table>" >> P["html"]

  print "</center>"  >> P["html"]

  print readfile(Home "footer.html") >> P["html"]
  close(P["html"])

  return 1

}

#
# Load and calculate numbers
# Column and Line numbers from:
#  https://docs.google.com/spreadsheets/d/1b2m7tsOlfD695crMHkJBczfHP5huSWwSGiwcIQwNzvo/edit?ts=5ba79ccc&pli=1#gid=0
#  August 1 2019
#
function makeArrays(  i,a,b,d,j,k) {

  if(checkexists(P["db"] "master.db")) {
    # nl.wikipedia.org 20190925 1979055 178863|116216|832|552|6386|4790|1496|842|0|0|0|0|0|0|0
    for(i = 1; i <= splitn(P["db"] "master.db", a, i); i++) {
      if(split(a[i], b, " ") == 4) {
        b[1] = strip(b[1]) 

        # Stop at second to last line if this is the second call to makeArrays
        if(!empty(RO[b[1]]["line"]) && i >= int(RO[b[1]]["line"])) continue

        if(b[1] ~ /[.]org/) {
          R[b[1]]["line"] = i
          R[b[1]]["site"] = b[1]
          R[b[1]]["lastdate"] = b[2]
          R[b[1]]["numberofarticles"] = b[3]
          c = split(b[4], d, /[|]/)
          if( c >= 8) {
            R[b[1]]["iahits"] = d[1]
            R[b[1]]["iapages"] = d[2]
            R[b[1]]["althits"] = d[3]
            R[b[1]]["altpages"] = d[4]
            R[b[1]]["ishits"] = d[5]
            R[b[1]]["ispages"] = d[6]
            R[b[1]]["wchits"] = d[7]
            R[b[1]]["wcpages"] = d[8]
          }
          if(c == 9) {
            R[b[1]]["gbhits"] = d[9]
          }
          else if(c > 9) {
            R[b[1]]["gbhits"] = d[9]
            R[b[1]]["iatexts"] = d[10]
            R[b[1]]["iaaudio"] = d[11]
            R[b[1]]["iamovies"] = d[12]
            R[b[1]]["iaimage"] = d[13]
            R[b[1]]["iaother"] = d[14]
            R[b[1]]["iapagen"] = d[15]
          }
        }
      }
    }
  }
  else {
    print "Unable to find " P["db"] "master.db"
    return 0
  }

  if(checkexists(P["db"] "start.db")) {
    # nl.wikipedia.org 20190925 1979055 178863|116216
    for(i = 1; i <= splitn(P["db"] "start.db", a, i); i++) {
      if(split(a[i], b, " ") == 4) {
        b[1] = strip(b[1]) 
        if(!empty(SO[b[1]]["line"]) && i >= int(SO[b[1]]["line"])) continue
        if(b[1] ~ /[.]org/) {
          S[b[1]]["site"] = b[1]
          S[b[1]]["plainlang"] = b[2]
          S[b[1]]["lastdate"] = b[3]
          S[b[1]]["line"] = i
          c = split(b[4], d, /[|]/)
          if( c >= 2) {
            S[b[1]]["iahits"] = d[1]
            S[b[1]]["althits"] = d[2]
          }
        }
      }
    }
  }
  else {
    print "Unable to find " P["db"] "start.db"
    return 0
  }


  # Column D total: "Number of articles"
  for(j in R) {
    for(k in R[j]) {
      if(k == "numberofarticles") 
        T["numberofarticles"] = T["numberofarticles"] + R[j]["numberofarticles"]
    }
  }
  # Column F total: "Number of Wayback at IABot origin"
  for(j in S) {
    if(!inarray(R, j)) continue # don't add up start.db entries that have no entry in master.db
    for(k in S[j]) {
      if(k == "iahits") {
          T["iahitsorigin"] = T["iahitsorigin"] + S[j]["iahits"]
      }
    }
  }
  # Column G total: "Number of Wayback links"
  for(j in R) {
    for(k in R[j]) {
      if(k == "iahits") 
        T["iahits"] = T["iahits"] + R[j]["iahits"]
    }
  }
  # Column H total: "Number of Alt-Archive at IABot origin"
  for(j in S) {
    if(!inarray(R, j)) continue # don't add up start.db entries that have no entry in master.db
    for(k in S[j]) {
      if(k == "althits") 
        T["althitsorigin"] = T["althitsorigin"] + S[j]["althits"]
    }
  }
  # Column I total: "Number of Alt-Archive links"
  for(j in R) {
    for(k in R[j]) {
      if(k == "althits") 
        T["althits"] = T["althits"] + R[j]["althits"]
    }
  }
  # Column J total: "Number of articles with Wayback Links"
  for(j in R) {
    for(k in R[j]) {
      if(k == "iapages") 
        T["iapages"] = T["iapages"] + R[j]["iapages"]
    }
  }
  # Column K total: "Number of articles with Alt-Archive Links"
  for(j in R) {
    for(k in R[j]) {
      if(k == "altpages") 
        T["altpages"] = T["altpages"] + R[j]["altpages"]
    }
  }

  # Column L total: "Number of Archive.is links"
  for(j in R) {
    for(k in R[j]) {
      if(k == "ishits") 
        T["ishits"] = T["ishits"] + R[j]["ishits"]
    }
  }
  # Column M total: "Number of articles with Archive.is links"
  for(j in R) {
    for(k in R[j]) {
      if(k == "ispages") 
        T["ispages"] = T["ispages"] + R[j]["ispages"]
    }
  }

  # Column N total: "Number of WebCite links"
  for(j in R) {
    for(k in R[j]) {
      if(k == "wchits") 
        T["wchits"] = T["wchits"] + R[j]["wchits"]
    }
  }
  # Column O total: "Number of articles with WebCite links"
  for(j in R) {
    for(k in R[j]) {
      if(k == "wcpages") 
        T["wcpages"] = T["wcpages"] + R[j]["wcpages"]
    }
  }


  # Line 31 (G + I + L + N)
  T["totalall"] = T["iahits"] + T["althits"] + T["ishits"] + T["wchits"]
  # Line 33 (I + L + N)
  T["totalalt"] = T["althits"] + T["ishits"] + T["wchits"]
  # Line 34 (Line 31 - (F+H))
  T["totalnew"] = T["totalall"] - (T["iahitsorigin"] + T["althitsorigin"])
  # Subtract 10%
  T["totalnewest"] = int(T["totalnew"] * 0.5)
  # Line 35 (G-F)
  T["ianew"] = T["iahits"] - T["iahitsorigin"]
  # Line 36 ( (I+L+N)-H)
  T["altnew"] = T["totalalt"] - T["althitsorigin"]
  # Line 37 ((J/D)*100)
  T["pctia"] = (T["iapages"] / T["numberofarticles"]) * 100
  # Line 38 ((K/D)*100)
  T["pctalt"] = ( (T["altpages"] + T["ispages"] + T["wcpages"]) / T["numberofarticles"]) * 100

  # ..... Media Stats chart

  # Column D total: "Mediatype texts"
  for(j in R) {
    for(k in R[j]) {
      if(k == "iatexts") 
        T["iatexts"] = T["iatexts"] + R[j]["iatexts"]
    }
  }
  # Column E total: "Mediatype audio"
  for(j in R) {
    for(k in R[j]) {
      if(k == "iatexts") 
        T["iaaudio"] = T["iaaudio"] + R[j]["iaaudio"]
    }
  }
  # Column F total: "Mediatype movies"
  for(j in R) {
    for(k in R[j]) {
      if(k == "iamovies") 
        T["iamovies"] = T["iamovies"] + R[j]["iamovies"]
    }
  }
  # Column G total: "Mediatype other"
  for(j in R) {
    for(k in R[j]) {
      if(k == "iaother") 
        T["iaother"] = T["iaother"] + R[j]["iaother"]
    }
  }
  # Column H total: "texts with page#"
  for(j in R) {
    for(k in R[j]) {
      if(k == "iapagen") 
        T["iapagen"] = T["iapagen"] + R[j]["iapagen"]
    }
  }
  # Column I total: "Number of Google Books hits"
  for(j in R) {
    for(k in R[j]) {
      if(k == "gbhits") 
        T["gbhits"] = T["gbhits"] + R[j]["gbhits"]
    }
  }

  return 1

}

# Given a line:
#   nl.wikipedia.org 20190925 1979055 178863|116216|832|552|6386|4790|1496|842|0|0|0|0|0|0|0
# Return a given key value ie. key of "1" will return 178863
#
function returnKey(line, key,  a,b,s,i,t) {

  t = "iahits=1&iapages=2&althits=3&altpages=4&ishits=5&ispages=6&wchits=7&wcpages=8&gbhits=9&iatexts=10&iaaudio=11&iamovies=12&iaimage=13&iaother=14&iapagen=15"
  s = split(t, a, /[&]/)
  for(i = 1; i <= s; i++) {
    split(a[i], b, /[=]/)
    if(b[1] == key)
      return splitx(line, "|", b[2])
  }

}

#
# Format last 12 runs for roll-over display
#
function diffHist(site,key,  i,s,b,max,result,tots,diff,loc,cal,maxruns,rk) {

  maxruns = 12

  if(checkexists(P["db"] "master.db")) {

    # nl.wikipedia.org 20190925 1979055 178863|116216|832|552|6386|4790|1496|842|0|0|0|0|0|0|0
    c = split(readfile2(P["db"] "master.db"), a, "\n")

    for(i = c; i > 1; i--) {
      if(split(a[i], b, " ") == 4) {
        b[1] = strip(b[1])
        if(b[1] == site ) {
          if(++max >= maxruns) break
          if(key == "numberofarticles")
            tots[++loc] = b[3]
          else
            tots[++loc] = returnKey(b[4], key)
        }
      }
    }
    max = loc = 0
    for(i = c; i > 1; i--) {
      if(split(a[i], b, " ") == 4) {
        b[1] = strip(b[1])
        if(b[1] == site ) {
          if(++max >= maxruns) break
          date = substr(b[2], 1, 4) "-"  substr(b[2], 5, 2) "-"  substr(b[2], 7, 2)
          loc++
          if(length(tots) >= loc+1) {
            cal = int(int(tots[loc]) - int(tots[loc+1]))
            if(cal > 0)
              diff = " +" coma(cal)
            else
              diff = " " coma(cal)
          }
          else
            diff = ""

          if(key == "numberofarticles")
            rk = b[3]
          else
            rk = returnKey(b[4], key)

          if(empty(result)) 
            result = date " = " coma(rk) diff
          else
            result = result "&#10;" date " = " coma(rk) diff
        }
      }
    }
  }
  return strip(result)

}

#
# Current time
#
function curtime() {
  return strftime("%Y%m%d-%H:%M:%S", systime(), 1)
}

#
# Add commas to a number
#
function coma(s) {
  return sprintf("%'d", s)
}

#
# Check for existence of a key in an array without triggering awk to create a table entry 
#  by the act of looking (sigh awk!)
#
function inarray(arr, key1,   j,p) {

  delete p
  for(j in arr) 
    p[j] = 1
  for(j in p) {
    if(j == key1)
      return 1
  }
  return 0

}

