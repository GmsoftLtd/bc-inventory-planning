# Exports the units still to translate as JSON, in plain text (XML entities decoded), with the object
# context and the developer comment, so a translator works on readable text.
# usage: perl xlf-export.pl <lang.xlf> <out.json> [--all]
use strict; use warnings; use JSON::PP;
my ($file, $out, $all) = @ARGV;
die "usage: perl xlf-export.pl <lang.xlf> <out.json> [--all]\n" unless $file && $out;
local $/;
open my $fh, '<:encoding(UTF-8)', $file or die "$file: $!"; my $x = <$fh>; close $fh;
sub unxml { my $s = shift; $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&apos;/'/g; $s =~ s/&amp;/&/g; return $s }
my @units;
while ($x =~ m{<trans-unit id="([^"]+)"[^>]*>(.*?)</trans-unit>}gs) {
    my ($id, $body) = ($1, $2);
    my ($src) = $body =~ m{<source>(.*?)</source>}s;
    my ($state, $tgt) = $body =~ m{<target state="([^"]*)">(.*?)</target>}s;
    next unless defined $src;
    next if !$all && (($state // '') ne 'needs-translation');
    my ($ctx) = $body =~ m{<note from="Xliff Generator"[^>]*>(.*?)</note>}s;
    my ($dev) = $body =~ m{<note from="Developer"[^>]*>(.*?)</note>}s;
    push @units, { id => $id, source => unxml($src), context => unxml($ctx // ''), comment => unxml($dev // ''),
                   ($all ? (target => unxml($tgt // '')) : ()) };
}
open $fh, '>:encoding(UTF-8)', $out or die "$out: $!";
print $fh JSON::PP->new->canonical->pretty->encode(\@units); close $fh;
print scalar(@units), " unit(s) exported to $out\n";
