#!/usr/bin/env perl
#
# helpers.pl  common helper functions for running benchtests
# 23-Jul-2020  chuck@ece.cmu.edu
#

use strict;
use IPC::Open2;
use POSIX;

#
# load_hostdb(from, \%hostdb): load hostdb.  ret #hosts loaded on success.
# input is a CSV: vhost,node,vhost_exp,node_exp
# hostdb loaded into hash.
#    'nodecnt' => node count
#    'vhost',N => host N vhost name
#    ... etc. as above for node, vhost_exp, and node_exp
#
sub load_hostdb {
    my($from, $hr) = @_;
    my($fh, $n);

    if ($from eq '-') {   # translate to read from stdin
        $fh = *STDIN;
    } else {
        open($fh, $ARGV[0]) || return(undef);
    }

    $n = 0;
    while (<$fh>) {
        chop;
        next if (/^\s*#/);
        s/#.*$//;
        @_ = split(/,/);
        die "bad input line: $_" if ($#_ != 3);
        $$hr{'vhost'}{$n} = $_[0];
        $$hr{'node'}{$n} = $_[1];
        $$hr{'vhost_exp'}{$n} = $_[2];
        $$hr{'node_exp'}{$n} = $_[3];
        $n++;
    }

    close($fh) unless ($ARGV[0] eq '-');
    $$hr{'nodecnt'} = $n;
}

#
# cli_srvr(prefix, cli, cli_cmd, srvr, srvr_cmd, $logfile): run client/server.
# we run the server through remrun to ensure it terminates properly.
#
sub cli_srvr {
    my($prefix, $cli, $cli_cmd, $srvr, $srvr_cmd, $logfile) = @_;
    my($srvr_pid, $rfh, $wfh, $gotget, $outfh, $wait);

    if ($srvr eq '') {
        # "-i" to prevent it from killing us too as part of the pgrp.
        # we'll assume it hasn't forked off other pids that we'd miss.
        $srvr_cmd = "$prefix/scripts/remrun -v -i " . $srvr_cmd;
    } else {
    $srvr_cmd = "ssh -o StrictHostKeyChecking=no $srvr " .
        "$prefix/scripts/remrun -v " . $srvr_cmd;
    }
    print "cli_srvr: starting server", ($srvr ne '') ? " on $srvr\n" : "\n";
    $srvr_pid = open2($rfh, $wfh, $srvr_cmd);
    die "open2 failed($!)" if ($srvr_pid < 1);

    # wait for remrun to start to ensure we are running on srvr side
    while (<$rfh>) {
        if (/GETENV/) {
            $gotget++;
            syswrite($wfh, "\n");     # ignore errors
            last;
        }
    }
    if (!$gotget) { close($rfh); close($wfh); return undef; }
    syswrite($wfh, "\n");    # no env vars, just start the program
    sleep(1);                # just to be safe

    $cli_cmd = "ssh -o StrictHostKeyChecking=no $cli " . $cli_cmd
        if ($cli ne '');

    if ($logfile ne "" && open($outfh, ">>$logfile")) {
        print $outfh "CMD: $cli_cmd\n";
        close($outfh);
    }
    system($cli_cmd);

    close($rfh);
    close($wfh);
    $wait = waitpid($srvr_pid, 0);
    print "wait value $?\n" if (0);   # not useful, we always kill it w/EOF

    return(1);
}

1;
