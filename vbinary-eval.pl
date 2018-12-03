#!/usr/bin/perl -w

#
# vbinary-eval.pl
#
# This program supplements the article
#
# \by Yu.V.Shevchuk
# \paper Vbinary: variable length integer coding revisited
# \jour Program Systems: Theory and Applications
# \vol 9
# \issue 4
# \yr 2018
#
# Copiright (C) Y.V.Shevchuk, 2018
# Copiright (C) A.K.Ailamazyan Program Systems Institute of RAS, 2018
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

# Output the "capacity vs bits" table based on vbinary code specification.
# With -v, output level details.
# With -g, generate codewords to infinity or to the limit set with -NNN.

use bigint;

# variables set by parse_args() or left undefined
my $spec;
my $verbose;
my $generate;
my $maxval;


sub usage {
    die "Usage: vbinary-eval.pl [-v][-g][-NNN] vbinary-spec\n";
}


sub parse_args {
    while (@ARGV) {
        local $_ = shift @ARGV;
        if (s/^-v//) {
            $verbose++;
        }
        elsif (s/^-g//) {
            my @prefixes = ("");
            my $start = 0;
            $generate = sub {
                my ($end, @a) = generate ($start, shift(@prefixes), @_);
                $start = $end;
                push @prefixes, @a;
            };
        }
        elsif (s/^-(\d+)$//) {
            $maxval = $1;
        }
        elsif (!$spec && s/^(vbinary\S+)//) {
            $spec = $1;
        }
        else {
            usage ();
        }
        unshift @ARGV, "-$_" if $_ ne "";
    }
}


sub die_with_pos {
    my ($errmsg, $left) = @_;
    my $consumed = substr ($spec, 0, length ($spec) - length ($left));
    my $line1 = "$errmsg: $consumed";
    my $indent = " " x length ($line1);
    die "${line1}\n${indent}${left}\n";
}


# Output codewords for one extension level to STDOUT.  Return the list
# of extension codewords (empty for terminal extensions), which will
# appear as $prefix in subsequent invocations of generate()
sub generate {
    my ($start, $prefix, $width, $nvalues, $nexts) = @_;
    for (my $i = 0; $i < $nvalues; $i++) {
        last if $maxval &&$start > $maxval;
        print $start++;
        printf(" %s%0*b\n", $prefix, $width, $i);
    }
    my @ret = ($start);
    for (my $i = 0; $i < $nexts; $i++) {
        push @ret, sprintf("$prefix%0*b", $width, $nvalues + $i);
    }
    return @ret;
}


# nip the level specification at the beginning of $_
# Return in the form [[width, ...], extindex, repeat-spec]
# repeat-spec  = undef    ; repeat last level
# repeat-spec /= [[factor divisor numerator denominator] ...]
sub parse_level {
    my @widths;
    my $exti;
    if (s/^(\d+)//) {
        @widths = map {$_ << 4} ($1);
        if (s/^x//) {
            $exti = 0;
        }
    }
    elsif (s/^\(//) {
        while (1) {
            s/^(\d+)// || die_with_pos ("Width expected", $_);
            push @widths, $1 << 4;
            if (s/^x//) {
                if (defined $exti) {
                    die_with_pos ("More than one extension mark per level", $_);
                }
                $exti = @widths - 1;
            }
            if (s/^\)//) {
                last;
            }
            elsif (! s/^,//) {
                die_with_pos ("comma expected", $_);
            }
        }
    }
    elsif (/^$/) {
        return undef;           # EOL reached
    }
    else {
        die_with_pos ("digit/left parenthesis/EOF expected", $_);
    }

    my $repeater = maybe_parse_repeater ();
    if (defined $repeater && @widths != @{$repeater}) {
        die ("Repeater rule count wrong ".
             sprintf "(%u != %u)", 0+@widths, 0+@{$repeater});
    }

    return [[@widths], $exti, $repeater];
}


# If we are at the repeater specification which is the last part of
# vbinary specification, parse it

