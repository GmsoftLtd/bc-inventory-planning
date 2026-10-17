# Builds or refreshes a target-language XLIFF from the generated .g.xlf.
# usage: perl xlf-fill.pl <g.xlf> <target-language> <out.xlf> [existing-translation.xlf]
# A unit keeps its existing translation only when its id AND its English source are unchanged, so a
# changed English text is always translated again. With no hit, en-* languages copy the source;
# every other language gets state "needs-translation" with the English text as placeholder.
use strict; use warnings;
my ($gfile, $lang, $outfile, $oldfile) = @ARGV;
die "usage: perl xlf-fill.pl <g.xlf> <lang> <out.xlf> [old.xlf]\n" unless $gfile && $lang && $outfile;
local $/;
open my $fh, '<:raw', $gfile or die "$gfile: $!"; my $g = <$fh>; close $fh;
my %byid;
if ($oldfile && -e $oldfile) {
    open $fh, '<:raw', $oldfile or die "$oldfile: $!"; my $old = <$fh>; close $fh;
    while ($old =~ m{<trans-unit id="([^"]+)"[^>]*>(.*?)</trans-unit>}gs) {
        my ($id, $body) = ($1, $2);
        next unless $body =~ m{<source>(.*?)</source>}s; my $src = $1;
        next unless $body =~ m{<target(?: state="([^"]*)")?[^>]*>(.*?)</target>}s;
        my ($state, $tgt) = ($1 // 'translated', $2);
        next if $state eq 'needs-translation' || $tgt eq '';
        $byid{$id} = [$src, $tgt, $state];
    }
}
my ($n, $kept, $copied, $missing) = (0, 0, 0, 0);
$g =~ s{(<trans-unit id="([^"]+)"[^>]*>)(\s*)<source>(.*?)</source>}{
    my ($open, $id, $ws, $src) = ($1, $2, $3, $4); $n++;
    my ($tgt, $state);
    if (defined $byid{$id} && $byid{$id}[0] eq $src) { ($tgt, $state) = ($byid{$id}[1], $byid{$id}[2]); $kept++ }
    elsif ($lang =~ /^en-/)                          { ($tgt, $state) = ($src, 'translated'); $copied++ }
    else                                             { ($tgt, $state) = ($src, 'needs-translation'); $missing++ }
    "$open$ws<source>$src</source>$ws<target state=\"$state\">$tgt</target>"
}gse;
$g =~ s/target-language="[^"]*"/target-language="$lang"/;
open $fh, '>:raw', $outfile or die "$outfile: $!"; print $fh $g; close $fh;
print "$outfile: units=$n kept=$kept copiedEnglish=$copied needsTranslation=$missing\n";
