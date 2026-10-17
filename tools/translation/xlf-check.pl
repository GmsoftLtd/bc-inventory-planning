# Checks target XLIFF files against their sources: every unit translated, no review marker left by a
# translation tool, and every translation keeps the placeholders (%1 ...), AL line breaks (\), headline
# tags and, for option captions, the number of options of its English source. Exit code 1 when
# anything is wrong, so a build script can stop on it.
# usage: perl xlf-check.pl <lang.xlf> [more.xlf ...]
use strict; use warnings;
local $/;
sub unxml { my $s = shift; $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&apos;/'/g; $s =~ s/&amp;/&/g; return $s }
sub sig {
    my ($s, $isOption) = @_;
    my @ph = sort ($s =~ /(%\d+)/g);
    my @tags = sort ($s =~ m{(</?(?:qualifier|payload|emphasize)>)}g);
    my $bs = () = $s =~ /\\/g;
    my $commas = $isOption ? (() = $s =~ /,/g) : 0;
    return join('|', @ph) . '#' . join('|', @tags) . '#' . $bs . '#' . $commas;
}
my $fail = 0;
for my $file (@ARGV) {
    open my $fh, '<:encoding(UTF-8)', $file or die "$file: $!"; my $x = <$fh>; close $fh;
    my ($units, $missing, $broken) = (0, 0, 0);
    while ($x =~ m{<trans-unit id="([^"]+)"[^>]*>(.*?)</trans-unit>}gs) {
        my ($id, $body) = ($1, $2); $units++;
        my ($src) = $body =~ m{<source>(.*?)</source>}s;
        next if !defined $src || $src eq '';   # an empty English source has nothing to translate
        my ($state, $tgt) = $body =~ m{<target state="([^"]*)">(.*?)</target>}s;
        if (!defined $tgt || $state eq 'needs-translation' || $tgt eq '') { $missing++; next }
        if ($tgt =~ m{\[NAB:|\bTODO\b|REVIEW\]}) { $broken++; print "  MARKER $id\n"; next }
        my $isOption = $body =~ /Property OptionCaption/;
        if (sig(unxml($src), $isOption) ne sig(unxml($tgt), $isOption)) { $broken++; print "  BROKEN $id\n" }
    }
    printf "%s: units=%d missing=%d broken=%d\n", $file, $units, $missing, $broken;
    $fail = 1 if $missing || $broken;
}
exit $fail;
