#! /usr/bin/env bash

## Define Variables

#WarnThreshold=500 ## 10Gb
#ErrorThreshold=100000   ## 20Gb
WarnThreshold=$(expr $1)
ErrorThreshold=$(expr $2)

## Get Running Container IDs
containerDets=`docker ps --format "{{.Names}},{{.ID}}"`

##containerIds=$(docker ps -q)

for container in $containerDets
do
	containerName=`echo $container| cut -d, -f1`
	containerID=`echo $container| cut -d, -f2`
	#echo "Name = "$containerName
	#echo "ID = "$containerID
	workspaceSpace=$(docker exec $containerID sh -c "if [ -d /home/jenkins/workspace ] ; then du -s /home/jenkins/workspace | awk '{print $3}' ; else echo 0 ; fi" 2> /dev/null)
	workSpace=`echo $workspaceSpace|cut -d" " -f1`
	## Allow For Container With No Workspace
	if [ -z $workSpace ]; then
                workSpace=0
        fi

	## Create Lists Of Errors And Warnings
	if (( $workSpace > $ErrorThreshold ))
	then
		## Add Container Name To ErrorList
		ErrorList="$ErrorList,$containerName,$containerID"
		# echo "Errors In "$ErrorList
	else
		if (( $workSpace > $WarnThreshold )) && (( $workSpace < $ErrorThreshold ))
		then
			WarnList="$WarnList,$containerName,$containerID"
			#echo "Warnings In "$WarnList
		else
			echo "OK" > /dev/null
		fi
	fi
done

warncount=`echo $WarnList | wc -c`
errorcount=`echo $ErrorList | wc -c`

if  [ $errorcount -gt 1 ] && [ $warncount -gt 1 ]
then
        echo "CRITICAL - These Docker Containers Have Extremely Large Workspaces: "$ErrorList
	echo "WARNING - These Docker Containers Have Large Workspaces :"$WarnList
        exit 2
else
	if [ $errorcount -gt 1 ] && [ $warncount -le 1 ]
	then
		echo "CRITICAL - These Docker Containers Have Extremely Large Workspaces: "$ErrorList
		exit 2
	else
		if [ $warncount -gt 1 ]
		then
			echo "WARNING - These Docker Containers Have Large Workspaces: "$WarnList
			exit 1
		else
			echo "OK - All Workspaces Are Within Defined Limits"
			exit 0
		fi
	fi
fi
echo "UNKNOWN - PLEASE CHECK DOCKER CONTAINERS"
exit 3