sub maybe_parse_repeater {
    if (s/^\((?=[am])//) {      # positive lookahead assertion [am]
        my @a;
        do {
            push @a, parse_repeater1 ();
            if (! defined ($a[-1])) {
                die_with_pos ("aN or mN or ... mN/NaN/N expected", $_);
            }
        } while (s/^,//);
        if (! s/^\)//) {
            die_with_pos ("right parenthesis expected", $_);
        }
        return \@a;
    }
    else {
        push @a, parse_repeater1 ();
        if (! defined ($a[-1])) {
            return;
        }
    }
    if (/./) {
        die_with_pos ("Expected nothing after repeat specification", $_);
    }
    return \@a;
}


# Subroutine of maybe_parse_repeater: parse a single aN oр mN/N clause,
# return [factor divisor numerator denominator]

sub parse_repeater1 {
    my @ret = (1,1,0,1);
    my $take;
    if (s/^m(\d+)\/(\d+)//) {
        @ret[0,1] = ($1,$2);
        $take = 1;
    }
    elsif (s/^m(\d+)//) {
        @ret[0,1] = ($1,1);
        $take = 1;
    }
    if (s/^a(\d+)\/(\d+)//) {
        @ret[2,3] = ($1,$2);
        $take = 1;
    }
    elsif (s/^a(\d+)//) {
        @ret[2,3] = ($1,1);
        $take = 1;
    }
    return ($take? \@ret: undef);
}


# Apply repeat specification to curlevel, return the resulting
# nextlevel data
sub repeat_maybe_add_mul {
    my ($curlevel) = @_;
    my $nextlevel = unshare ($curlevel);
    if (defined $curlevel->[2]) {
        my @repeat = @{$curlevel->[2]};
        for (my $i = 0; $i < @{$nextlevel->[0]}; $i++) {
            my ($fact, $div, $nom, $den) = @{$repeat[$i]};
            use integer;
            $nextlevel->[0][$i] *= $fact;
            $nextlevel->[0][$i] /= $div;
            $nextlevel->[0][$i] += (($nom << 4) / $div);
        }
    }
    return $nextlevel;
}


# Copy a nested data structure recursively, so we can modify any part
# of it without affecting others who refer to the original term.

sub unshare {
    my ($term) = @_;
    if (ref ($term) eq ARRAY) {
        my @a;
        for (@{$term}) {
            push @a, unshare ($_);
        }
        return \@a;
    }
    elsif (ref ($term) eq HASH) {
        my %h;
        for (keys %{$term}) {
            $h{$_} = unshare ($term->{$_});
        }
        return \%h;
    }
    else {                      # not a reference = not shared
        return $term;
    }
}


sub main {
    parse_args ();
    local $_ = $spec;

    print "0 0\n" unless $verbose || $generate;

    s/^vbinary// || usage ();
    /^\d/ || usage ();
    my $bits = 0;
    my $totvalues = 0;
    my $curlevel = parse_level ($_);
    for (my $level = 0; ; $level++) {
        my $exti = $curlevel->[1];
        if (! defined $exti && /./) {
            die_with_pos ("Expected nothing after terminal level", $_);
        }
        my $nextlevel = parse_level ();
        if (! $nextlevel) {     # EOL reached
            if (defined $exti) {
                $nextlevel = repeat_maybe_add_mul ($curlevel);
            }
            else {  # terminal level
                $nextlevel = [[], undef, undef];
            }
        }
        # Account for values represented by curlevel
        for (my $i=0; $i < @{$curlevel->[0]}; $i++) {
            my $width = ($curlevel->[0][$i] >> 4);
            my $bits = $bits + $width;
            my $extcount = 0;
            if (defined $exti && $i == $exti) {
                $extcount = @{$nextlevel->[0]};
                if ($extcount > 2**$width) {
                    die ("too many extensions ($extcount) for width $width\n");
                }
            }
            my $nvalues = 2**$width - $extcount;
            $totvalues += $nvalues;
            if ($verbose) {
                printf("level %2u/%u width %2u data %3s exts %u".
                       " totbits %2u totvalues $totvalues\n",
                       $level, $i, $width, $nvalues, $extcount, $bits);
            }
            elsif (! $generate) {
                print "$bits $totvalues\n" if $nvalues;
            }
            if ($generate) {
                $generate->($width, $nvalues, $extcount);
                last if $maxval && $totvalues > $maxval;
            }
        }
        # Switch to the next level, unless the code is finite and the
        # last level is finished
        last unless defined $exti;
        last if $maxval && $totvalues > $maxval;
        $bits += ($curlevel->[0][$exti] >> 4);
        $curlevel = $nextlevel;
    }
}


main ();
exit 0;
