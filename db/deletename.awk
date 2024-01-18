#!/usr/bin/gawk -E

#
# Delete entries from a logfile based on a list of names in namefile
#
# Memory required: adjustable
#
# Test:
#    /usr/bin/time --verbose ./deletename.awk
#
# Note: this version does NOT currently support -mk
#

# The MIT License (MIT)
#
# Copyright (c) 2016-2020 by User:GreenC (at en.wikipedia.org)
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

@load "filefuncs"

BEGIN {

  # Number of re statements to stack with pipes .. too big it crushes memory too small it runs slow
  # If dealing with very large files consider a number around 75 and MemAlloc of 25
  # If smallish files consider a number around 500 w/ MemAlloc of 25
  Blocksize = 75

  # Megabytes to allocate for sort .. x2.5 approx will be max memory required.. too small it runs slow
  MemAlloc = 25

  # For WaybackMedic try 500/50 and for arcstat 75/25 w/ 256Mb memory request

  debug = 0

  delete opmode
  dups = 0

  Exe["sort"] = "/usr/bin/sort"
  Exe["comm"] = "/usr/bin/comm"
  Exe["uniq"] = "/usr/bin/uniq"
  Exe["bash"] = "/usr/bin/bash"
  Exe["mv"] = "/usr/bin/mv"

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "m:n:l:o:d")) != -1) {
    if(C == "n")
      namefile = Optarg
    if(C == "l")
      logfile = Optarg
    if(C == "o")              # optional outfile, otherwise prints to stdout
      outfile = Optarg
    if(C == "d")              # optional flag. Unique duplicate lines leaving only 1 line among the dups - good for index files
      dups = 1
    if(C == "m")              # -m <mode>  d=delete, k=keep. Default is delete. 
      opmode["arg"] = Optarg
  }

  if(!length(namefile)) {
    stdErr("Unable to open namefile: " namefile)
    exit
  }
  if(!length(logfile)) {
    stdErr("Unable to open logfile: " logfile)
    exit
  }

  if(opmode["arg"] != "k") {
    opmode["default"] = "keep"
    opmode["action"] = "delete"
  }
  else {

    print "Unsupported option"
    exit

    opmode["default"] = "delete"
    opmode["action"] = "keep"
  }

  if(logfile ~ /^index/)
    rebreak = "[|]"
  else
    rebreak = "([-]{4}|$)"

  tlog = logfile ".tlog"  # temp file for lines to be deleted

  c = split(readfile(namefile), a, "\n")

  blocks = getblocks(c)

  if(debug) {
    print "c = " c
    print "d = " d
    print "blocks = " blocks
  }

  if(!length(outfile)) {
    outfilelog = "/dev/stdout"
  }
  else {
    close(outfile)
    outfilelog = outfile ".outfilelog"
  }

  removefile2(tlog)

  for(bl = 1; bl <= blocks; bl++) {

    if(bl == 1) {
      start = bl
      end = Blocksize
    }
    else {
      start = (bl * Blocksize) - (Blocksize - 1)
      end = (bl * Blocksize)
    }

    if(debug)
      print "start = " start " ; end = " end

    out = ""
    for(i = start; i <= end; i++) {
      if(! empty(a[i]) ) {
        if (i == end || i == c-1)
          out = out regesc2(a[i])
        else
          out = out regesc2(a[i]) "|"
      }
    }

    re = "^(" out ")[ ]*" rebreak

    if(debug)
      print "re = " re

    if(!empty(out)) {
      while ((getline line < logfile) > 0) {
        if(opmode["arg"] != "k") {
          if(line ~ re ) {
            print line >> tlog                   # create a log file of every line to be deleted
            ff++
          }
        }
      }
    }

    close(logfile) # ie. rewind so getline starts over
    close(tlog)

  }

  if(ff == 0) {
    if(outfilelog == "/dev/stdout") {
      while ((getline line < logfile) > 0)
        print line >> outfilelog
    }
    exit
  }
  else {

    system("") # flush

    # Unique to file2: comm -13 <(sort file1) <(sort file2)
    # preserves duplicate lines
    # Find all in original log that are not in tlog created above, using sort and comm. Sort allows limits on memory usage.
    command = Exe["bash"] " -c " shquote(Exe["comm"] " -13 <(" Exe["sort"] " --buffer-size=" MemAlloc "M --parallel=1 " tlog ") <(" Exe["sort"] " --buffer-size=" MemAlloc "M --parallel=1 " logfile ") > " outfilelog)

    # Unique to file2: comm -13 <(sort file1 | uniq) <(sort file2 | uniq)
    # delete duplicate lines
    if(dups)
      command = Exe["bash"] " -c " shquote(Exe["comm"] " -13 <(" Exe["sort"] " --buffer-size=" MemAlloc "M --parallel=1 " tlog " | " Exe["uniq"] " ) <(" Exe["sort"] " --buffer-size=" MemAlloc "M --parallel=1 " logfile " | " Exe["uniq"] " ) > " outfilelog)

    system(command) # sys2var doesn't work
    close(command)

  }

  close(outfilelog)
  system("")
  if(length(outfile))
    sys2var(Exe["mv"] " " outfilelog " " outfile)
  for(zz = 1; zz <= 10; zz++) {
    if(removefile2(tlog))
      break
    stdErr("deletename.awk : Try " zz " of 10: Unable to delete " tlog)
    sleep(10)
  }

}

