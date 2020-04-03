# This script checks if an 8dot3 shortname exists for a specified directory in the Program Files (x86) folder

$dirName=$Args[0]
$shortName=$Args[1]

$string=(cmd /c dir /x "C:\Program Files (x86)" | grep "$dirName")
$result=($string.split(" ")[17])

If ($result -eq ""){
	echo "Setting Shortname"
	fsutil file setshortname "C:\Program Files (x86)\$dirName" $shortName
}
