#!/bin/bash
########################################################################
#
# AppBrand
#
# 2014 BroadSoft, Inc.
#
# This script may be used to brand an Android application binary for
# redistribution.  For details regarding the operations performed by
# this script, refer to the BroadSoft documentation:
#
#   BroadTouch (TM) Android Application Branding Guide
#
# The executor of this script accepts full responsibility for adherence
# to the distribution licensing agreements set forth by Google Inc.
# BroadSoft, Inc. is not liable for redistribution performed by
# 3rd parties.
#
########################################################################

VERSION="21.1"
BASENAME=$0
LOG_BASENAME="${BASENAME}.log"
INTERACTIVE=0

echo -e "\n**************************************************\n"
echo -e "  Branding Scripts for Android APK"
echo -e "  Version: $VERSION"
echo -e "  Copyright 2015 BroadSoft, Inc."
echo -e "\n**************************************************\n"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setup Working Environment
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#STARTTIME=$(date +%s)
TSTAMP=$(date '+%Y-%m-%d-%H%M%S')
WORKDIR_BASENAME="${BASENAME}-${TSTAMP}"
WORKDIR="./${WORKDIR_BASENAME}"
LOG="${WORKDIR}/${LOG_BASENAME}"
JARSIGNER="jarsigner"

mkdir -p "$WORKDIR"

