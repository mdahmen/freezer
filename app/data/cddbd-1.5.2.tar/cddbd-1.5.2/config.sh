#!/bin/sh
#
#   @(#)$Id: config.sh,v 1.18.2.3 2006/04/14 14:45:06 joerg78 Exp $
#
#   cddbd - CD Database Protocol Server
#
#   Copyright (C) 1996       Steve Scherf (steve@moonsoft.com)
#   Portions Copyright (C) 2001-2006  by various authors 
#
#   Based on the original source by Ti Kan.
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/etc:/usr/local/bin
export PATH

CDDBD_VER=1.5.2
UMASK=022
ERRFILE=/tmp/cddbd.err
TMPFILE=/tmp/cddbd.$$
CONFIGHEADER=configurables.h

#
# Utility functions
#

getyn()
{
	if [ -z "$YNDEF" ]
	then
		YNDEF=y
	fi

	while :
	do
		$ECHO "$*? [${YNDEF}] \c"
		read ANS
		if [ -n "$ANS" ]
		then
			case $ANS in
			[yY])
				RET=0
				break
				;;
			[nN])
				RET=1
				break
				;;
			*)
				$ECHO "Please answer y or n"
				;;
			esac
		else
			if [ $YNDEF = y ]
			then
				RET=0
			else
				RET=1
			fi
			break
		fi
	done

	YNDEF=
	return $RET
}

doexit()
{
	if [ $1 -eq 0 ]
	then
		$ECHO "Configuration of cddbd is now complete."
		$ECHO "You may now run \"make\"."
	else
		$ECHO "\nErrors have occurred during configuration."
		if [ $ERRFILE != /dev/null ]
		then
			$ECHO "See $ERRFILE for an error log."
		fi
	fi
	exit $1
}

logerr()
{
	if [ "$1" = "-p" ]
	then
		$ECHO "Error: $2"
	fi
	$ECHO "$2" >>$ERRFILE
	ERROR=1
}

getstr()
{
	$ECHO "$* \c"
	read ANS
	if [ -n "$ANS" ]
	then
		return 0
	else
		return 1
	fi
}



#
# Main execution starts here.
#

# Catch some signals
trap "rm -f $TMPFILE; exit 1" 1 2 3 5 15

# Use Sysv echo if possible
if [ -x /usr/5bin/echo ]
then
	ECHO=/usr/5bin/echo				# SunOS SysV echo
elif [ -z "`(echo -e a) 2>/dev/null | fgrep e`" ]
then
	ECHO="echo -e"					# GNU bash, etc.
else
	ECHO=echo					# generic SysV
fi

# Remove old error log file.
ERROR=0
rm -f $ERRFILE
if [ -f $ERRFILE ]
then
	$ECHO "Cannot remove old $ERRFILE: output logging not enabled."
	ERRFILE=/dev/null
fi

$ECHO "\nConfiguring \"cddbd\" CDDB Protocol Server $CDDBD_VER by Steve Scherf et al."

# Determine BASEDIR.

if [ -z "$BASEDIR" ]
then
    BASEDIR=/usr/local
else
	BASEDIR=`echo $BASEDIR | sed 's/\/\//\//g'`
fi

ACCESS=${BASEDIR}/cddbd

while :
do
	if getstr "\nEnter the path to the cddbd access file dir\n[${ACCESS}]"
	then
		if [ -d `dirname "$ANS"` ]
		then
			ACCESS=$ANS
			break
		else
			$ECHO "Error: $ANS does not exist."
		fi
	else
		break
	fi
done

echo


# Create the target files.

umask $UMASK
rm -f cddbd
echo "ACCESSFILE $ACCESS" > .accessfile

cat > access.h << __EOF__
/* This file is generated by config.sh. Do not edit. */

#ifdef _AIX
#include <sys/select.h>
#include <net/nh.h>
#endif

#define ACCESSFILE "${ACCESS}/access"

__EOF__

cat > secure.c << __EOF__
/* This file is generated by config.sh. Do not edit. */

char *secure_users[] = {
__EOF__

$ECHO "Enter the list of trusted users, one per line."
$ECHO "Press return alone when finished.\n"

secusers=0

while :
do
	if getstr "Secure user:"
	then
		if [ $ANS = "" ]
		then
			break
		else
			$ECHO "	\"$ANS\"," >> secure.c
			secusers=`expr $secusers + 1`
		fi
	else
		break
	fi
done

cat >> secure.c << __EOF__
	0
};
__EOF__

echo ""

echo "SECUSERS ${secusers}" >> .accessfile

# Setup configurables.h
rm -f ${CONFIGHEADER}

echo "/* Generated by config.sh - do not edit */" >> ${CONFIGHEADER}
echo "#ifndef __CONFIGURABLES_H__" >> ${CONFIGHEADER}
echo "#define __CONFIGURABLES_H__" >> ${CONFIGHEADER}
echo "" >> ${CONFIGHEADER}

YNDEF=n
getyn "\nDo you want to use Windows format of the DB"
if [ $? -eq 0 ]
then
    echo "#define DB_WINDOWS_FORMAT" >> ${CONFIGHEADER}
    YNDEF=y
    getyn "\nDo you want to support DB files containing range of discid's start byte\n\
- e.g. 01to33 (this is the standard format; otherwise there must be a file for\n\
each discid's start byte - e.g. 01to01 (a little bit faster))"
    if [ $? -eq 0 ]
    then
        echo "#define DB_WINDOWS_FORMAT_USE_RANGES" >> ${CONFIGHEADER}
    else
        echo "#undef DB_WINDOWS_FORMAT_USE_RANGES" >> ${CONFIGHEADER}
    fi
else
    echo "#undef DB_WINDOWS_FORMAT" >> ${CONFIGHEADER}
    echo "#undef DB_WINDOWS_FORMAT_USE_RANGES" >> ${CONFIGHEADER}
fi

YNDEF=n
getyn "\nDo you want to disable peer address resolution (faster under Cygwin\n\
when there is no DNS (no internet access))"
if [ $? -eq 0 ]
then
    echo "#define DONT_RESOLVE_ADDRESS" >> ${CONFIGHEADER}
else
    echo "#undef DONT_RESOLVE_ADDRESS" >> ${CONFIGHEADER}
fi

echo "" >> ${CONFIGHEADER}
echo "#endif /* __CONFIGURABLES_H__ */" >> ${CONFIGHEADER}

doexit $ERROR
