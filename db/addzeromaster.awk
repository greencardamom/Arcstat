#
# Add new fields to index.db
#

BEGIN {

    IGNORECASE=1

    fo = "/data/project/botwikiawk/arcstat/db/master.db.bak"
    fn = "/data/project/botwikiawk/arcstat/db/master.db.new"
    while ((getline line < fo) > 0) {
      split(line, a, " ")
      print a[1] " " a[2] " " a[3] " " a[4] "|0|0|0|0|0|0" >> fn
    }
    close(fn)
    system("")
#    system("/bin/mv " fn " " fo)

}
