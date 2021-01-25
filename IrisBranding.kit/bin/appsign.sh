#!/bin/bash

########################################################################
#
# iOS Application Signer
#
# 2016 BroadSoft, Inc.
#
# This script may be used to re-sign an iOS application binary for
# redistribution.  For details regarding the operations performed by
# this script, refer to the BroadSoft documentation:
#
#   BroadTouch (TM) iOS Application Deployment Guide
#
# The executor of this script accepts full responsibility for adherence
# to the distribution licensing agreements set forth by Apple Inc.
# BroadSoft, Inc. is not liable for redistribution performed by
# 3rd parties.
#
########################################################################

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Define Application Variables
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# constants
declare -r SCRIPTNAME=$(basename $0)
declare -r SCRIPTDIR=$(dirname $0)
declare -r SCRIPTBASE="${SCRIPTNAME%.*}"
declare -r COMMANDLINE="${@}"
declare -r ENVIRONMENT="${SCRIPTDIR}/.appsign.env"
declare -r LOG_BASENAME="${SCRIPTBASE}.log"
declare -r DBGLOG_BASENAME="${SCRIPTBASE}.debug.log"

# static variables (set once, used throughout)
declare -i MANUALPROMPT=0
declare TSTAMP
declare WORKDIR_BASENAME

# load environment
source "$ENVIRONMENT"
test $? -eq 0 || \
  { echo "failed to load environment: ${ENVIRONMENT}"; exit 1; }

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Command Syntax Function
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function commandSyntax ()
{
cat << !!syntax
usage: ${SCRIPTNAME} [-ypdvh] <app> <profile> <bundleId> <App Extension Profiles>
!!syntax
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Usage Function
#
# $1: exit code
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function usageExit ()
{
commandSyntax
cat << !!usage
Try '${SCRIPTNAME} -h' for more information.
!!usage

exit $1
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Help Exit Function
#
# $1: exit code
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function helpExit ()
{
commandSyntax
cat << !!help

Re-signs an iOS application.  No source files are overwritten, and all
output is stored in a new directory that is named using the following
time stamp format:
   ${SCRIPTBASE}-yyyy-mm-dd-HHMMSS

<app>
   The iOS Application to re-sign.  This may be either an application
   content directory (ending with a '.app' file extension) or an
   application archive (ending with a '.ipa' file extension).

<profile>
   The provisioning profile that specifies how the application will be
   distributed.  This file should be downloaded from the Apple developer
   web site:
   https://developer.apple.com/account/ios/profile/profileList.action

<bundleId>
   A Bundle ID that is compatible with the ID specified in the provisioning
   profile.

 <App Extension profiles>
    The App Extension provisioning profile that specifies how the extension will be
    distributed. This file is needed if the application has any extension and optional if not.
    This file should be downloaded from the Apple developer
    web site:
    https://developer.apple.com/account/ios/profile/profileList.action

    If the application contains multiple extensions then the profiles should be mentioned in the following format:
    Extension Name:Provisioning Profile Path

    Example: ./bin/appsign.sh ./Teams.app/ ./teams.mobileprovision com.broadsoft.enterprise.webexteams TeamsBroadcastExtension:./broadcastextension.mobileprovision TeamsNotificationServiceExtension:./notificationserviceextension.mobileprovision TeamsShareExtension:./sharesextension.mobileprovision

OPTIONS:
   -y
      Promptless mode.  Quietly accept all prompts as if they had been
      accepted on the command line.  This option is mutually exclusive
      with the -p option.

   -p
      Prompt for manual changes before code signing.

   -d
      Enables debug logging to file '${DBGLOG_BASENAME}'.

   -v
      Displays the version number and exits.
      The current version is: ${VERSION}

   -T
     Updates CFBundleVersion with value of CFBundleShortVersionString. Used specifically for Webex Teams.

   -h
      Show this message.
!!help

exit $1
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Gather Input Parameters
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if [ $# -eq 0 ]
then
  usageExit 0
fi

# enable extended glob expression matching (needed thoroughout)
shopt -s extglob

while getopts ":hvypdT" opt
do
  case $opt in
    h)
      helpExit 0
      ;;
    v)
      echo "${VERSION}"
      exit 0
      ;;
    y)
      PROMPTS=0
      ;;
    p)
      MANUALPROMPT=1
      ;;
    d)
      DEBUG=1
      ;;
    T)
      UPDATE_VERSION=1
      ;;
    \?)
      echo -e "invalid option: -${OPTARG}\n"
      usageExit  1
      ;;
    :)
      echo -e "option -${OPTARG} requires an argument\n"
      usageExit 1
      ;;
    *)
      echo -e "unimplimented option: -${opt}\n"
      usageExit 1
      ;;
  esac
