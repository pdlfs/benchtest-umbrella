#!/usr/bin/env perl
#
# do_math.pl  do math on text file
# 12-Aug-2020  chuck@ece.cmu.edu
#

use strict;
use Getopt::Long qw(:config require_order no_ignore_case);

my($rv, $col, $sep, $verbo);

$rv = GetOptions(
                 'c|column=i'   => \$col,
                 's|sep=s'      => \$sep,
                 'v|verbose'    => \$verbo,
                );

sub usage {
    my($err) = @_;
    print "\n";
    print "$err\n\n" if (defined($err));
    print "usage: $0 [options] input-file\n";
    print "where options are:\n";
    print "\t-c / --col [s]     column number\n";
    print "\t-s / --sep [s]     seperator\n";
    print "\t-v / --verbose     print input data as we parse it\n";
    print "\n";
    exit(1);
}

die usage() if ($rv != 1 || $#ARGV < 0);
my(@data);

@data = load_data($col, $sep, @ARGV);
if ($#data == -1) {
    print STDERR "NO DATA!\n";
    exit(1);
}

my($min, $max, $avg, $median, $dev) = do_math(\@data);
print "min=$min, max=$max, avg=$avg, median=$median, dev=$dev\n";

exit(0);

#
# load_data(col, sep, data1, ...): load data
#
sub load_data {
    my($c, $s, @from) = @_;
    my(@result, $f, $fh, @chunks);
    $s = "\\s+" if ($s eq '');

    foreach $f (@from) {
        if ($f eq '-') {
            $fh = *STDIN;
        } else {
            if (!open($fh, "<$f")) {
                print STDERR" open $f failed ($!)\n";
                return(undef);
            }
        }
        while (<$fh>) {
            chop;
            @chunks = split(/\s+/, $_);
            if (!defined($chunks[$c])) {
                print STDERR "WARN: missing chunk from $f - $_\n";
            } else {
                print $chunks[$c], "\n" if ($verbo);
                push(@result, $chunks[$c]);
            }
        }
        close($fh) if ($f ne '-');
    }

    return(@result);
}
    
#
# do_math(aref): do math on an array ref
# ret min, max, avg, median, stddev
#
sub do_math {
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
