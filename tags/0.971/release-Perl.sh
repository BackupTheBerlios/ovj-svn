test -f OVJ.exe && rm OVJ.exe
rm -Rf t test.sh runtests.pl pl2exe.bat release*.sh
find . -name .svn -prune -exec rm -Rf "{}" ";"
pushd ..; zip -r OVJ-0.971-Perl.zip OVJ-0.971-Perl; popd