#
# Divide number of lines in file by Blocksize and return number of blocks
#  If 0.xx return 1
#  If 1.0 return 1
#  If 1.xx return 2
#
function getblocks(i,  c, e, a) {

  c = int(i) / Blocksize
  e = split(c, a, "[.]")
  if(e == 1)
    return c
  if(int(a[1]) == 0)
    return 1
  if(int(a[2]) > 0)
   return int(a[1]) + 1

}

#______________________ UTILITIES ________________________

#
# stdErr() - print s to /dev/stderr
#
#  . if flag = "n" no newline
#
function stdErr(s, flag) {
    if (flag == "n")
        printf("%s",s) > "/dev/stderr"
    else
        printf("%s\n",s) > "/dev/stderr"
    close("/dev/stderr")
}

#
# strip - strip leading/trailing whitespace
#
#   . faster than gsub() or gensub() methods eg.
#        gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
#        gensub(/^[[:space:]]+|[[:space:]]+$/,"","g",s)
#
#   Credit: https://github.com/dubiousjim/awkenough by Jim Pryor 2012
#
function strip(str) {
    if (match(str, /[^ \t\n].*[^ \t\n]/))
        return substr(str, RSTART, RLENGTH)
    else if (match(str, /[^ \t\n]/))
        return substr(str, RSTART, 1)
    else
        return ""
}

#
# Escape regex symbols
#  Caution: causes trouble with regex and [g]sub() with "&"
#  Consider instead using the non-regex literal string replacetext() in library.awk
#
function regesc2(str,   safe) {
  safe = str
  gsub(/[\\.^$(){}\[\]|*+?]/, "\\\\&", safe)
  return safe
}

#   
# empty - return 0 if string is 0-length
#
function empty(s) {           
  if(length(s) == 0)          
    return 1  
  return 0
}             

