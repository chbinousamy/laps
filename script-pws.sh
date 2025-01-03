#!/bin/bash

SENSECAP_URL=$1
OID=$2
APIAccessKey=$3
EUI=$4
WINDY_API_KEY=$5

date "+%H:%M:%S %d/%m/%y"
#sudo apt -y install mosquitto-clients
echo mosquitto_sub -v -h $SENSECAP_URL -t '/device_sensor_data/${{ OID }}/${{ EUI }}/1/vs/+' -u 'org-${{ OID }}' -P '${{ APIAccessKey}}' -I 'org-${{ OID }}-quickstart' -C 10 | awk -F '[/:,{}]' '{print $7" "$9" "$11 }' >> data
mosquitto_sub -v -h $SENSECAP_URL -t /device_sensor_data/${OID}/${EUI}/1/vs/+ -u org-${OID} -P ${APIAccessKey} -I org-${OID}-quickstart -C 10 | awk -F '[/:,{}]' '{print $7" "$9" "$11 }' > data

echo && date "+%H:%M:%S %d/%m/%y" && cat data
curl_data="{\"observations\":[{\"station\":2"
#echo $curl_data
        
TIME=$(cat data | grep 4097 | awk '{printf "%d", $3}')
echo TIME=$TIME

if [ -z "$TIME" ]; then echo "TIME is blank"; else curl_data="$curl_data, \"ts\":$TIME"; fi
#echo $curl_data
        
TEMP=$(cat data | grep 4097 | awk '{printf "%.2f", $2}')
if [ -z "$TEMP" ]; then echo "TEMP is blank"; else curl_data="$curl_data, \"temp\":$TEMP"; fi
#echo $curl_data

WIND=$(cat data | grep 4105 | awk '{printf "%.2f", $2}')
if [ -z "$WIND" ]; then echo "WIND is blank"; else curl_data="$curl_data, \"wind\":$WIND"; fi
#echo $curl_data

WINDDIR=$(cat data | grep 4104 | awk '{printf "%d", $2}')
if [ -z "$WINDDIR" ]; then echo "WINDDIR is blank"; else curl_data="$curl_data, \"winddir\":$WINDDIR"; fi
# echo $curl_data

GUST=$(cat data | grep 4191 | awk '{printf "%.2f", $2}')
if [ -z "$GUST" ]; then echo "GUST is blank"; else curl_data="$curl_data, \"gust\":$GUST"; fi
# echo $curl_data

HUMIDITY=$(cat data | grep 4098 | awk '{printf "%d", $2}')
if [ -z "$HUMIDITY" ]; then echo "HUMIDITY is blank"; else curl_data="$curl_data, \"humidity\":$HUMIDITY"; fi
# echo $curl_data

if [[ -z "$TEMP" || -z "$HUMIDITY" ]]; then
	echo "One of TEMP or HUMIDITY is blank"
else
	ALPHA=$(bc -l <<< "l($HUMIDITY/100) + 17.625*$TEMP/(243.04+$TEMP)")
	DEWT=$(bc -l <<< "(243.04 * $ALPHA / (17.625 - $ALPHA))")
	DEWT=`printf "%.2f" $DEWT`
fi
if [ -z "$DEWT" ]; then echo "DEWT is blank"; else curl_data="$curl_data, \"dewpoint\":$DEWT"; fi
#echo $curl_data
        
PRESSURE=$(cat data | grep 4101 | awk '{printf "%d", $2}')
if [ -z "$PRESSURE" ]; then echo "PRESSURE is blank"; else curl_data="$curl_data, \"pressure\":$PRESSURE"; fi
#echo $curl_data
        
PRECIP=$(cat data | grep 4113 | awk '{printf "%.2f", $2}')
if [ -z "$PRECIP" ]; then echo "PRECIP is blank"; else curl_data="$curl_data, \"precip\":$PRECIP"; fi
#echo $curl_data
        
UV=$(cat data | grep 4190 | awk '{printf "%.1f", $2}')
if [ -z "$UV" ]; then echo "UV is blank"; else curl_data="$curl_data, \"uv\":$UV"; fi
#echo $curl_data

rm data
git pull
curl_data="$curl_data}]}" && echo $curl_data | jq > latest.json && cat latest.json && echo
curl -i -X POST -H "Content-Type: application/json" --data @latest.json https://stations.windy.com/pws/update/${WINDY_API_KEY}
echo 
node update_data.js
git config --global user.name 'Github Action Bot'
git config --global user.email 'githubaction-bot@users.noreply.github.com'
git commit -am "Update data with latest values"
git push
date "+%H:%M:%S %d/%m/%y"