# use some scripting log fu
exec 1> >(tee "$LOG") 2>&1
echo -e "******** Created working directory:\n\t${PWD}/${WORKDIR_BASENAME}"
echo -e "******** Creating log file: ${LOG_BASENAME}\n"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Error Exit Function
#
# $1 error message
# $2 exit code
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
errexit()
{
  echo -e "error ${2}: ${1}"
  exit $2
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Show Warning Function
#
# $1 warning message
# $2 exit code
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
showwarning()
{
  NUMOFWARNINGS=$(( $NUMOFWARNINGS + 1 ))
  echo -e ">>>> WARNING! (#$NUMOFWARNINGS): ${1}"
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Interactive Function
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
interactive() {
	if ! [ "$INTERACTIVE" -eq 0 ]; then
		echo "Please hit <ENTER> to continue..."
		read
	fi
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# List contains Function
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
listcontains() {
  for word in $1; do
    [[ $2 == $word ]] && return 0
  done
  return 1
}

unset INFILE
unset RESFOLDER
unset KEYSTORE
unset KEYALIAS
unset KEYPASS
unset STOREPASS
unset VERSIONCODE
unset BUILDID
unset CRASHLYTICSNAME
if [ -f "./appbrand.config" ]; then
	source "./appbrand.config"
else
	errexit "./appbrand.config not found!" 1
fi

BRANDINGPROP="$RESFOLDER/branding.properties"
VERSIONPROP="$RESFOLDER/version.properties"
ENABLE_V2_APK_SIGNING=true

if [ -f $BRANDINGPROP ]; then
	export PACKAGENAME=$(awk -F'=' '/app.package.name/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)
	OUTFILE0=$(awk -F'=' '/app.application.name/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)
	export ENABLE_URL_SCHEME=$(awk -F'=' '/app.enable.url.scheme/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)
	export URL_SCHEME_STRING=$(awk -F'=' '/app.url.scheme.string/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)
	export CRASHLYTICSNAME=$(awk -F'=' '/app.crashlytics.name/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)
	export BUILDID=$(awk -F'=' '/app.crashlytics.buildid/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)
  	export CRASHLYTICS_APIKEY=$(awk -F'=' '/app.crashlytics.apikey/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)
	export ALLOW_BACKUP=$(awk -F'=' '/^app.apk.allowBackup/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)
	export ENABLE_READ_CALL_LOG=$(awk -F'=' '/^app.permission.read_call_log/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)
	export DISABLE_DARK_MODE=$(awk -F'=' '/^darkmode.disabled/ {split($0,array,"=")} END {print array[2]}' $BRANDINGPROP)

	#export OUTFILE=$(awk -F'=' '/app.application.name/ {split($0,array,"=")} END {print "./" array[2] ".apk"}' $BRANDINGPROP)
  echo -e "Updating Package Name $PACKAGENAME"
	if [ -z "$PACKAGENAME" ]; then
		errexit "\"app.package.name\" is empty in $BRANDINGPROP!" 1
	fi
	if [ -z "$OUTFILE0" ]; then
		errexit "\"app.application.name\" is empty in $BRANDINGPROP!" 1
	fi
	export OUTFILE=$(echo "./"$OUTFILE0".apk")
	#echo $OUTFILE
else
	errexit "$BRANDINGPROP not found!" 1
fi


if [ -f $VERSIONPROP ]; then
	export APPVERSIONBUILD=$(awk -F'=' '/app.version.build/ {split($0,array,"=")} END {print array[2]}' $VERSIONPROP)
	if [ -z "$APPVERSIONBUILD" ]; then
		errexit "\"app.version.build\" not found/empty in $VERSIONPROP!" 1
	fi
	export VERSIONCODE=$(awk -F'=' '/app.apk.versioncode/ {split($0,array,"=")} END {print array[2]}' $VERSIONPROP)
	export APPVERSIONFULLNAME=$(awk -F'=' '/app.version.fullname/ {split($0,array,"=")} END {print array[2]}' $VERSIONPROP)
  export MIN_SDK_VERSION=$(awk -F'=' '/app.min.sdk/ {split($0,array,"=")} END {print array[2]}' $VERSIONPROP)
else
	errexit "$VERSIONPROP not found!" 1
fi

if [ -z "$KEYSTORE" ]; then
	errexit "\"KEYSTORE\" is empty in appbrand.config!" 1
fi
if [ ! -f "$KEYSTORE" ]; then
	errexit "\"$KEYSTORE\" does not exist!" 1
fi

if [ -z "$KEYALIAS" ]; then
	errexit "\"KEYALIAS\" is empty in appbrand.config!" 1
fi


if [[ $INFILE == *.aab ]]; then
    echo "Infile is App Bundle, running bundle tool"
	command -v $JARSIGNER >/dev/null || errexit "cannot find the $JARSIGNER command!" 1
    java -jar android-branding-tools.jar
    export OUTFILE=$(echo "./"$OUTFILE0".aab")

    echo -e "\n******** Signing Bundle ..."
	
	JARSIGNERPARM2=""
	JARSIGNERPARM3=""


	if [ -n "$KEYPASS" ]; then
		JARSIGNERPARM2=" -keypass ""$KEYPASS"
	fi
	if [ -n "$STOREPASS" ]; then
		JARSIGNERPARM3=" -storepass ""$STOREPASS"
	fi

	$JARSIGNER -verbose -keystore "$KEYSTORE" $JARSIGNERPARM2 $JARSIGNERPARM3 "$OUTFILE" "$KEYALIAS"
	rc=$?; test $rc -eq 0 || errexit "Failed to sign aab" $rc
	echo -e "******** Done Signing!\n"
	interactive
    
    exit
fi

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setup Internals
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
SED="sed"
unamestr=`uname`
if [ $unamestr == "Linux" ]; then
        APKTOOL="./bin/apktool"
        ZIPALIGN="./bin/zipalign"
        APKSIGNER="./bin/apksigner"
elif [ $unamestr == "Darwin" ]; then
      APKTOOL="./bin/apktool"
      APKSIGNER="./bin/apksigner"
      ZIPALIGN="./bin/zipalign-mac"
      SED="gsed"
else
        APKSIGNER="./bin/apksigner.bat"
        APKTOOL="./bin/apktool.bat"
        ZIPALIGN="./bin/zipalign.exe"
fi

echo -e "Running the script on $unamestr"

CMP="cmp"
FRAMEWORK="./bin/BT_framework.apk"
XML="xmlstarlet"
XMLTIDY="tidy"
ZIP="zip"

TEMPFOLDER="UNZIPPEDapk"
TEMPDISTFOLDER="$TEMPFOLDER/dist"
TEMPAPKFILE=$TEMPDISTFOLDER/$INFILE
UNKNOWNFOLDER="unknown"
TEMPUNKNOWNFOLDER="$TEMPFOLDER/$UNKNOWNFOLDER"
TEMPFILE=_temp
LANGFILE=_lang

NUMOFWARNINGS=0
# Language Code ISO-639-1
SUPPORTEDLANGLIST="values-aa values-ab values-ae values-af values-ak values-am values-an values-ar values-as values-av values-ay values-az values-ba values-be values-bg values-bh values-bi values-bm values-bn values-bo values-br values-bs values-ca values-ce values-ch values-co values-cr values-cs values-cu values-cv values-cy values-da values-de values-dv values-dz values-ee values-el values-en values-eo values-es values-et values-eu values-fa values-ff values-fi values-fj values-fo values-fr values-fy values-ga values-gd values-gl values-gn values-gu values-gv values-ha values-he values-hi values-ho values-hr values-ht values-hu values-hy values-hz values-ia values-id values-ie values-ig values-ii values-ik values-in values-io values-is values-it values-iu values-iw values-ja values-ji values-jv values-jw values-ka values-kg values-ki values-kj values-kk values-kl values-km values-kn values-ko values-kr values-ks values-ku values-kv values-kw values-ky values-la values-lb values-lg values-li values-ln values-lo values-lt values-lu values-lv values-mg values-mh values-mi values-mk values-ml values-mn values-mo values-mr values-ms values-mt values-my values-na values-nb values-nd values-ne values-ng values-nl values-nn values-no values-nr values-nv values-ny values-oc values-oj values-om values-or values-os values-pa values-pi values-pl values-ps values-pt values-qu values-rm values-rn values-ro values-ru values-rw values-sa values-sc values-sd values-se values-sg values-sh values-si values-sk values-sl values-sm values-sn values-so values-sq values-sr values-ss values-st values-su values-sv values-sw values-ta values-te values-tg values-th values-ti values-tk values-tl values-tn values-to values-tr values-ts values-tt values-tw values-ty values-ug values-uk values-ur values-uz values-ve values-vi values-vo values-wa values-wo values-xh values-yi values-yo values-za values-zh values-zu values-aa-r* values-ab-r* values-ae-r* values-af-r* values-ak-r* values-am-r* values-an-r* values-ar-r* values-as-r* values-av-r* values-ay-r* values-az-r* values-ba-r* values-be-r* values-bg-r* values-bh-r* values-bi-r* values-bm-r* values-bn-r* values-bo-r* values-br-r* values-bs-r* values-ca-r* values-ce-r* values-ch-r* values-co-r* values-cr-r* values-cs-r* values-cu-r* values-cv-r* values-cy-r* values-da-r* values-de-r* values-dv-r* values-dz-r* values-ee-r* values-el-r* values-en-r* values-eo-r* values-es-r* values-et-r* values-eu-r* values-fa-r* values-ff-r* values-fi-r* values-fj-r* values-fo-r* values-fr-r* values-fy-r* values-ga-r* values-gd-r* values-gl-r* values-gn-r* values-gu-r* values-gv-r* values-ha-r* values-he-r* values-hi-r* values-ho-r* values-hr-r* values-ht-r* values-hu-r* values-hy-r* values-hz-r* values-ia-r* values-id-r* values-ie-r* values-ig-r* values-ii-r* values-ik-r* values-in-r* values-io-r* values-is-r* values-it-r* values-iu-r* values-iw-r* values-ja-r* values-ji-r* values-jv-r* values-jw-r* values-ka-r* values-kg-r* values-ki-r* values-kj-r* values-kk-r* values-kl-r* values-km-r* values-kn-r* values-ko-r* values-kr-r* values-ks-r* values-ku-r* values-kv-r* values-kw-r* values-ky-r* values-la-r* values-lb-r* values-lg-r* values-li-r* values-ln-r* values-lo-r* values-lt-r* values-lu-r* values-lv-r* values-mg-r* values-mh-r* values-mi-r* values-mk-r* values-ml-r* values-mn-r* values-mo-r* values-mr-r* values-ms-r* values-mt-r* values-my-r* values-na-r* values-nb-r* values-nd-r* values-ne-r* values-ng-r* values-nl-r* values-nn-r* values-no-r* values-nr-r* values-nv-r* values-ny-r* values-oc-r* values-oj-r* values-om-r* values-or-r* values-os-r* values-pa-r* values-pi-r* values-pl-r* values-ps-r* values-pt-r* values-qu-r* values-rm-r* values-rn-r* values-ro-r* values-ru-r* values-rw-r* values-sa-r* values-sc-r* values-sd-r* values-se-r* values-sg-r* values-sh-r* values-si-r* values-sk-r* values-sl-r* values-sm-r* values-sn-r* values-so-r* values-sq-r* values-sr-r* values-ss-r* values-st-r* values-su-r* values-sv-r* values-sw-r* values-ta-r* values-te-r* values-tg-r* values-th-r* values-ti-r* values-tk-r* values-tl-r* values-tn-r* values-to-r* values-tr-r* values-ts-r* values-tt-r* values-tw-r* values-ty-r* values-ug-r* values-uk-r* values-ur-r* values-uz-r* values-ve-r* values-vi-r* values-vo-r* values-wa-r* values-wo-r* values-xh-r* values-yi-r* values-yo-r* values-za-r* values-zh-r* values-zu-r*"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Verify Execution Environment
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

command -v $APKTOOL >/dev/null || errexit "cannot find the $APKTOOL command!" 1
command -v $CMP >/dev/null || errexit "cannot find the $CMP command!" 1
if [ "$ENABLE_V2_APK_SIGNING" = false ]; then
	command -v $JARSIGNER >/dev/null || errexit "cannot find the $JARSIGNER command!" 1
fi
command -v $XML >/dev/null || errexit "cannot find the $XML command!" 1
command -v $XMLTIDY >/dev/null || errexit "cannot find the $XMLTIDY command!" 1
command -v $ZIPALIGN >/dev/null || errexit "cannot find the $ZIPALIGN command!" 1
command -v $ZIP >/dev/null || errexit "cannot find the $ZIP command!" 1
command -v $SED >/dev/null || errexit "cannot find the $SED command!. on Mac OS Please install GNU Sed using command: brew install gnu-sed" 1


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Actual Work Starts Here...
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo -e "\n******** Installing framework..."
$APKTOOL if $FRAMEWORK -t broadtouch
rc=$?; test $rc -eq 0 || errexit "Failed to install framework!" $rc
echo -e "******** Done Installing!\n"
interactive



echo -e "\n******** Decompiling..."
$APKTOOL d -f -m -t broadtouch -o $TEMPFOLDER $INFILE
rc=$?; test $rc -eq 0 || errexit "Failed to de-compile!" $rc
echo -e "******** Done Decompiling!\n"
interactive


if [ ! -d "$RESFOLDER/res" ]; then
	errexit "res folder does not exist!" 1
fi


echo -e "\n******** Copying images..."
IMAGEFOLDERSRC="$RESFOLDER/res/drawable-*"
IMAGEFOLDERDEST="$TEMPFOLDER/res"
#echo -e $IMAGEFOLDERSRC
#echo -e $IMAGEFOLDERDEST

for flder in $IMAGEFOLDERSRC
do
	#echo -e $flder
	if [ ! -d $flder ]; then
		showwarning "There are no images for branding!"
	else
		for f in $flder/*.png
		do
			if [ -d "$IMAGEFOLDERDEST/${flder##*/}/" ]; then
					TARGETF=$IMAGEFOLDERDEST/${flder##*/}/${f##*/}
					TARGETFOLDER=$IMAGEFOLDERDEST/${flder##*/}/.
			else
					drawableVersionFolder=$(echo $flder | awk '/.*drawable-.*-v.*/')
					if [ -z "$drawableVersionFolder" ]; then
						TARGETF=$IMAGEFOLDERDEST/${flder##*/}-v4/${f##*/}
						TARGETFOLDER=$IMAGEFOLDERDEST/${flder##*/}-v4/.
					else
						flder=$(echo ${flder##*/} | $SED 's/-v.//g')
						TARGETF=$IMAGEFOLDERDEST/${flder}/${f##*/}
						TARGETFOLDER=$IMAGEFOLDERDEST/${flder}/.
					fi
			fi
			if [ -f $TARGETF ]; then
				cmp -s $f $TARGETF
				if [ $? -eq 0 ]; then
					showwarning "$f has not been customized in the branding resources!"
				else
					cp -r -v $f $TARGETFOLDER
					W0=$(file -b $f | awk -F"x|," '{print $2}' | tr -d ' ')
					H0=$(file -b $f | awk -F"x|," '{print $3}' | tr -d ' ')
					W1=$(file -b $TARGETF | awk -F"x|," '{print $2}' | tr -d ' ')
					H1=$(file -b $TARGETF | awk -F"x|," '{print $3}' | tr -d ' ')
					if [ $W0 -eq $W1 ]; then
						if [ $H0 -ne $H1 ]; then
							showwarning "$f: Dimension mis-match! (Provided: $W0,$H0; Expected: $H0,$H1)"
						fi
					else
						showwarning "$f: Dimension mis-match! (Provided: $W0,$H0; Expected: $H0,$H1)"
					fi
				fi
			else
				showwarning "$TARGETF does not exist!"
			fi
		done
	fi
done
echo -e "******** Done Copying images...\n"
interactive


echo -e "\n******** Copying mipmap images..."
IMAGEFOLDERSRC="$RESFOLDER/res/mipmap-*"
IMAGEFOLDERDEST="$TEMPFOLDER/res"
#echo -e $IMAGEFOLDERSRC
#echo -e $IMAGEFOLDERDEST

for flder in $IMAGEFOLDERSRC
do
	#echo -e $flder
	if [ ! -d $flder ]; then
		showwarning "There are no images for branding!"
	else
		for f in $flder/*.png
		do
			if [ -d "$IMAGEFOLDERDEST/${flder##*/}/" ]; then
					TARGETF=$IMAGEFOLDERDEST/${flder##*/}/${f##*/}
					TARGETFOLDER=$IMAGEFOLDERDEST/${flder##*/}/.
			else
					drawableVersionFolder=$(echo $flder | awk '/.*drawable-.*-v.*/')
					if [ -z "$drawableVersionFolder" ]; then
						TARGETF=$IMAGEFOLDERDEST/${flder##*/}-v4/${f##*/}
						TARGETFOLDER=$IMAGEFOLDERDEST/${flder##*/}-v4/.
					else
						flder=$(echo ${flder##*/} | $SED 's/-v.//g')
						TARGETF=$IMAGEFOLDERDEST/${flder}/${f##*/}
						TARGETFOLDER=$IMAGEFOLDERDEST/${flder}/.
					fi
			fi
			#echo -e $TARGETF
			if [ -f $TARGETF ]; then
				cmp -s $f $TARGETF
				if [ $? -eq 0 ]; then
					showwarning "$f has not been customized in the branding resources!"
				else
					cp -r -v $f $TARGETFOLDER
					W0=$(file -b $f | awk -F"x|," '{print $2}' | tr -d ' ')
					H0=$(file -b $f | awk -F"x|," '{print $3}' | tr -d ' ')
					W1=$(file -b $TARGETF | awk -F"x|," '{print $2}' | tr -d ' ')
					H1=$(file -b $TARGETF | awk -F"x|," '{print $3}' | tr -d ' ')
					if [ $W0 -eq $W1 ]; then
						if [ $H0 -ne $H1 ]; then
							showwarning "$f: Dimension mis-match! (Provided: $W0,$H0; Expected: $H0,$H1)"
						fi
					else
						showwarning "$f: Dimension mis-match! (Provided: $W0,$H0; Expected: $H0,$H1)"
					fi
				fi
			else
				showwarning "$TARGETF does not exist!"
			fi
		done
	fi
done
echo -e "******** Done Copying mipmap images...\n"
interactive
echo -e "\n******** Copying RAW items..."
RAWFOLDERSRC="$RESFOLDER/res/raw*"
RAWFOLDERDEST="$TEMPFOLDER/res"
#echo -e $RAWFOLDERSRC
#echo -e $RAWFOLDERDEST

for flder in $RAWFOLDERSRC
do
	#echo -e $flder
	if [ ! -d $flder ]; then
		showwarning "There are no raw folders for branding!"
	else
		TARGETFOLDER=$RAWFOLDERDEST/${flder##*/}
		#echo -e $TARGETFOLDER

		if ! [ -d $TARGETFOLDER ]; then
			showwarning "New language ${flder##*/}"
			mkdir -p $TARGETFOLDER
			setfacl -b $TARGETFOLDER
		fi

		if [ -d $flder ]; then
			for f in $flder/*.*
			do
				#echo -e $f
				TARGETF=$RAWFOLDERDEST/${flder##*/}/${f##*/}
				if [ -f $TARGETF ]; then
					cp -r -v $f $RAWFOLDERDEST/${flder##*/}/.
				else
					if [ -d $TARGETFOLDER ]; then
						cp -r -v $f $RAWFOLDERDEST/${flder##*/}/.
					else
						showwarning "$TARGETFOLDER , $TARGETF does not exist!"
					fi
				fi
			done
		fi
	fi
done

echo -e "******** Done Copying RAW items...\n"
interactive

echo -e "\n******** Copying Assets items..."
ASSETSFOLDERSRC="$RESFOLDER/assets"
ASSETSFOLDERDEST="$TEMPFOLDER/assets"

cp -r -v $ASSETSFOLDERSRC/* $ASSETSFOLDERDEST/.

echo -e "******** Done Copying Assets items...\n"
interactive

echo -e "\n******** Applying Branding Changes..."
# AndroidManifest.xml
#if [ -f $BRANDINGPROP ]; then
if [ -z "$VERSIONCODE" ]; then
	APPVERSIONCODE=$(date +%s)
else
	APPVERSIONCODE=$VERSIONCODE
fi
echo -e "VersionCode $APPVERSIONCODE"
	#echo $APPVERSIONCODE
	cp -r -v $TEMPFOLDER/AndroidManifest.xml 0
	rc=$?; test $rc -eq 0 || errexit "Failed to read AndroidManifest.xml!" $rc
	ORIGPACKAGENAME=$($XML sel -T -E utf-8 -t -m "manifest" -v "@package" 0)
	export ORIGPACKAGENAME2=$(echo $ORIGPACKAGENAME | $SED 's/\./\//g')
	export ORIGPACKAGENAME2ESC=L$(echo $ORIGPACKAGENAME | $SED 's/\./\\\//g')\\/
	#echo $ORIGPACKAGENAME
	#echo $ORIGPACKAGENAME2
	#echo $ORIGPACKAGENAME2ESC

	TEMPAPPNAME0=$($XML sel -T -E utf-8 -t -m "manifest/application" -v "@android:name" 0)
	TEMPAPPNAME1=${TEMPAPPNAME0##*.}

	export APPVERSIONSTRING=$($XML sel -T -E utf-8 -t -m "manifest" -v "@android:versionName" 0)
	#echo $APPVERSIONSTRING
	APPVERSION_ARRAY=( ${APPVERSIONSTRING//./ } )
	if [ -z "$APPVERSIONFULLNAME" ]; then
		export APPVERSIONNAME="${APPVERSION_ARRAY[0]}.${APPVERSION_ARRAY[1]}.${APPVERSION_ARRAY[2]}".$APPVERSIONBUILD
	else
		export APPVERSIONNAME=$APPVERSIONFULLNAME.$APPVERSIONBUILD
	fi
	#echo $APPVERSIONNAME
CRASHLYTICSPROP="$ASSETSFOLDERDEST/crashlytics-build.properties"
if [ -f "$CRASHLYTICSPROP" ]; then
	echo -e "******** Patching Crashlytics properties...\n"
	$SED -i "s/version_name=.*/version_name=$APPVERSIONNAME/" $CRASHLYTICSPROP
	$SED -i "s/package_name=.*/package_name=$PACKAGENAME/" $CRASHLYTICSPROP
	if [ -z "$BUILDID" ]; then
		echo "Build Id Not found, not replacing"
	else
		$SED -i "s/build_id=.*/build_id=$BUILDID/" $CRASHLYTICSPROP
	fi
	$SED -i "s/version_code=.*/version_code=$APPVERSIONCODE/" $CRASHLYTICSPROP
	if [ -z "$CRASHLYTICSNAME" ]; then
		echo "CRASHLYTICSNAME not found, not replacing"
	else
		$SED -i "s/app_name=.*/app_name=$CRASHLYTICSNAME/" $CRASHLYTICSPROP
	fi
	echo -e "******** Done Patching Crashlytics properties...\n"
fi
	#$XML ed -u "manifest/@android:versionCode" -v $APPVERSIONCODE 1 > 2
	$XML ed -d "manifest/@android:versionCode" 0 > 1
	rm -f 0
	$XML ed -i "manifest" -t attr -n "android:versionCode" -v $APPVERSIONCODE 1 > 2
	rm -f 1
	#$XML ed -u "manifest/@android:versionName" -v $APPVERSIONNAME 2 > 3
	$XML ed -d "manifest/@android:versionName" 2 > 2.5
	rm -f 2
	$XML ed -i "manifest" -t attr -n "android:versionName" -v $APPVERSIONNAME 2.5 > 3
	rm -f 2.5
	$SED -i 's/\b'"$ORIGPACKAGENAME"'\b/'"$PACKAGENAME"'/g' 3
	# sed -i "s/android:authorities\=\"$ORIGPACKAGENAME\./android:authorities\=\"$PACKAGENAME\./g" 3
  $XML ed -u "manifest/@package" -v $PACKAGENAME 3 > 3.5
	rm -f 3
	$XML ed -u "manifest/application/@android:name" -v $TEMPAPPNAME0 3.5 > 4
	rm -f 3.5
	echo $ENABLE_URL_SCHEME
	if [ ! -z "$ENABLE_URL_SCHEME" ]; then
		echo "Enable URL Scheme"
		$XML ed -u "manifest/application/activity[@android:name='com.broadsoft.android.common.activity.UrlSchemeActivity']/@android:enabled" -v $ENABLE_URL_SCHEME 4 > 5
		cp -r -v 5 4
		rm -f 5
		# IRISA-3831: Connect uses alias while Communicator use Activity. Added logic to handle both.
		$XML ed -u "manifest/application/activity-alias[@android:name='com.broadsoft.android.common.activity.UrlSchemeActivity']/@android:enabled" -v $ENABLE_URL_SCHEME 4 > 5
		cp -r -v 5 4
		rm -f 5
	fi

	echo $URL_SCHEME_STRING
	if [ ! -z "$URL_SCHEME_STRING" ]; then
		echo "URL Scheme string"
		$XML ed -u "manifest/application/activity[@android:name='com.broadsoft.android.common.activity.UrlSchemeActivity']/intent-filter/data/@android:scheme" -v $URL_SCHEME_STRING 4 > 5
		cp -r -v 5 4
		rm -f 5
		# IRISA-3831: Connect uses alias while Communicator use Activity. Added logic to handle both.
		$XML ed -u "manifest/application/activity-alias[@android:name='com.broadsoft.android.common.activity.UrlSchemeActivity']/intent-filter/data/@android:scheme" -v $URL_SCHEME_STRING 4 > 5
		cp -r -v 5 4
		rm -f 5
	fi

	if [ ! -z "$ALLOW_BACKUP" ]; then
		echo "Setting allowBackup $ALLOW_BACKUP"
		$XML ed -u "manifest/application/@android:allowBackup" -v $ALLOW_BACKUP 4 > 5
		cp -r -v 5 4
		rm -f 5
	fi
  if [ ! -z "$CRASHLYTICS_APIKEY" ]; then
    echo "Updating Crashlytics API Key to $CRASHLYTICS_APIKEY"
		$XML ed -u 'manifest/application/meta-data[@android:name="io.fabric.ApiKey"]/@android:value' -v "$CRASHLYTICS_APIKEY" 4 > 5
		cp -r -v 5 4
		rm -f 5
	fi

  if [ ! -z "$MIN_SDK_VERSION" ]; then
    MANIFEST_MIN_SDK_VERSION=$($XML sel -t -v "manifest/uses-sdk/@android:minSdkVersion" 4)
    MANIFEST_TARGET_VERSION=$($XML sel -t -v "manifest/uses-sdk/@android:targetSdkVersion" 4)
    if [[ "$MIN_SDK_VERSION" -gt "$MANIFEST_MIN_SDK_VERSION" && "$MIN_SDK_VERSION" -lt "$MANIFEST_TARGET_VERSION" ]]; then
      echo "Updating Minimum SDK Version to $MIN_SDK_VERSION"
  		$XML ed -u 'manifest/uses-sdk/@android:minSdkVersion' -v "$MIN_SDK_VERSION" 4 > 5
  		cp -r -v 5 4
  		rm -f 5
    else
      echo "Ignoring Minimum SDK Version $MIN_SDK_VERSION since Manifest Min version is $MANIFEST_MIN_SDK_VERSION and target version is $MANIFEST_TARGET_VERSION"
    fi
	fi

	if [ ! -z "$ENABLE_READ_CALL_LOG" ]; then
		if [ "$ENABLE_READ_CALL_LOG" = "enabled" ]; then
	   		echo "Updating Permissions to add READ_CALL_LOG"
			xml ed -s '/manifest' -t elem -n 'uses-permission-calllog' -v "" -i '/manifest/uses-permission-calllog' -t attr -n 'android:name' -v 'android.permission.READ_CALL_LOG' -r '/manifest/uses-permission-calllog' -v 'uses-permission' 4 > 5
	  		cp -r -v 5 4
			rm -f 5
		fi
	fi

  echo "Updating Widget Provider Permission"
  $SED -i "s/com.broadsoft.connect.permission.WIDGET_PROVIDER/$PACKAGENAME.permission.WIDGET_PROVIDER/" 4

	cp -r -v 4 $TEMPFOLDER/AndroidManifest.xml
	rc=$?; test $rc -eq 0 || errexit "Failed to replace AndroidManifest.xml!" $rc
	rm -f 4




#	export PACKAGENAME2=$(echo $PACKAGENAME | sed 's/\./\//g')
#	export PACKAGENAME2ESC=L$(echo $PACKAGENAME | sed 's/\./\\\//g')\\/
#	mkdir -p $TEMPFOLDER/smali/$PACKAGENAME2
#	rc=$?; test $rc -eq 0 || errexit "Failed to create $TEMPFOLDER/smali/$PACKAGENAME2!" $rc

#	SMALISRC="$TEMPFOLDER/smali/$ORIGPACKAGENAME2/*"
#	for smalifile in $SMALISRC
#	do
		#echo -e $smalifile
#		if ! [ "${smalifile##*/}" == "$TEMPAPPNAME1"".smali" ]; then
#			cp $smalifile $TEMPFOLDER/smali/$PACKAGENAME2/.
#			rc=$?; test $rc -eq 0 || errexit "Failed to move $smalifile!" $rc
#		fi
#	done
#	chmod -R a+rw $TEMPFOLDER/smali/$PACKAGENAME2/*

	cp -r -v $TEMPFOLDER/apktool.yml 0
	rc=$?; test $rc -eq 0 || errexit "Failed to read apktool.yml!" $rc

	$SED -i 's/\b'"$ORIGPACKAGENAME"'\b/'"$PACKAGENAME"'/g' 0

	cp -r -v 0 $TEMPFOLDER/apktool.yml
	rc=$?; test $rc -eq 0 || errexit "Failed to replace apktool.yml!" $rc
	rm -f 0


	rmdir -p --ignore-fail-on-non-empty $TEMPFOLDER/smali/$ORIGPACKAGENAME2
#	find $TEMPFOLDER/smali/$PACKAGENAME2/ -type f -print0 | xargs -0 sed -i 's/'"$ORIGPACKAGENAME2ESC"'/'"$PACKAGENAME2ESC"'/g'
#fi
interactive


VALUESFOLDERSRC="$RESFOLDER/res/values"
for valfolder in $VALUESFOLDERSRC
do

	#echo -e $valfolder
	if [ ! -d $valfolder ]; then
		showwarning "There are no strings for branding!"
	else

		VALUESXMLSRC="$valfolder/*.xml"
		VALUEPWD=${valfolder##*/}
		#echo -e $VALUEPWD
		CURRENTFILE="./tmp.xml"

		if ! [ -d "$TEMPFOLDER/res/$VALUEPWD" ]; then
			showwarning "New language $VALUEPWD"
			mkdir -p "$TEMPFOLDER/res/$VALUEPWD"
		fi


		for xmlfile in $VALUESXMLSRC
		do
			#echo -e $xmlfile

			$XMLTIDY -xml -iq -utf8 -wrap 0 "$xmlfile" > "$CURRENTFILE"
			rc=$?; test $rc -eq 0 || errexit "Invalid XML file: $xmlfile!" $rc

			# Check for each strings
			$XML sel -T -E utf-8 -t -m '//string[string-length(text())=0]' -o "\t- " -v "@name" -o "\r\n" $CURRENTFILE > $TEMPFILE
			if [ -s $TEMPFILE ]; then
				STRINGS_LIST=$(cat $TEMPFILE)
				WARNING_MSG=$(echo -e "Empty string(s) found in '$xmlfile':\r\n"$STRINGS_LIST)
				showwarning "$WARNING_MSG"
			fi

			# Booleans
			OUTDATAFILE="$TEMPFOLDER/res/$VALUEPWD/bools.xml"
			#$XML sel -T -E utf-8 -t -m "resources/bool" -v "@name" -o ">" -v "." -o "" -n $CURRENTFILE > $TEMPFILE
			$XML sel -T -E utf-8 -t -m "resources/bool" -v "@name" -n $CURRENTFILE > $TEMPFILE
			if [ -s $TEMPFILE ]; then
				$XML sel -B -E utf-8 -t -m "resources/bool" -c . -n $CURRENTFILE > tmpxml_content

				if [ -f $OUTDATAFILE ]; then
					cp -r -v $OUTDATAFILE 0
				else
					echo -e "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n</resources>" > 0
				fi

				#awk -v ff=$OUTDATAFILE 'BEGIN {j=0} {split($0,array,">"); cmd="./xml ed -u \"resources/bool[@name=\\\""array[1]"\\\"]\" -v \""array[2] "\" "j; print cmd; j=j+1; system(cmd " > "j);system("rm -f " j-1)} END {system("cp -r -v " j " " ff); system("rm -f " j)}' $TEMPFILE
				awk -v xml=$XML 'BEGIN {j=0} {split($0,array,">"); cmd=xml " ed -d \"resources/bool[@name=\\\""array[1]"\\\"]\" " j; print cmd; system(cmd " > "j+1);system("rm -f " j);  j=j+1} END {system("cp -r -v " j " tmpxml_header"); system("rm -f " j)}' $TEMPFILE
				$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
				$SED -i "s/<\/resources>/ /g" tmpxml_header
				echo -e "</resources>" > tmpxml_footer
				cat tmpxml_header tmpxml_content tmpxml_footer > tmpxml
				$XMLTIDY -xml -iq -utf8 -wrap 0 tmpxml > tmpxml_final
				rc=$?; test $rc -eq 0 || errexit "Invalid XML file: bool!" $rc
				cp -r -v tmpxml_final $OUTDATAFILE
			fi


			# Integer
			OUTDATAFILE="$TEMPFOLDER/res/$VALUEPWD/integers.xml"
			#$XML sel -T -E utf-8 -t -m "resources/integer" -v "@name" -o ">" -v "." -o "" -n $CURRENTFILE > $TEMPFILE
			$XML sel -T -E utf-8 -t -m "resources/integer" -v "@name" -n $CURRENTFILE > $TEMPFILE
			if [ -s $TEMPFILE ]; then
				$XML sel -B -E utf-8 -t -m "resources/integer" -c . -n $CURRENTFILE > tmpxml_content

				if [ -f $OUTDATAFILE ]; then
					cp -r -v $OUTDATAFILE 0
				else
					echo -e "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n</resources>" > 0
				fi

				#awk -v ff=$OUTDATAFILE 'BEGIN {j=0} {split($0,array,">"); cmd="./xml ed -u \"resources/integer[@name=\\\""array[1]"\\\"]\" -v \""array[2] "\" "j; print cmd; j=j+1; system(cmd " > "j);system("rm -f " j-1)} END {system("cp -r -v " j " " ff); system("rm -f " j)}' $TEMPFILE
				awk -v xml=$XML 'BEGIN {j=0} {split($0,array,">"); cmd=xml " ed -d \"resources/integer[@name=\\\""array[1]"\\\"]\" " j; print cmd; system(cmd " > "j+1);system("rm -f " j);  j=j+1} END {system("cp -r -v " j " tmpxml_header"); system("rm -f " j)}' $TEMPFILE
				$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
				$SED -i "s/<\/resources>/ /g" tmpxml_header
				echo -e "</resources>" > tmpxml_footer
				cat tmpxml_header tmpxml_content tmpxml_footer > tmpxml
				$XMLTIDY -xml -iq -utf8 -wrap 0 tmpxml > tmpxml_final
				rc=$?; test $rc -eq 0 || errexit "Invalid XML file: integer!" $rc
				cp -r -v tmpxml_final $OUTDATAFILE
			fi

			# Items
			OUTDATAFILE="$TEMPFOLDER/res/$VALUEPWD/ids.xml"
			#$XML sel -T -E utf-8 -t -m "resources/item" -v "@name" -o ">" -v "." -o "" -n $CURRENTFILE > $TEMPFILE
			$XML sel -T -E utf-8 -t -m "resources/item" -v "@name" -n $CURRENTFILE > $TEMPFILE
			if [ -s $TEMPFILE ]; then
				$XML sel -B -E utf-8 -t -m "resources/item" -c . -n $CURRENTFILE > tmpxml_content

				if [ -f $OUTDATAFILE ]; then
					cp -r -v $OUTDATAFILE 0
				else
					echo -e "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n</resources>" > 0
				fi

				#awk -v ff=$OUTDATAFILE 'BEGIN {j=0} {split($0,array,">"); cmd="./xml ed -u \"resources/item[@name=\\\""array[1]"\\\"]\" -v \""array[2] "\" "j; print cmd; j=j+1; system(cmd " > "j);system("rm -f " j-1)} END {system("cp -r -v " j " " ff); system("rm -f " j)}' $TEMPFILE
				awk -v xml=$XML 'BEGIN {j=0} {split($0,array,">"); cmd=xml " ed -d \"resources/item[@name=\\\""array[1]"\\\"]\" " j; print cmd; system(cmd " > "j+1);system("rm -f " j);  j=j+1} END {system("cp -r -v " j " tmpxml_header"); system("rm -f " j)}' $TEMPFILE
				$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
				$SED -i "s/<\/resources>/ /g" tmpxml_header
				echo -e "</resources>" > tmpxml_footer
				cat tmpxml_header tmpxml_content tmpxml_footer > tmpxml
				$XMLTIDY -xml -iq -utf8 -wrap 0 tmpxml > tmpxml_final
				rc=$?; test $rc -eq 0 || errexit "Invalid XML file: item!" $rc
				cp -r -v tmpxml_final $OUTDATAFILE
			fi

			# Dimensions
			OUTDATAFILE="$TEMPFOLDER/res/$VALUEPWD/dimens.xml"
			#$XML sel -T -E utf-8 -t -m "resources/dimen" -v "@name" -o ">" -v "." -o "" -n $CURRENTFILE > $TEMPFILE
			$XML sel -T -E utf-8 -t -m "resources/dimen" -v "@name" -n $CURRENTFILE > $TEMPFILE
			if [ -s $TEMPFILE ]; then
				$XML sel -B -E utf-8 -t -m "resources/dimen" -c . -n $CURRENTFILE > tmpxml_content
				if [ -f $OUTDATAFILE ]; then
					cp -r -v $OUTDATAFILE 0
				else
					echo -e "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n</resources>" > 0
				fi

				#awk -v ff=$OUTDATAFILE 'BEGIN {j=0} {split($0,array,">"); cmd="./xml ed -u \"resources/dimen[@name=\\\""array[1]"\\\"]\" -v \""array[2] "\" "j; print cmd; j=j+1; system(cmd " > "j);system("rm -f " j-1)} END {system("cp -r -v " j " " ff); system("rm -f " j)}' $TEMPFILE
				awk -v xml=$XML 'BEGIN {j=0} {split($0,array,">"); cmd=xml " ed -d \"resources/dimen[@name=\\\""array[1]"\\\"]\" " j; print cmd; system(cmd " > "j+1);system("rm -f " j);  j=j+1} END {system("cp -r -v " j " tmpxml_header"); system("rm -f " j)}' $TEMPFILE
				$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
				$SED -i "s/<\/resources>/ /g" tmpxml_header
				echo -e "</resources>" > tmpxml_footer
				cat tmpxml_header tmpxml_content tmpxml_footer > tmpxml
				$XMLTIDY -xml -iq -utf8 -wrap 0 tmpxml > tmpxml_final
				rc=$?; test $rc -eq 0 || errexit "Invalid XML file: dimen!" $rc
				cp -r -v tmpxml_final $OUTDATAFILE
			fi

			# Strings
			OUTDATAFILE="$TEMPFOLDER/res/$VALUEPWD/strings.xml"
			$XML sel -T -E utf-8 -t -m "resources/string" -v "@name" -n $CURRENTFILE > $TEMPFILE
			if [ -s $TEMPFILE ]; then
				$XML sel -B -E utf-8 -t -m "resources/string" -c . -n $CURRENTFILE > tmpxml_content

				if [ -f $OUTDATAFILE ]; then
					cp -r -v $OUTDATAFILE 0
				else
					echo -e "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n</resources>" > 0
				fi

				#awk -v ff=$OUTDATAFILE 'BEGIN {j=0; _tag0="<\\/resources>"} {split($0,array,">"); cmd="./xml ed -d \"resources/string[@name=\\\""array[1]"\\\"]\" " j; print cmd; system(cmd " > "j+1);system("rm -f " j); _tag1="  <string name=\\\""array[1]"\\\">"array[2]"<\\/string>\\n<\\/resources>"; cmd2="sed -i \"s%" _tag0 "%" _tag1 "%g\" "; print cmd2; system(cmd2 " "j+1); j=j+1} END {system("cp -r -v " j " " ff); system("rm -f " j)}' $TEMPFILE
				awk -v xml=$XML 'BEGIN {j=0} {split($0,array,">"); cmd=xml " ed -d \"resources/string[@name=\\\""array[1]"\\\"]\" " j; print cmd; system(cmd " > "j+1);system("rm -f " j);  j=j+1} END {system("cp -r -v " j " tmpxml_header"); system("rm -f " j)}' $TEMPFILE
				$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
				$SED -i "s/<\/resources>/ /g" tmpxml_header
				echo -e "</resources>" > tmpxml_footer
				cat tmpxml_header tmpxml_content tmpxml_footer > tmpxml
				$XMLTIDY -xml -iq -utf8 -wrap 0 tmpxml > tmpxml_final
				rc=$?; test $rc -eq 0 || errexit "Invalid XML file: string!" $rc
				cp -r -v tmpxml_final $OUTDATAFILE
			fi

			# String Arrays "loginMenu" for connect client
			OUTDATAFILE="$TEMPFOLDER/res/$VALUEPWD/arrays.xml"
		copy_array()
		{
				if [ -f $OUTDATAFILE ]; then
					cp -r -v $OUTDATAFILE 0
				RESOURCE_ARRAY_FOUND=false

				xml_element_count=$($XML sel -t -v "count(/resources/array[@name='$1'])" 0)
				if [ "$xml_element_count" -gt 0 ]; then
					$XML ed -d "resources/array[@name='$1']" 0 > tmpxml_header
					$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
					$SED -i "s/<\/resources>/ /g" tmpxml_header
					echo -e "<array name=\"$1\">\n" > tmpxml_content
					echo -e "</array>\n</resources>" > tmpxml_footer
					RESOURCE_ARRAY_FOUND=true
				fi

				xml_element_count=$($XML sel -t -v "count(/resources/string-array[@name='$1'])" 0)
				if [ "$xml_element_count" -gt 0 ]; then
					$XML ed -d "resources/string-array[@name='$1']" 0 > tmpxml_header
					$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
					$SED -i "s/<\/resources>/ /g" tmpxml_header
					echo -e "<string-array name=\"$1\">\n" > tmpxml_content
					echo -e "</string-array>\n</resources>" > tmpxml_footer
					RESOURCE_ARRAY_FOUND=true
				fi

				xml_element_count=$($XML sel -t -v "count(/resources/integer-array[@name='$1'])" 0)
				if [ "$xml_element_count" -gt 0 ]; then
					$XML ed -d "resources/integer-array[@name='$1']" 0 > tmpxml_header
					$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
					$SED -i "s/<\/resources>/ /g" tmpxml_header
					echo -e "<integer-array name=\"$1\">\n" > tmpxml_content
					echo -e "</integer-array>\n</resources>" > tmpxml_footer
					RESOURCE_ARRAY_FOUND=true
				fi

				if [ "$RESOURCE_ARRAY_FOUND" = true ]; then
					cat tmpxml_header tmpxml_content $TEMPFILE tmpxml_footer > tmpxml
					$XMLTIDY -xml -iq -utf8 -wrap 0 tmpxml > tmpxml_final
					rc=$?; test $rc -eq 0 || errexit "Invalid XML file: $1!" $rc
					cp -r -v tmpxml_final $OUTDATAFILE
				fi
			fi

		}
		ARRAYVALUE=$($XML sel -B  -t -m "resources/array" -m "@name" -v . -n $CURRENTFILE)
		ARRAYVALUECOUNT=${#ARRAYVALUE}

		for tArray in $ARRAYVALUE
		 do
			$XML ed -d "resources/array/item/@name" $CURRENTFILE | $XML sel -B  -t -m "resources/array[@name='$tArray']/item" -c . -n > $TEMPFILE
			if [ "$tArray" == "languageValues" ]; then
				$XML sel -T -E utf-8 -t -m "resources/string-array[@name='languageValues']/item" -v "@name" -o ">" -v "." -o "" -n $CURRENTFILE > $LANGFILE
			fi
			copy_array $tArray

		done


		ARRAYVALUE=$($XML sel -B  -t -m "resources/string-array" -m "@name" -v . -n $CURRENTFILE)
		ARRAYVALUECOUNT=${#ARRAYVALUE}

		for tArray in $ARRAYVALUE
		 do
			$XML ed -d "resources/string-array/item/@name" $CURRENTFILE | $XML sel -B  -t -m "resources/string-array[@name='$tArray']/item" -c . -n > $TEMPFILE
			if [ "$tArray" == "languageValues" ]; then
				$XML sel -T -E utf-8 -t -m "resources/string-array[@name='languageValues']/item" -v "@name" -o ">" -v "." -o "" -n $CURRENTFILE > $LANGFILE
			fi
			copy_array $tArray
		done


	ARRAYVALUE=$($XML sel -B  -t -m "resources/integer-array" -m "@name" -v . -n $CURRENTFILE)
	ARRAYVALUECOUNT=${#ARRAYVALUE}

		for tArray in $ARRAYVALUE
		 do
			$XML ed -d "resources/integer-array/item/@name" $CURRENTFILE | $XML sel -B  -t -m "resources/integer-array[@name='$tArray']/item" -c . -n > $TEMPFILE
			if [ "$tArray" == "languageValues" ]; then
				$XML sel -T -E utf-8 -t -m "resources/string-array[@name='languageValues']/item" -v "@name" -o ">" -v "." -o "" -n $CURRENTFILE > $LANGFILE
			fi
			copy_array $tArray

		done

			# Colors
			OUTDATAFILE="$TEMPFOLDER/res/$VALUEPWD/colors.xml"
			#$XML sel -T -E utf-8 -t -m "resources/color" -v "@name" -o ">" -v "." -o "" -n $CURRENTFILE > $TEMPFILE
			$XML sel -T -E utf-8 -t -m "resources/color" -v "@name" -n $CURRENTFILE > $TEMPFILE
			if [ -s $TEMPFILE ]; then
				$XML sel -B -E utf-8 -t -m "resources/color" -c . -n $CURRENTFILE > tmpxml_content
				if [ -f $OUTDATAFILE ]; then
					cp -r -v $OUTDATAFILE 0
				else
					echo -e "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n</resources>" > 0
				fi

				#awk -v ff=$OUTDATAFILE 'BEGIN {j=0} {split($0,array,">"); cmd="./xml ed -u \"resources/color[@name=\\\""array[1]"\\\"]\" -v \""array[2] "\" "j; print cmd; j=j+1; system(cmd " > "j);system("rm -f " j-1)} END {system("cp -r -v " j " " ff); system("rm -f " j)}' $TEMPFILE
				awk -v xml=$XML 'BEGIN {j=0} {split($0,array,">"); cmd=xml " ed -d \"resources/color[@name=\\\""array[1]"\\\"]\" " j; print cmd; system(cmd " > "j+1);system("rm -f " j);  j=j+1} END {system("cp -r -v " j " tmpxml_header"); system("rm -f " j)}' $TEMPFILE
				$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
				$SED -i "s/<\/resources>/ /g" tmpxml_header
				echo -e "</resources>" > tmpxml_footer
				cat tmpxml_header tmpxml_content tmpxml_footer > tmpxml
				$XMLTIDY -xml -iq -utf8 -wrap 0 tmpxml > tmpxml_final
				rc=$?; test $rc -eq 0 || errexit "Invalid XML file: color!" $rc
				cp -r -v tmpxml_final $OUTDATAFILE
			fi
		done
	fi
done

#echo $SUPPORTEDLANGLIST

echo -e "\n******** Cleaning up language files..."
if [ -s $LANGFILE ]; then
	export brandinglanglist=$(awk '{split($0,array,">"); print " values-" array[2]}' $LANGFILE)
	echo -e "\n******** Language(s) to be supported:\n$brandinglanglist \n********\n"

	TVALUESFOLDERSRC="$TEMPFOLDER/res/values-*"
	for tvalfolder in $TVALUESFOLDERSRC
	do
		TVALUEPWD=${tvalfolder##*/}
		#echo $TVALUEPWD

		if listcontains "$SUPPORTEDLANGLIST" $TVALUEPWD; then
			if listcontains "$brandinglanglist" $TVALUEPWD; then
				echo "+Keeping $TVALUEPWD...";
			else
#				if [ "$TVALUEPWD" != "values-sv" ]; then
#					if [ "$TVALUEPWD" != "values-tr" ]; then
						echo "-Removing $TVALUEPWD...";
						rm -f $tvalfolder/*
						rmdir $tvalfolder
#					else
#						echo "Keeping $TVALUEPWD for now...";
#					fi
#				else
#					echo "Keeping $TVALUEPWD for now...";
#				fi
			fi
		else
			echo "!Not a language: $TVALUEPWD...";
		fi
	done


	TRAWFOLDERSRC="$TEMPFOLDER/res/raw-*"
	for trawfolder in $TRAWFOLDERSRC
	do
		TRAWPWD=${trawfolder##*/}
		TVALUEPWD=$(echo $TRAWPWD | awk '{split($0,array,"-"); print "values-" array[2]}')

		if listcontains "$SUPPORTEDLANGLIST" $TVALUEPWD; then
			if listcontains "$brandinglanglist" $TVALUEPWD; then
				echo "+Keeping $TRAWPWD...";
			else
				echo "-Removing $TRAWPWD... $trawfolder";
				rm -f $trawfolder/*
				rmdir $trawfolder
			fi
		else
			echo "!Not a language: $TVALUEPWD...";
		fi
	done
fi
echo -e "******** Done Cleaning up language files...\n"
interactive


VALUESFOLDERSRC="$RESFOLDER/res/values-*"
for valfolder in $VALUESFOLDERSRC
do

	#echo -e $valfolder
	if [ ! -d $valfolder ]; then
		showwarning "There are no strings for branding!"
	else

		VALUESXMLSRC="$valfolder/*.xml"
		VALUEPWD=${valfolder##*/}
		#echo -e $VALUEPWD
		CURRENTFILE="./tmp.xml"

		if listcontains "$brandinglanglist" $VALUEPWD; then

			if ! [ -d "$TEMPFOLDER/res/$VALUEPWD" ]; then
				showwarning "New language $VALUEPWD"
				mkdir -p "$TEMPFOLDER/res/$VALUEPWD"
			fi


			for xmlfile in $VALUESXMLSRC
			do
				#echo -e $xmlfile

				$XMLTIDY -xml -iq -utf8 -wrap 0 "$xmlfile" > "$CURRENTFILE"
				rc=$?; test $rc -eq 0 || errexit "Invalid XML file: $xmlfile!" $rc

				# Check for each strings
				$XML sel -T -E utf-8 -t -m '//string[string-length(text())=0]' -o "\t- " -v "@name" -o "\r\n" $CURRENTFILE > $TEMPFILE
				if [ -s $TEMPFILE ]; then
					STRINGS_LIST=$(cat $TEMPFILE)
					WARNING_MSG=$(echo -e "Empty string(s) found in '$xmlfile':\r\n"$STRINGS_LIST)
					showwarning "$WARNING_MSG"
				fi

				# Strings
				OUTDATAFILE="$TEMPFOLDER/res/$VALUEPWD/strings.xml"
				$XML sel -T -E utf-8 -t -m "resources/string" -v "@name" -n $CURRENTFILE > $TEMPFILE
				if [ -s $TEMPFILE ]; then
					$XML sel -B -E utf-8 -t -m "resources/string" -c . -n $CURRENTFILE > tmpxml_content

					if [ -f $OUTDATAFILE ]; then
						cp -r -v $OUTDATAFILE 0
					else
						echo -e "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n</resources>" > 0
					fi

					#awk -v ff=$OUTDATAFILE 'BEGIN {j=0; _tag0="<\\/resources>"} {split($0,array,">"); cmd="./xml ed -d \"resources/string[@name=\\\""array[1]"\\\"]\" " j; print cmd; system(cmd " > "j+1);system("rm -f " j); _tag1="  <string name=\\\""array[1]"\\\">"array[2]"<\\/string>\\n<\\/resources>"; cmd2="sed -i \"s%" _tag0 "%" _tag1 "%g\" "; print cmd2; system(cmd2 " "j+1); j=j+1} END {system("cp -r -v " j " " ff); system("rm -f " j)}' $TEMPFILE
					awk -v xml=$XML 'BEGIN {j=0} {split($0,array,">"); cmd=xml " ed -d \"resources/string[@name=\\\""array[1]"\\\"]\" " j; print cmd; system(cmd " > "j+1);system("rm -f " j);  j=j+1} END {system("cp -r -v " j " tmpxml_header"); system("rm -f " j)}' $TEMPFILE
					$SED -i "s/<resources\/>/<resources>\n<\/resources>/g" tmpxml_header
					$SED -i "s/<\/resources>/ /g" tmpxml_header
					echo -e "</resources>" > tmpxml_footer
					cat tmpxml_header tmpxml_content tmpxml_footer > tmpxml
					$XMLTIDY -xml -iq -utf8 -wrap 0 tmpxml > tmpxml_final
					rc=$?; test $rc -eq 0 || errexit "Invalid XML file: string!" $rc
					cp -r -v tmpxml_final $OUTDATAFILE
				fi

			done
		elif [[ "$valfolder" =~ .*"values-night".* ]]; then
			if ! [ -d "$TEMPFOLDER/res/$TVALUEPWD" ]; then
				showwarning "New values $TVALUEPWD"
				mkdir -p "$TEMPFOLDER/res/$TVALUEPWD"
			fi
			for xmlfile in $VALUESXMLSRC
			do
				cp -r -v $xmlfile "$TEMPFOLDER/res/$VALUEPWD/".
			done
		else
			showwarning "Translation is provided for $VALUEPWD, but is not specified in the language list!"
		fi
	fi
done

cp -r -v $TEMPFOLDER/res/values/strings.xml 0
rc=$?; test $rc -eq 0 || errexit "Failed to read strings.xml!" $rc

$XML ed -u "resources/string[@name='account_type']" -v $PACKAGENAME 0 > 1
rm -f 0
cp -r -v 1 $TEMPFOLDER/res/values/strings.xml
rc=$?; test $rc -eq 0 || errexit "Failed to replace account_type in strings.xml!" $rc
rm -f 1

if [ -f $LANGFILE ]; then
	rm -f $LANGFILE
fi

if [ -f $CURRENTFILE ]; then
	rm -f $CURRENTFILE
fi

if [ -f $TEMPFILE ]; then
	rm -f $TEMPFILE
fi

if [ -d $UNKNOWNFOLDER ]; then
	rm -r $UNKNOWNFOLDER
fi

rm -f tmpxml_header tmpxml_content tmpxml_footer tmpxml tmpxml_final

if [ ! -z "$DISABLE_DARK_MODE" ]; then
	if [ "$DISABLE_DARK_MODE" = "true" ]; then
	   	echo "Night mode isdisabled"
		rm -rf $TEMPFOLDER/res/*-night*
		cp -r -v $TEMPFOLDER/res/values/public.xml 0
		rc=$?; test $rc -eq 0 || errexit "Failed to read public.xml!" $rc
		$XML ed -d "resources/public[@name='disableDarkMode']" 0 > 1
		rm -f 0
		cp -r -v 1 $TEMPFOLDER/res/values/public.xml
		rc=$?; test $rc -eq 0 || errexit "Failed to delete disableDarkMode in public.xml!" $rc
		rm -f 1
	fi
fi


#echo $TEMPUNKNOWNFOLDER
#if [ -d $TEMPUNKNOWNFOLDER ]; then
#	echo -e "\nMoving APK extras from $TEMPUNKNOWNFOLDER...\n"
#	cp -r -v $TEMPUNKNOWNFOLDER .
#	rc=$?; test $rc -eq 0 || errexit "Failed to prepare extras for APK!" $rc
#	rm -r $TEMPUNKNOWNFOLDER
#fi
echo -e "******** Done Applying Branding Changes...\n"
interactive



echo -e "\n******** Building \"Dist\" Folder..."
$APKTOOL b -t broadtouch $TEMPFOLDER
rc=$?; test $rc -eq 0 || errexit "Failed to rebuild!" $rc
echo -e "******** Done Building!\n"
interactive

METAINFOLDER=./META-INF

echo -e "\n******** Adding META-INFO files to APK..."
if [ -d $TEMPFOLDER/original/META-INF/ ]; then
    mkdir ./META-INF
    cp -r -v $TEMPFOLDER/original/META-INF/* ./META-INF
    rm $METAINFOLDER/*.MF
    rm $METAINFOLDER/*.RSA
    rm $METAINFOLDER/*.SF
    if [ "$(ls -A $METAINFOLDER)" ]; then
        chmod -R a+rw "$METAINFOLDER"
        cp -r -v "$TEMPAPKFILE" ./temp.zip
        #cd $METAINFOLDER
        $ZIP -r ./temp.zip $METAINFOLDER/*
		rc=$?; test $rc -eq 0 || errexit "Failed to add META-INFO to APK!" $rc
		cp -r -v ./temp.zip "$TEMPAPKFILE"

		rc=$?; test $rc -eq 0 || errexit "Failed to copy updated APK!" $rc
		rm ./temp.zip
	fi
	rm -r $METAINFOLDER
fi
echo -e "\n******** Done Adding!"
interactive


echo -e "\n******** Adding extras to APK..."
if [ -d $UNKNOWNFOLDER ]; then
	chmod -R a+rw "$UNKNOWNFOLDER"
	cp -r -v "$TEMPAPKFILE" ./temp.zip
	cd $UNKNOWNFOLDER
	$ZIP -r ../temp.zip *
	rc=$?; test $rc -eq 0 || errexit "Failed to add extras to APK!" $rc
	cd ..
	cp -r -v ./temp.zip "$TEMPAPKFILE"
	rc=$?; test $rc -eq 0 || errexit "Failed to copy updated APK!" $rc
	rm ./temp.zip
	rm -r $UNKNOWNFOLDER
fi
echo -e "\n******** Done Adding!"
interactive



echo -e "\n******** Signing..."
#JARSIGNERPARM1=""
JARSIGNERPARM2=""
JARSIGNERPARM3=""

APKSIGNERPARM2=""
APKSIGNERPARM3=""


#if [ -n "$KEYSTORE" ]; then
#	JARSIGNERPARM1=" -keystore ""$KEYSTORE"
#fi
if [ -n "$KEYPASS" ]; then
	JARSIGNERPARM2=" -keypass ""$KEYPASS"
  APKSIGNERPARM2=" --key-pass pass:$KEYPASS"
fi
if [ -n "$STOREPASS" ]; then
	JARSIGNERPARM3=" -storepass ""$STOREPASS"
  APKSIGNERPARM3="--ks-pass pass:$STOREPASS"
fi
# IRISA-5119
# $JARSIGNER -verbose -sigalg MD5withRSA -digestalg SHA1 -keystore "$KEYSTORE" $JARSIGNERPARM2 $JARSIGNERPARM3 "$TEMPAPKFILE" "$KEYALIAS"
if [ "$ENABLE_V2_APK_SIGNING" = false ]; then
	$JARSIGNER -verbose -keystore "$KEYSTORE" $JARSIGNERPARM2 $JARSIGNERPARM3 "$TEMPAPKFILE" "$KEYALIAS"
	rc=$?; test $rc -eq 0 || errexit "Failed to sign APK V1!" $rc
	echo -e "******** Done Signing!\n"
	interactive



	echo -e "\n******** Verifying..."
	$JARSIGNER -verify  -verbose -certs "$TEMPAPKFILE"
	rc=$?; test $rc -eq 0 || errexit "Failed to verify APK!" $rc
	echo -e "******** Done Verifying!\n"
	interactive
fi

echo -e "\n******** Zipaligning..."
if [ -f "$OUTFILE" ]; then
	rm "$OUTFILE"
fi
$ZIPALIGN -v 4 "$TEMPAPKFILE" "$OUTFILE"
rc=$?; test $rc -eq 0 || errexit "Failed to zipalign APK!" $rc
echo -e "******** Done Zipaligning!\n"

if [ "$ENABLE_V2_APK_SIGNING" = true ]; then
  echo -e "\n******** APK V2 Signing..."
  $APKSIGNER sign --ks "$KEYSTORE" --ks-key-alias "$KEYALIAS" $APKSIGNERPARM2 $APKSIGNERPARM3 "$OUTFILE"
  rc=$?; test $rc -eq 0 || errexit "Failed to sign APK V2!" $rc
  echo -e "\n******** Done APK V2 Signing..."
fi


rm -r $TEMPFOLDER


echo -e "\n******** Total Number of Warnings: $NUMOFWARNINGS"
echo -e "\n******** \"$OUTFILE\" is generated successfully.\n"

#ENDTIME=$(date +%s)
#echo -e "\nTime taken: $(($ENDTIME - $STARTTIME)) seconds.\n\n"