#
# shquote() - make string safe for shell
#
#  . an alternate is shell_quote.awk in /usr/local/share/awk which uses '"' instead of \'
#
#  Example:     
#     print shquote("Hello' There")    produces 'Hello'\'' There'
#     echo 'Hello'\'' There'           produces Hello' There
#
function shquote(str,  safe) {
    safe = str
    gsub(/'/, "'\\''", safe)
    gsub(/’/, "'\\’'", safe)
    return "'" safe "'"
}

#               
# exists - check for file existence
#         
#   . return 1 if exists, 0 otherwise.
#   . requirement: @load "filefuncs"
#
function exists(name    ,fd) {
    if ( stat(name, fd) == -1)
      return 0
    else
      return 1
}

# 
# readfile - same as @include "readfile"                  
#
#   . leaves an extra trailing \n just like with the @include readfile      
# 
#   Credit: https://www.gnu.org/software/gawk/manual/html_node/Readfile-Function.html by by Denis Shirokov
# 
function readfile(file,     tmp, save_rs) {
    save_rs = RS
    RS = "^$"
    getline tmp < file
    close(file)
    RS = save_rs
    return tmp
}                

#   
# sys2var() - run a system command and store result in a variable
#   
#  . supports pipes inside command string
#  . stderr is sent to null
#  . if command fails (errno) return null
#
#  Example:
#     googlepage = sys2var("wget -q -O- http://google.com")
#
function sys2var(command        ,fish, scale, ship) {

    # command = command " 2>/dev/null"
    while ( (command | getline fish) > 0 ) {
        if ( ++scale == 1 )
            ship = fish
        else
            ship = ship "\n" fish
    }
    close(command)
    system("")
    return ship
}

#
# sleep() - sleep seconds
#               
#   . Caution: systime() method eats CPU and has up-to 1 second error of margin (averge half-second)
#   . optional "unix" will spawn unix sleep
#   . Use unix sleep for applications with long or many sleeps, needing precision, or sub-second sleep
#           
function sleep(seconds,opt,   t) {    

    if (opt == "unix")                
        sys2var("sleep " seconds)
    else {
      t = systime()
      while (systime() < t + seconds) {}          
    }

}                 

#           
# exists2() - check for file existence
#
#   . return 1 if exists, 0 otherwise.
#   . no dependencies
#
function exists2(file    ,line, msg) {           
    if ((getline line < file) == -1 ) {           
        msg = (ERRNO ~ /Permission denied/ || ERRNO ~ /a directory/) ? 1 : 0
        close(file)
        return msg
    }
    else {
        close(file)
        return 1
    }                 
}              

# 
# removefile2() - delete a file/directory
#
#   . no wildcards
#   . return 1 success
#
#   Requirement: rm
#
function removefile2(str) {

    if (str ~ /[*|?]/ || empty(str))
        return 1
    system("") # Flush buffer
    if (exists2(str)) {
      sys2var("rm -r -- " shquote(str) )
      system("")
      if (! exists2(str))
        return 1
    }
    else
      return 1
    return 0
}

#
# getopt - command-line parser
# 
#   . define these globals before getopt() is called:
#        Optind = Opterr = 1
# 
#   Credit: GNU awk (/usr/local/share/awk/getopt.awk)
# 
function getopt(argc, argv, options,    thisopt, i) {

    if (length(options) == 0)    # no options given
        return -1     

    if (argv[Optind] == "--") {  # all done
        Optind++
        _opti = 0
        return -1
    } else if (argv[Optind] !~ /^-[^:[:space:]]/) {
        _opti = 0
        return -1
    }
    if (_opti == 0)
        _opti = 2
    thisopt = substr(argv[Optind], _opti, 1)
    Optopt = thisopt                
    i = index(options, thisopt)
    if (i == 0) {     
        if (Opterr)
            printf("%c -- invalid option\n", thisopt) > "/dev/stderr"
        if (_opti >= length(argv[Optind])) {
            Optind++
            _opti = 0
        } else
            _opti++
        return "?"
    }
    if (substr(options, i + 1, 1) == ":") {
        # get option argument
        if (length(substr(argv[Optind], _opti + 1)) > 0)
            Optarg = substr(argv[Optind], _opti + 1)
        else
            Optarg = argv[++Optind]
        _opti = 0
    } else
        Optarg = ""
    if (_opti == 0 || _opti >= length(argv[Optind])) {
        Optind++
        _opti = 0
    } else
        _opti++
    return thisopt
}

