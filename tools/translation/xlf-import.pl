# Writes translations into a target XLIFF and marks them translated. Input: a JSON array of
# {"id": ..., "target": "..."} in plain text (this script escapes it for XML). A translation is
# refused, and the unit left untouched, when it changes the placeholders (%1, %2 ...), the AL line
# breaks (\), the headline tags (<qualifier>, <payload>, <emphasize>) or is empty.
# usage: perl xlf-import.pl <lang.xlf> <translations.json> [more.json ...]
use strict; use warnings; use JSON::PP;
my ($file, @inputs) = @ARGV;
die "usage: perl xlf-import.pl <lang.xlf> <translations.json> [...]\n" unless $file && @inputs;
local $/;
my %tr;
for my $in (@inputs) {
    open my $fh, '<:encoding(UTF-8)', $in or die "$in: $!"; my $j = decode_json(do { local $/; my $t = <$fh>; utf8::encode($t); $t }); close $fh;
    $tr{$_->{id}} = $_->{target} for @$j;
}
open my $fh, '<:encoding(UTF-8)', $file or die "$file: $!"; my $x = <$fh>; close $fh;
sub unxml { my $s = shift; $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&apos;/'/g; $s =~ s/&amp;/&/g; return $s }
sub toxml { my $s = shift; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; return $s }
sub sig {
    my ($s, $isOption) = @_;
    my @ph = sort ($s =~ /(%\d+)/g);
    my @tags = sort ($s =~ m{(</?(?:qualifier|payload|emphasize)>)}g);
    my $bs = () = $s =~ /\\/g;
    my $commas = $isOption ? (() = $s =~ /,/g) : 0;
    return join('|', @ph) . '#' . join('|', @tags) . '#' . $bs . '#' . $commas;
}
my ($ok, $bad, $unknown) = (0, 0, 0);
my %seen;
$x =~ s{(<trans-unit id="([^"]+)"[^>]*>)(.*?)(</trans-unit>)}{
    my ($open, $id, $body, $close) = ($1, $2, $3, $4);
    if (exists $tr{$id}) {
        $seen{$id} = 1;
        my ($src) = $body =~ m{<source>(.*?)</source>}s;
        my $s = unxml($src); my $t = $tr{$id};
        my $isOption = $body =~ /Property OptionCaption/;
        if (!defined $t || $t =~ /^\s*$/) { warn "EMPTY  $id\n"; $bad++ }
        elsif (sig($s, $isOption) ne sig($t, $isOption)) { warn "REFUSED $id: placeholders/tags/backslashes/option count differ\n  EN: $s\n  TR: $t\n"; $bad++ }
        else {
            my $tx = toxml($t);
            $body =~ s{<target state="[^"]*">.*?</target>}{<target state="translated">$tx</target>}s; $ok++;
        }
    }
    "$open$body$close"
}gse;
for my $id (keys %tr) { unless ($seen{$id}) { warn "UNKNOWN id $id\n"; $unknown++ } }
open $fh, '>:encoding(UTF-8)', $file or die "$file: $!"; print $fh $x; close $fh;
my $left = () = $x =~ /state="needs-translation"/g;
print "$file: imported=$ok refused=$bad unknownIds=$unknown stillNeedsTranslation=$left\n";
exit($bad ? 1 : 0);
