#!/usr/bin/env perl
#
# report_iperf.pl  generate report from run_iperf.pl output
# 23-Jul-2020  chuck@ece.cmu.edu
#

use strict;
use Getopt::Long qw(:config require_order no_ignore_case);

my($rv, $csv, $senders, $trim);

$rv = GetOptions(
                 'c|csv=s'      => \$csv,
                 's|senders'    => \$senders,
                 't|trim=s'     => \$trim,
                );

sub usage {
    my($err) = @_;
    print "\n";
    print "$err\n\n" if (defined($err));
    print "usage: $0 [options] run-iperf-output-dirs\n";
    print "where options are:\n";
    print "\t-c / --csv [s]     generate csv output file too\n";
    print "\t-s / --senders     only report nodes that were senders\n";
    print "\t-t / --trim [s]    trim string 's' from nodenames\n";
    print "\n";
    print "note that you can specify more than output dir to read\n";
    print "\n";
    exit(1);
}

my($dir, $fh, @inputs, @csvtab, $in, %sendnodes);

die usage() if ($rv != 1 || $#ARGV < 0);

# sanity check args
foreach (@ARGV) {
    unless (-d $_) {
        print "ERROR: $_ is not a directory\n";
        exit(1);
    }
}

print STDERR "generating list of input files\n";
foreach $dir (@ARGV) {
    open($fh, "find $dir -type f -print|") || die "popen find failed";
    while (<$fh>) {
        chop;
        push(@inputs, $_);
    }
    close($fh);
}
print STDERR $#inputs+1, " input file(s) in input data sets\n";


print STDERR "loading data\n";

foreach $in (@inputs) {
    my(@parts, $to, $from, @lns, $state, $is_iperf3, $threads);
    my($src, $dst, $bw, $u);
    @parts = split(/\//, $in);
    $to = pop(@parts);
    $from = pop(@parts);
    next unless ($from ne '' && $to ne '');

    open($fh, "<$in") || next;
    @lns = <$fh>;
    close($fh);
    
    $state = 'start';
    foreach (@lns) {
        if ($state eq 'start') {
            next unless (/^CMD: /);
            $is_iperf3 = (/iperf3 /) ? 1 : 0;
            $threads = (/-P\s*\d+/) ? 1 : 0;
            $state = 'running';
            next;
        }
        if ($state eq 'running') {
            next unless (/local (\S+) port \S+ connected \w+ (\S+) port/);
            $src = $1;
            $dst = $2;
            $state = 'result';
            next;
        }

        if ($state eq 'result') {
            next unless (/0\.0+-\d+\.\d+\s+sec\s+\S+\s+\S+\s+(\S+)\s+(\S+)/);
            if ($threads) {
                next unless(/SUM/);
            }
            $bw = $1;
            $u = $2;
            if ($u eq 'Mbits/sec') {   # normalize on G
                $bw = $bw / 1000.0;
                $u = 'Gbits/sec';
            }
            die "bad unit $u" if ($u ne 'Gbits/sec');
            $state = 'start';
            push(@csvtab, sprintf("%s,%s,%s", $from, $to, $bw));
            $sendnodes{$from}++;
            next;
        }
        die "oops";
    }
}

print STDERR "all data loaded\n";

if ($csv ne '') {
    print STDERR "dumping csv to $csv\n";
    open($fh, ">$csv") || die "can't open csv $csv ($!)";
    print $fh join("\n", @csvtab), "\n";
    close($fh);
}

#
# now generate the report
#
my($ln, %db, %snodes, %dnodes, %averages);

foreach $ln (@csvtab) {
    my($src, $dst, $gbits_sec) = split(/,/, $ln);
    $snodes{$src}++;
    $dnodes{$dst}++;

    $db{$src,$dst} = [] if (!defined($db{$src,$dst}));
    push(@{$db{$src,$dst}}, $gbits_sec);
}

my(@srcs, @dsts, $s, $d);
@srcs = sort keys %snodes;
@dsts = sort keys %dnodes;

print "\niperf IPoIB bandwidth\n";
print "output is in Gbits/sec, second number is the standard dev.\n\n";
printf "%-9s  DEST\n", "SRC";
printf "%-9s", "";
foreach $d (@dsts) {
    next if ($senders && !$sendnodes{$d});
    printf "  %-9s", do_trim($d, $trim);
}
print "\n";

foreach $s (@srcs) {
    printf "%-9s", do_trim($s, $trim);
    foreach $d (@dsts) {
        next if ($senders && !$sendnodes{$d});
        if (!defined($db{$s,$d})) {
            printf "  %-9s", "-";
            next;
        }
        my($min, $max, $avg, $median, $dev) = do_math($db{$s,$d});
        $averages{$s,$d} = $avg;
        printf "  %-2.2f %-3.1f", $avg, $dev;
        #printf "  %-5.2f %-3.1f", 0,0 ;
        #print "$avg $dev\t";
    }
    print "\n";
}
print "\n\n";

print "Detailed per-run results (in Gbits/sec):\n\n";
foreach $s (@srcs) {
    print "Source node: ", do_trim($s, $trim), "\n";
    foreach $d (@dsts) {
        next if ($senders && !$sendnodes{$d});
        next if ($d eq $s || !defined($db{$s,$d}));
        print "dst=", do_trim($d, $trim), "  avg=",
            sprintf("%5.2f", $averages{$s,$d}), "  ";
        print join(" ", @{$db{$s,$d}}), "\n";
    }
    print "\n";
    
}

exit(0);

sub do_trim {
    my($name, $trm) = @_;
    my($lhs, $rhs);
    return($name) if ($trm eq '');
    $_ = index($name, $trm);
    return($name) if ($_ == -1);
    $lhs = substr($name, 0, $_);
    $rhs = substr($name, $_ + length($trm));
    return("${lhs}${rhs}");
}

sub do_math {  # ret min, max, avg, median, stddev
    my($aref) = @_;
    my(@sorted, $n, $tot, $mean, $devtot, $dev);
    @sorted = sort { $a <=> $b } @$aref;
    $n = $#sorted+1;
    return(undef) if ($n == 0);
    foreach (@sorted) {
        $tot += $_;
    }
    $mean = $tot / $n;

    foreach (@sorted) {
        $devtot += ($_ - $mean) ** 2;
    }
    $dev = sqrt($devtot / $n);
    

    return($sorted[0], $sorted[$#sorted], $mean, $sorted[int($n/2)], $dev);
    
}