done
shift $(($OPTIND - 1))

# if ( [ $# -ne 3 ] && [ $# -ne 4 ] )
# then
#   echo -e "missing arguments\n"
#   usageExit 1
# fi

if ( [ $# -le 2 ] )
then
  echo -e "missing arguments\n"
  usageExit 1
fi


if (( PROMPTS == 0 && MANUALPROMPT == 1 ))
then
  echo -e "prompts cannot be disabled when manual prompting is requested\n"
  usageExit 1
fi
ARGS_COUNT=$(($# - 3))

APP="${1%%+(/)}"
PROFILE="$2"
BUNDLEID="$3"
unset APPEX_PROFILE
if ( [ $# -ge 4 ] )
then
  args=("$@")
  APPEX_PROFILE=()
  for (( i=3; i<${#@}; i++ ));
  do
    APPEX_PROFILE+=("${args[$i]}")
  done
else
  APPEX_PROFILE=()
fi

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Verifty Environment
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

test -r "$APP" || \
  errExit "cannot access application:\n\t\"${APP}\"" 1

test -r "$PROFILE" || \
  errExit "cannot access provisioning profile:\n\t\"${PROFILE}\"" 1

assertSigningEnvironment

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setup Working Environment
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

TSTAMP=$(date '+%Y-%m-%d-%H%M%S')
WORKDIR_BASENAME="${SCRIPTBASE}-${TSTAMP}"
WORKDIR="./${WORKDIR_BASENAME}"
LOG="${WORKDIR}/${LOG_BASENAME}"

mkdir -p "$WORKDIR" || \
  errExit "failed to create working directory: ${WORKDIR}" 1

# use some scripting log fu
if (( DEBUG == 1 ))
then
  echo "${0} ${COMMANDLINE}" > "$LOG"
  echo "${0} ${COMMANDLINE}" > "${WORKDIR}/${DBGLOG_BASENAME}"
  exec > >(tee -a "$LOG") 2>>"${WORKDIR}/${DBGLOG_BASENAME}"
  set -x
  echo "executing ${SCRIPTNAME} ${VERSION} at ${TSTAMP}"
  echo -e "Created working directory:\n\t${PWD}/${WORKDIR_BASENAME}"
  echo -e "Creating log file: ${LOG_BASENAME}"
  echo -e "Creating debug log file: ${DBGLOG_BASENAME}"
  echo -e "User environment:"
  "$UNAME" -prsv
  "$SWVERS"
else
  echo "${0} ${COMMANDLINE}" > "$LOG"
  exec > >(tee -a "$LOG") 2>&1
  echo "executing ${SCRIPTNAME} ${VERSION} at ${TSTAMP}"
  echo -e "Created working directory:\n\t${PWD}/${WORKDIR_BASENAME}"
  echo -e "Creating log file: ${LOG_BASENAME}"
fi

echo "---"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Resign the App
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

decodeProvisioningProfile
chooseCodeSigningCertificate
prepareIpaRoot
extractInfoPlistSettings
#Added for WxTeams
verifyAndUpdateGroupIdentifier
if (( UPDATE_VERSION == 1 ))
then
updateCFBundleVersion
fi
verifyBundleId
verifyAndUpdateGroupId
applyURLSchemeChanges
replaceEmbeddedMobileProfile

if (( APPSTORE_DIST == 1 ))
then
  verifyRequiredVersionKeys
  optionallyAddSwiftSupport
  stripITunesArtwork
fi

createCodeSigningEntitlements

# prompt for manual changes
if (( MANUALPROMPT == 1 ))
then
cat << !!prompt

Complete all manual changes to the application content.
Press 'n' to abort, and any other key to continue ...
!!prompt

  read response

  if [[ $response =~ $RE_NO ]]
  then
    echo "${SCRIPTNAME} aborted."
    exit 0
  fi

  # remove any DS Store files the user may have created
  /usr/bin/find "${IPAROOT}" -name ".DS_Store" -delete
fi

codeSignApp
createAppArchive

echo "Re-sign complete."
exit 0
