$dirName=$Args[0]
$shortName=$Args[1]

$string=(cmd /c dir /x "C:\Program Files (x86)" | grep "$dirName")
$result=($string.split(" ")[17])

If ($result -eq ""){
	echo "Setting Shortname"
	fsutil file setshortname "C:\Program Files (x86)\$dirName" $shortName
}
