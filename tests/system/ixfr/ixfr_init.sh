#!/bin/sh
#
# Copyright (C) 2011  Internet Software Consortium.
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND ISC DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS.  IN NO EVENT SHALL ISC BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
# OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

# \file
# This file should be run by all IXFR tests before going anything else.  It
# includes the main configuration script that defines the various environment
# variables, as well as defining useful shell subroutines.

. /home/stephen/bind10/tests/system/conf.sh

# Useful symbols used in the IXFR tests.

# Short-hand for getting SOA - just supply address of the server
DIG_SOA="$DIG +norecurse +short -p $DNS_PORT example. SOA"

# All IXFR tests use a BIND 9 server serving a BIND 10 client
SERVER_NAME=ns1
SERVER_IP=10.53.0.1   # BIND 9

CLIENT_NAME=nsx2
CLIENT_IP=10.53.0.2   # BIND 10

# \brief Check Arguments
#
# All functions take the name of the server as the firsrt argument and its IP
# address as the second.  This function is passed "$*" and just checks that
# both $1 and $2 are defined.
#
# \arg $* Arguments passed to caller
#
# \return status 0 => $1 and $2 are defined, 1 => they are not.
check_name_ip() {

    if [ "$1" = "" ];
    then
        echo "R:FAIL name of server not supplied"
        return 1
    fi

    if [ "$2" = "" ];
    then
        echo "R:FAIL IP address of server not supplied"
        return 1
    fi

    return 0
}


# \brief Perform RNDC Command
#
# Controls the BIND 9 IXFR server.  Called do_rndc (instead of rndc) to avoid
# confusion if rndc itself is in the search path.
#
# $1 - Name of the server (ns1, nsx2 etc.)
# $2 - IP address of the server
# $* - Command to execute (which may be multiple tokens)
do_rndc () {

    # If the following checks fail, the code is wrong.

    check_name_ip $*
    if [ $? -ne 0 ];
    then
        echo "R:FAIL do_rndc - name or ip address of server not supplied"
        return 1
    fi

    name=$1
    shift
    ip=$1
    shift

    if [ "$1" = "" ];
    then
        echo "R:FAIL do_rndc - rndc command not supplied"
        return 1
    fi
    
    $RNDC -c $SYSTEM_TOP/common/rndc.conf -s $ip -p $RNDC_PORT $* 2>&1 \
        | sed "s/^/I:$name /"
}

# wait_for_update
#
# Given a serial number and a server, poll the nameserver until the SOA serial
# number is different from that given.  The poll takes place every five seconds
# for a minute.
#
# $1 - Name of the server
# $2 - IP address of the server
# $3 - Serial number to check against
#
# Returns:
# 0 - Serial number is different (requires another poll to obtain it)
# 1 - Serial number has not changed
wait_for_update() {

    # If the following checks fail, the code is wrong.

    check_name_ip $*
    if [ $? -ne 0 ];
    then
        echo "R:FAIL wait_for_update - name or ip address of system not supplied"
        return 1
    fi

    name=$1
    shift
    ip=$1
    shift

    serial=$1
    shift
    if [ "$serial" = "" ];
    then
        echo "R:FAIL wait_for_update - serial number not supplied"
        return 1
    fi

    # Now poll the server looking for the new serial number

    for i in 1 2 3 4 5 6 7 8 9 10 11 12
    do
        if [ $i -gt 1 ];
        then
            sleep 5
        fi

        new_serial=`$DIG_SOA @$ip | $AWK '{print $3}'`
        if [ "$new_serial" != "$serial" ];
        then
            return 0
        fi
    done

    echo "R:$name FAIL serial number has not updated"
    return 1
}



# update_server_zone
#
# Reloads the example. zone in the BIND 9 IXFR server and waits a maximum of
# one minute for it to be served.
#
# $1 - Name of the server (ns1, nsx2 etc.)
# $2 - IP address of the server
# $3 - Zone file to load
# $* - Command to execute (which may be multiple tokens)
update_server_zone() {

    # If the following checks fail, the code is wrong.

    check_name_ip $*
    if [ $? -ne 0 ];
    then
        echo "R:FAIL update_server_zone - name or ip address of server not supplied"
        return 1
    fi

    name=$1
    shift
    ip=$1
    shift

    file=$1
    shift
    if [ "$file" = "" ];
    then
        echo "R:FAIL update_server_zone - new zone file not supplied"
        return 1
    fi

    if [ ! -e $file ];
    then
        echo "R:FAIL update_server_zone - zone file does not exist: $file"
        return 1
    fi

    old_serial=`$DIG_SOA @$ip | $AWK '{print $3}'`

    echo "I:$name IXFR server loading $1"
    cp $file $name/zone.db
    do_rndc $name $ip reload
    if [ $? -ne 0 ];
    then
        return 1    # Message will have already been output
    fi

    wait_for_update $name $ip $old_serial
    if [ $? -ne 0 ];
    then
        echo "R:$name FAIL IXFR server did not update zone after reload"
        return 1
    fi

    new_serial=`$DIG_SOA @$ip | $AWK '{print $3}'`
    echo "I:$name was at serial $old_serial, now at $new_serial"
    return 0
}

# \brief Compare client and server SOAs
#
# Checks the SOAs of two systems and reports if they are not equal.
#
# \arg $1 Name of the IXFR server
# \arg $2 IP of the IXFR server 
# \arg $3 Name of the IXFR client
# \arg $4 IP of the IXFR client
#
# \return 0 if the systems have the same SOA, 1 if not.  In the latter case,
#         an error will be output.
compare_soa() {

    # If the following checks fail, the code is wrong.

    check_name_ip $*
    if [ $? -ne 0 ];
    then
        echo "R:FAIL compare_soa - name or ip address of server not supplied"
        return 1
    fi

    server_name=$1
    shift
    server_ip=$1
    shift

    check_name_ip $*
    if [ $? -ne 0 ];
    then
        echo "R:FAIL compare_soa - name or ip address of client not supplied"
        return 1
    fi

    client_name=$1
    shift
    client_ip=$1
    shift

    client_serial=`$DIG_SOA @$client_ip | $AWK '{print $3}'`
    server_serial=`$DIG_SOA @$server_ip | $AWK '{print $3}'`
    if [ "$client_serial" != "$server_serial" ];
    then
        echo "R:FAIL client $client_name serial $client_serial not same as server $server_name serial $server_serial"
        return 1
    fi

    return 0
}
