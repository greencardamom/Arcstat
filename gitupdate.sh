#
# This copies files to the GitHub repository local directory. It's required because:
#   1. git does not support following symlinks, so I can't symlink from the GitHub directory to the arcstatData directory
#   2. Also because the arcstatData is a VirtualBox shared directory, I can not symlink outbound either, because it is outside the shared directory
# The only solution is to copy the files over using cron on a regular basis.
#
# This file needs to be updated for any new files added to the GitHub repository.
#

cp --preserve=all /home/greenc/arcstatData/app.css /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/arcstat.awk /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/crontab-argos.txt /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/crontab-luego.txt /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/crontab-quepasa.txt /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/db/deletename.awk /home/greenc/Arcstat/db
cp --preserve=all /home/greenc/arcstatData/db/master.db /home/greenc/Arcstat/db
cp --preserve=all /home/greenc/arcstatData/definearcs.awk /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/footer.html /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/header.html /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/gitupdate.sh /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/makehtml.awk /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/push.csh /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/run.awk /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/start.db /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/table1header.html /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/table2header.html /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/templateNames.txt /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/trans.awk /home/greenc/Arcstat
cp --preserve=all /home/greenc/arcstatData/www/sorttable.js /home/greenc/Arcstat/www
cp --preserve=all /home/greenc/arcstatData/www/sweetalert.min.js /home/greenc/Arcstat/www

