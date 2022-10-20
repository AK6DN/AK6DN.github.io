#!/usr/bin/perl -w

printf << 'EOF';
Options Indexes
IndexOrderDefault Ascending Description
IndexOptions FancyIndexing NameWidth=* DescriptionWidth=* SuppressHTMLPreamble HTMLTable
IndexStyleSheet /css/PDP-8.css
IndexIgnore . .htaccess .htaccess.pl

AddIcon /icons/text.gif *.lst *.pal *.ini *.log
AddIcon /icons/binary.gif *.bin *.rim

AddDescription "&#1;&#1;Diagnostics SIMH control file, RIM format" diagnostics_rim.ini
AddDescription "&#1;&#2;Diagnostics SIMH log file, RIM format" diagnostics_rim.log
AddDescription "&#1;&#3;Diagnostics SIMH control file, BIN format" diagnostics_bin.ini
AddDescription "&#1;&#4;Diagnostics SIMH log file, BIN format" diagnostics_bin.log
EOF

my %db = (
    D0LA => 'KE-8E (EAE) Instruction Test 1 (rev A)',
    D0LB => 'KE-8E (EAE) Instruction Test 1 (rev B)',
    D0MB => 'KE-8E (EAE) Instruction Test 2',
    DHKEA => 'KE-8E (EAE) Extended Memory Exerciser',
    );

my %type = (
    1 => ["pdf", "DEC documentation (acrobat)"],
    2 => ["bin", "program loader tape (BIN format)"],
    3 => ["rim", "program loader tape (RIM format)"],
    4 => ["pal", "disassembled PAL source (text)"],
    5 => ["lst", "assembled PAL listing (text)"],
    );

my $n = 5;
foreach my $file (sort(keys(%db))) {
    my $n1 = int($n/5)+1;
    my $n2 = ($n%5)+1;
    printf "\n";
    foreach my $s (1..5) {
	printf "AddDescription \"&#%d;&#%d;&#%d;<FONT COLOR=%s>%s - %s</FONT>\" *%s*%s\n",
	       $n1, $n2, $s, ('#880000','#008800')[$n%2], $db{$file}, $type{$s}[1], $file, $type{$s}[0];
    }
    $n += 1;
}

exit;
