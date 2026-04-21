@echo off
set JAVA_HOME=Dandjbr
set PATH=Cflutterbin;Dandjbrbin;%PATH%
cd d CUsersmeqdadhr_app
echo ========================================
echo Building APK...
echo ========================================
flutter build apk --release
echo ========================================
echo Done! Check the output above.
echo APK location CUsersmeqdadhr_appbuildappoutputsflutter-apk
echo ========================================
pause