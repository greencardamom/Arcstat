#!/usr/local/bin/gawk -E

#
# Add new fields to index.db
#

BEGIN {

  IGNORECASE=1

#  c = split("als bar bn ca ckb cs de en es gl hu it ko lv nl no pt ru species sr sv uk zh zh-yue", a, " ")
#  c = split("als hu nl zh-yue", a, " ")
  c = split("als", a, " ")
  for(i=1;i<=c;i++) {
    fo = "/data/project/botwikiawk/arcstat/db/" a[i] ".wikipedia.org.iadetails.db"
    fn = "/data/project/botwikiawk/arcstat/db/" a[i] ".wikipedia.org.iadetails.db.new"
    while ((getline line < fo) > 0) {
      split(line, b, " ---- ")
      print b[1] " ---- " b[2] " ---- " b[3] " ---- 0"  >> fn
    }
    close(fn)
    system("")
    system("/bin/mv " fn " " fo)
  }
}
