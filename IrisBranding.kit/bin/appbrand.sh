#!/bin/bash

########################################################################
#
# iOS Application Brander
#
# 2016 BroadSoft, Inc.
#
# This script may be used to re-brand an iOS application binary for
# redistribution with customizations.  For details regarding the
# operations performed by this script, refer to the BroadSoft
# documentation:
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
declare -r ENVIRONMENT="${SCRIPTDIR}/.appbrand.env"
declare -r LOG_BASENAME="${SCRIPTBASE}.log"
declare -r DBGLOG_BASENAME="${SCRIPTBASE}.debug.log"

# static variables (set once, used throughout)
declare -i MANUALPROMPT=0

declare -i IGNORE_ICON_AND_LAUNCH_CHECK=0
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
usage: ${SCRIPTNAME} [-ypdivh] [-c <cert>] <app> <profile> <resources> <App Extension profile>
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

Brands and re-signs an iOS application.  No source files are overwritten,
and all output is stored in a new directory that is named using the following
time stamp format:
   ${SCRIPTBASE}-yyyy-mm-dd-HHMMSS

<app>
   The iOS Application to brand and re-sign.  This may be either an
   application content directory (ending with a '.app' file extension) or
   an application archive (ending with a '.ipa' file extension).

<profile>
   The provisioning profile that specifies how the application will be
   distributed.  This file should be downloaded from the Apple developer
   web site:
   https://developer.apple.com/account/ios/profile/profileList.action

<resources>
   Names a directory .zip file of application resources to replace during
   branding.  The original resources are generally obtained from a branding
   kit.  Refer to the appropriate BroadSoft branding resource guide for more
   information.

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

   -c <certCommonName>
      Specifies the Common Name of the certificiate to use when signing.
      This is useful when multiple certificates can sign for the profile,
      and promptless mode (-y) is being used.

   -d
      Enables debug logging to file '${DBGLOG_BASENAME}'.

   -i
      Ignore application icon verification.

   -v
      Displays the version number and exits.
      The current version is: ${VERSION}

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

while getopts ":hvidypc:" opt
do
  case $opt in
    h)
      helpExit 0
      ;;
    v)
      echo "${VERSION}"
      exit 0
      ;;
    i)
      IGNORE_ICON_AND_LAUNCH_CHECK=1
      ;;
    d)
      DEBUG=1
      ;;
    y)
      PROMPTS=0
      ;;
    p)
      MANUALPROMPT=1
      ;;
    c)
      CERTNAME="$OPTARG"
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

if ( [ $# -ne 3 ] && [ $# -ne 4 ] )
then
  echo -e "missing arguments\n"
  usageExit 1
fi

if (( PROMPTS == 0 && MANUALPROMPT == 1 ))
then
  echo -e "prompts cannot be disabled when manual prompting is requested\n"
  usageExit 1
fi

APP="${1%%+(/)}"
PROFILE="$2"
BRANDKIT="${3%%+(/)}"


ARGS_COUNT=$(($# - 3))

echo "ARGS_COUNT================>${#ARGS_COUNT}"

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

test -r "$BRANDKIT" || \
  errExit "cannot access branding kit:\n\t\"${BRANDKIT}\"" 1

assertBrandingEnvironment

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Setup Working Environment
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

TSTAMP=$(date '+%Y-%m-%d-%H%M%S')
WORKDIR_BASENAME="${SCRIPTBASE}-${TSTAMP}"
WORKDIR="./${WORKDIR_BASENAME}"
LOG="${WORKDIR}/${LOG_BASENAME}"

/bin/mkdir -p "$WORKDIR" || \
  errExit "failed to create working directory: ${WORKDIR}" 1

# use some scripting log fu
if (( DEBUG == 1 ))
then
  echo "${0} ${COMMANDLINE}" > "$LOG"
  echo "${0} ${COMMANDLINE}" > "${WORKDIR}/${DBGLOG_BASENAME}"
  exec > >(tee -a "$LOG") 2>>"${WORKDIR}/${DBGLOG_BASENAME}"
  SYSDETAILS="$(sw_vers)"
  set -x
  echo -e "executing ${SCRIPTNAME} ${VERSION} at ${TSTAMP} in ${SYSDETAILS}. \nXCode Version $(xcodebuild -version)"
  echo -e "Created working directory:\n\t${PWD}/${WORKDIR_BASENAME}"
  echo -e "Creating log file: ${LOG_BASENAME}"
  echo -e "Creating debug log file: ${DBGLOG_BASENAME}"
  echo -e "User environment:"
  "$UNAME" -prsv
  "$SWVERS"
else
  echo "${0} ${COMMANDLINE}" > "$LOG"
  exec > >(tee -a "$LOG") 2>&1
  SYSDETAILS="$(sw_vers)"
  echo -e "executing ${SCRIPTNAME} ${VERSION} at ${TSTAMP} in ${SYSDETAILS}. \nXCode Version $(xcodebuild -version)"
  echo -e "Created working directory:\n\t${PWD}/${WORKDIR_BASENAME}"
  echo -e "Creating log file: ${LOG_BASENAME}"
fi

echo "---"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Brand and Re-sign the App
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

decodeProvisioningProfile
chooseCodeSigningCertificate
createBrandingResourceDirectory
createBrandingDirectivesPlist
prepareIpaRoot
extractInfoPlistSettings

if (( $IGNORE_ICON_AND_LAUNCH_CHECK != 1 )) &&
   (( $(readPlistValue "$DIRECTIVESPLIST" "IgnoreRequiredIconCheck" "0") != 1 ))
then
  verifyCoreResourcesBranding
else
  echo "Skipping branded application icon verification."
fi

determineAllowedLanguages
determineWebCredentialsAssociatedDomains
applyBrandingNameChanges
applyBrandingVersionChanges
applyBrandingCodeChanges
applyBrandingDeviceFamilyChanges
verifyBundleId
verifyAndUpdateGroupId
applyBrandingURLSchemeChanges
applyBrandingApplicationQueriesSchemesChanges
applyAppTransportSecurityChanges
applyDarkModeChanges
applyCrashlyticsChanges
transferBrandingResources
replaceEmbeddedMobileProfile

if (( APPSTORE_DIST == 1 ))
then
  optionallyAddSwiftSupport
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

echo "Branding complete."
