#!/usr/bin/env perl
#
# report_perftest.pl  generate report from run_perftest.pl output
# 13-Aug-2020  chuck@ece.cmu.edu
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
    print "usage: $0 [options] run-perftest-output-dirs\n";
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
    my(@parts, $tospec, $from, $test, $mode, $to, @lns, @vals, $v);
    @parts = split(/\//, $in);
    $tospec = pop(@parts);
    $from = pop(@parts);
    next unless ($from ne '' && $tospec ne '');
    next unless ($tospec =~ /^(atomic|read|send|write)-(bw|lat)-(.*)/);
    $test = $1;
    $mode = $2;
    $to = $3;

    open($fh, "<$in") || next;
    @lns = <$fh>;
    close($fh);
    
    foreach (@lns) {
        chop;
        s/^\s+//;
        next unless (/^\d/);
        @vals = split(/\s+/);
        $v = ($mode eq "bw") ? $vals[3] : $vals[5];
        next if ($v == 0);
        push(@csvtab, sprintf("%s,%s,%s,%s,%f", $from, $to, $test, $mode, $v));
        $sendnodes{$from}++;
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
my($ln, %db, %snodes, %dnodes, %tests, %modes);

foreach $ln (@csvtab) {
    my($src, $dst, $test, $mode, $val) = split(/,/, $ln);
    $snodes{$src}++;
    $dnodes{$dst}++;
    $tests{$test}++;
    $modes{$mode}++;

    $db{$src,$dst,$test,$mode} = [] if (!defined($db{$src,$dst,$test,$mode}));
    push(@{$db{$src,$dst,$test,$mode}}, $val);
}

my(@tsts, @mds, @srcs, @dsts, $t, $m, $s, $d, $ar, $u);
@tsts = sort keys %tests;
@mds = sort keys %modes;
@srcs = sort keys %snodes;
@dsts = sort keys %dnodes;

foreach $t (@tsts) {
    foreach $m (@mds) {
        print "test: $t-$m\n";
        if ($m eq 'bw') {
            $u = "Gbits/sec";
        } elsif ($m eq 'lat') {
            $u = "usec";
        } else {
            $u = "??";
        }
        foreach $s (@srcs) {
            foreach $d (@dsts) {
                $ar = $db{$s,$d,$t,$m};
                next unless (defined($ar));
                my($min, $max, $avg, $median, $dev) = do_math($ar);
                printf "%s -> %s =  %.2f  %.2f  [%.2f,%.2f]  %.2f  (%s)\n",
                    do_trim($s, $trim), do_trim($d, $trim), $avg,
                    $median, $min, $max, $dev, $u;
                
            }
        }
    }
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
