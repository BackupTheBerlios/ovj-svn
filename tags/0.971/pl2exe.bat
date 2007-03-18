@echo off
echo "$Id$"
perl -v
if not errorlevel 1 (
	echo Verwende Perl aus Standard-PATH
) else if exist U:\Programme\ActivePerl\bin\perl.exe (
	set PATH=%PATH%;U:\Programme\ActivePerl\bin;U:\Programme\ActivePerl\site\bin
) else (
	echo Kann Perl nicht finden
)
pp --gui --lib lib -o OVJ.exe OVJ.pl 
