test -f OVJ.exe || exit 1
rm -Rf t test.sh runtests.pl pl2exe.bat OVJ.pl lib release*.sh
find . -name .svn -prune -exec rm -Rf "{}" ";"
pushd ..; zip -r OVJ-0.971-MSWin.zip OVJ-0.971-MSWin; popd
