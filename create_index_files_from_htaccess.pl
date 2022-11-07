#!/usr/bin/perl -w
#!/usr/local/bin/perl -w

# options
use strict;

# external global modules
use Getopt::Long;
use Pod::Text;
use FindBin;
use Cwd;
use File::stat;
use File::Spec;
use File::Copy;
use Data::Dumper;

# defaults
my $VERSION = 'v1.0'; # version of code
my $HELP = 0; # set to 1 for man page output
my $DEBUG = 0; # set to 1 for debug messages
my $VERBOSE = 0; # set to 1 for verbose messages
my $OUTFILE = 'index.html'; # default output file name, '-' for STDOUT, '' for none

# process command line arguments
my $NOERROR = GetOptions( "help!"	=> \$HELP,
			  "debug!"	=> \$DEBUG,
			  "verbose!"	=> \$VERBOSE,
			  "outfile:s"	=> \$OUTFILE,
			  );

# init
$VERBOSE = 1 if $DEBUG; # debug implies verbose messages

# say hello
printf STDERR "%s %s (perl %g)\n", $0, $VERSION, $] if $VERBOSE;

# globals
my %db = ();
my %dd = ();
my %di = ();
my @entries = ();
my $maxlen = 0;

# simple subroutine to quote an argument
sub q ($) { my ($s) = @_; return '"'.$s.'"'; }

# ------------------------------------------------------------------------------

# process command line argument as working directory, if exists
chdir($ARGV[0]) if scalar(@ARGV) == 1 && -e $ARGV[0] && -d $ARGV[0];

# get working directory
my $dir = getcwd;
printf STDERR "INFO: processing in directory '%s'\n", $dir if $VERBOSE;

# read a .htaccess file if exists, else leave
if (-f '.htaccess') {
    if (open(INP, '< .htaccess')) {
	printf STDERR "INFO: processing .htaccess file ...\n" if $VERBOSE;
	while (my $line = scalar(<INP>)) {
	    $line =~ s/[\015\012]+$//;
	    printf "line=[%s]\n", $line if $DEBUG;
	    # process keywords
	    if    ($line =~ m/^\s*$/i) { }
	    elsif ($line =~ m/^\s*indexoptions\s+(.+)\s*$/i) { foreach my $entry (split(/\s+/,$1)) { $db{option}{lc($entry)}++; } }
	    elsif ($line =~ m/^\s*options\s+(.+)\s*$/i) { foreach my $entry (split(/\s+/,$1)) { $db{option}{lc($entry)}++; } }
	    elsif ($line =~ m/^\s*headername\s+(\S+)\s*$/i) { $db{header} = $1; }
	    elsif ($line =~ m/^\s*indexstylesheet\s+(\S+)\s*$/i) { $db{stylesheet} = $1; }
	    elsif ($line =~ m/^\s*(?:readme|trailer)name\s+(\S+)\s*$/i) { $db{trailer} = $1; }
	    elsif ($line =~ m/^\s*indexorderdefault\s+(\S+)\s+(\S+)\s*$/i) { $db{index}{order} = [lc($1),lc($2)]; }
	    elsif ($line =~ m/^\s*indexignore\s+(.+)\s*$/i) {
		foreach my $i (split(/\s+/,$1)) { my $j = $i; $j =~ s/[.]/[.]/g; $j =~ s/[*]/.*/g; $db{ignore}{sprintf("^%s\$",$j)} = $i; } }
	    elsif ($line =~ m/^\s*adddescription\s+\"(.+)\"\s+(\S+)\s*$/i) {
		my $f = $1; foreach my $i (split(/\s+/,$2)) { my $j = $i; $j =~ s/[.]/[.]/g; $j =~ s/[*]/.*/g; $db{description}{sprintf("^%s\$",$j)} = $f; } }
	    elsif ($line =~ m/^\s*addicon\s+(\S+)\s+(.+)$/i) {
		my $f = $1; foreach my $i (split(/\s+/,$2)) { my $j = $i; $j =~ s/[.]/[.]/g; $j =~ s/[*]/.*/g; $db{addicon}{sprintf("^%s\$",$j)} = $f; } }
	    else { printf STDERR "unknown option line: %s\n", $line; }
	}
	# always ignore these entries
	$db{ignore}{'^[.]$'} = '.';
	$db{ignore}{'^[.][.]$'} = '..';
	$db{ignore}{'^.*[.]html$'} = '*.html';
	close(INP);
	print STDERR Dumper(\%db) if $DEBUG;
	printf STDERR "INFO: ... complete\n" if $VERBOSE;
	# some defaults
	$db{index}{order} = ['ascending','description'] if not exists $db{index}{order};
	# indicate seen
	$db{seen} = 1;
    }
} else {
    # indicate not seen
    $db{seen} = 0;
}

# find all the directory entries we need using /BIN/LS
printf STDERR "INFO: Directory Entries:\n" if $VERBOSE;
my @line = `/bin/ls -a -h --full-time`;
foreach my $line (@line) {
    # strip EOLs
    $line =~ s/[\015\012]+$//;
    # parse into fields
    my @word = split(/\s+/, $line);
    next unless scalar(@word) == 9;
    # get filename entry and check if keep/ignore
    my $entry = $word[8];
    my $ok = 1; foreach my $ignore (sort(keys(%{$db{ignore}}))) { $ok = 0 if $entry =~ m/${ignore}/i; }
    push(@entries, $entry) if $ok;
    # save some stats for later
    $dd{$entry}{size} = $word[4];
    $dd{$entry}{time} = substr($word[5],0,10).' '.substr($word[6],0,5);
    $dd{$entry}{type} = -f $entry ? 'f' : (-d $entry ? 'D' : '?');
    # print status
    printf STDERR "%40s : %s %s %6s %s\n", $entry, $dd{$entry}{type}, $dd{$entry}{time}, $dd{$entry}{size}, $ok ? '' : '(ignore)' if $VERBOSE;
    # remember maximum name length
    $maxlen = length($entry) if length($entry) > $maxlen;
}

# exit early if no .htaccess file seen
if (!$db{seen}) {
    printf STDERR "INFO: Exiting, no .htaccess file!\n" if $VERBOSE;
    exit;
}

# attach descriptions to files, default to none
foreach my $entry (@entries) {
    $dd{$entry}{description} = '';
    foreach my $key (sort(keys(%{$db{description}}))) {
	next unless $entry =~ m/${key}/;
	$dd{$entry}{description} = $db{description}{$key};
    }
}

# re-sort directory entries if needed
if (exists $db{index}{order}) {
    my ($ord,$col) = @{$db{index}{order}};
    printf STDERR "INFO: sort order: %s %s\n", $ord, $col if $DEBUG;
    sub sort_order { $dd{$a}{description} ne $dd{$b}{description} ? $dd{$a}{description} cmp $dd{$b}{description} : $dd{$a}{type} ne $dd{$b}{type} ? $dd{$a}{type} cmp $dd{$b}{type} : $a cmp $b }
    if ($col eq 'description') {
	if ($ord eq 'ascending') {
	    @entries = sort(sort_order @entries);
	} else {
	    @entries = reverse(sort(sort_order @entries));
	}
    }
}

# fix descriptions to prune off leading '&#n;' characters that were used as sort key
foreach my $entry (keys(%dd)) { $dd{$entry}{description} =~ s/^(&#\d+;)+// if exists $dd{$entry}{description}; }

# build the extension to icon table
$di{'[/]$'} = ['/icons/folder.gif','DIR'];
$di{'[.](zip|tgz)$'} = ['/icons/compressed.gif','ZIP'];
$di{'[.](txt|ini|log|pal|mac|lst)$'} = ['/icons/text.gif','TXT'];
$di{'[.](bin|rim|rx1|rx2|dsk)$'} = ['/icons/binary.gif','BIN'];
$di{'[.]pdf$'} = ['/icons/layout.gif','PDF'];

# build the output file
if (1) {

    # store all the lines here
    my @outfile = ();

    # local and parent directories
    my @dir = File::Spec->splitdir($dir);
    shift(@dir) until $dir[0] =~ m/.github.io$/;
    shift(@dir);
    my $all = join('/',@dir);
    my $lcl = pop(@dir);
    my $par = join('/',@dir);
    $all = '/'.$all; $all .= '/' if $all !~ m|/$|;
    $lcl = '/'.$lcl; $lcl .= '/' if $lcl !~ m|/$|;
    $par = '/'.$par; $par .= '/' if $par !~ m|/$|;

    printf STDERR "INFO: all = %s\n", $all if $DEBUG;
    printf STDERR "INFO: par = %s\n", $par if $DEBUG;
    printf STDERR "INFO: lcl = %s\n", $lcl if $DEBUG;

    # file header
    if (exists $db{header} && -f $db{header} && open(TMP, '<'.$db{header})) {
	while (my $line = scalar(<TMP>)) { $line =~ s/[\015\012]+$//g; push(@outfile, sprintf("%s\n", $line)); }
	close(TMP);
    } else {
	push(@outfile, sprintf("<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">\n"));
	push(@outfile, sprintf("<html>\n"));
	push(@outfile, sprintf("  <head>\n"));
	push(@outfile, sprintf("    <title>Index of %s</title>\n", $all));
	push(@outfile, sprintf("    <link rel=\"stylesheet\" href=\"%s\" type=\"text/css\">\n", $db{stylesheet})) if exists $db{stylesheet};
	push(@outfile, sprintf("  </head>\n"));
	push(@outfile, sprintf("  <body>\n"));
	push(@outfile, sprintf("    <h1 id=\"indextitle\">Index of %s</h1>\n", $all));
    }
	
    # determine display format
    if (exists $db{option}{htmltable}) {

	# HTML table 

	# table header
	push(@outfile, sprintf("\n    <table id=\"indexlist\">\n"));
	push(@outfile, sprintf("      <tr class=\"indexhead\">"));
	push(@outfile, sprintf("<th class=\"indexcolicon\"><img src=\"/icons/blank.gif\" alt=\"[ICO]\"></th>"));
	push(@outfile, sprintf("<th class=\"indexcolname\">Name</th>"));
	push(@outfile, sprintf("<th class=\"indexcollastmod\">Last modified</th>"));
	push(@outfile, sprintf("<th class=\"indexcolsize\">Size</th>"));
	push(@outfile, sprintf("<th class=\"indexcoldesc\">Description</th>"));
	push(@outfile, sprintf("</tr>\n"));
	push(@outfile, sprintf("      <tr class=\"indexbreakrow\"><th colspan=\"%d\"><hr></th></tr>\n", 5));

	# special entry for move up one level
	push(@outfile, sprintf("      <tr class=\"%s\">", "even"));
	push(@outfile, sprintf("<td class=\"indexcolicon\"><img src=\"%s\" alt=\"%s\"></td>", "/icons/back.gif", "[PARENTDIR]"));
	push(@outfile, sprintf("<td class=\"indexcolname\"><a href=\"%s\">%s</a></td>",       $par, "Parent Directory"));
	push(@outfile, sprintf("<td class=\"indexcollastmod\">%s</td>",                       "&nbsp;"));
	push(@outfile, sprintf("<td class=\"indexcolsize\"> %s </td>",                        ""));
	push(@outfile, sprintf("<td class=\"indexcoldesc\">%s</td>",                          "&nbsp;"));
	push(@outfile, sprintf("</tr>\n"));

	my $n = 0;
	foreach my $entry (@entries) {

	    my ($icon,$flag) = ('/icons/unknown.gif','');
	    foreach my $key (%di) { if ($entry =~ m/${key}/i) { $icon = $di{$key}->[0]; $flag = $di{$key}->[1]; last; } }
	    ($icon,$flag) = ('/icons/folder.gif','DIR') if $dd{$entry}{type} eq 'D';
	    my $slash = $dd{$entry}{type} eq 'D' ? '/' : '';

	    # output an entry
	    push(@outfile, sprintf("      <tr class=\"%s\">",                                        ++$n%2 ? "odd" : "even"));
	    push(@outfile, sprintf("<td class=\"indexcolicon\"><img src=\"%s\" alt=\"[%3s]\"></td>", $icon, $flag));
	    push(@outfile, sprintf("<td class=\"indexcolname\"><a href=\"%s\">%s</a></td>",          $entry.$slash, $entry.$slash));
	    push(@outfile, sprintf("<td class=\"indexcollastmod\"> %s </td>",                        $dd{$entry}{time}));
	    push(@outfile, sprintf("<td class=\"indexcolsize\"> %s </td>",                           $dd{$entry}{size} eq '0' ? '-' : $dd{$entry}{size}));
	    push(@outfile, sprintf("<td class=\"indexcoldesc\">%s</td>",                             $dd{$entry}{description}));
	    push(@outfile, sprintf("</tr>\n"));
	}
    
	# table trailer
	push(@outfile, sprintf("      <tr class=\"indexbreakrow\"><th colspan=\"%d\"><hr></th></tr>\n", 5));
	push(@outfile, sprintf("    </table>\n"));

    } else {

	# preformatted HTML display

	my $HDR = "<img src=\"%s\" alt=\"%3s\"> %s%*s %-16s %5s  %s\n";
	my $FMT = "<img src=\"%s\" alt=\"[%3s]\"> <a href=\"%s\">%s</a>%*s %-16s %5s  %s\n";

	push(@outfile, sprintf("\n<pre>"));
	push(@outfile, sprintf($HDR, "/icons/blank.gif", "Icon ", "Name", $maxlen-4, '', "Last modified", "Size", "Description"));
	push(@outfile, sprintf("<hr>"));

	my $title = 'Parent Directory';
	my $icon = '/icons/back.gif';
	my $flag = 'PARENTDIR';
	
	push(@outfile, sprintf($FMT, $icon, $flag, $par, $title, $maxlen-length($title)-length($flag)+3, '', '', '', ''));

	foreach my $entry (@entries) {

	    my ($icon,$flag) = ('/icons/unknown.gif','');
	    foreach my $key (%di) { if ($entry =~ m/${key}/i) { $icon = $di{$key}->[0]; $flag = $di{$key}->[1]; last; } }
	    my $slash = $dd{$entry}{type} eq 'D' ? '/' : '';

	    push(@outfile, sprintf($FMT, $icon, $flag, $entry.$slash, $entry.$slash, $maxlen-length($entry.$slash), '', $dd{$entry}{time}, $dd{$entry}{size}, $dd{$entry}{description}));
	}

	push(@outfile, sprintf("<hr>"));
	push(@outfile, sprintf("</pre>\n\n"));

    }

    # file trailer
    if (exists $db{trailer} && -f $db{trailer} && open(TMP, '<'.$db{trailer})) {
	while (my $line = scalar(<TMP>)) { $line =~ s/[\015\012]+$//g; push(@outfile, sprintf("%s\n", $line)); }
	close(TMP);
    } else {
	# default trailer
	push(@outfile, sprintf("\n  </body>\n</html>\n"));
    }

    # now write all the output, if enabled
    if ($OUTFILE ne '') {
	# output something
	if ($OUTFILE eq '-') {
	    # output to STDERR
	    foreach my $line (@outfile) { print STDERR $line; }
	} else {
	    # output to a file
	    if (open(OUT, '> '.$OUTFILE)) { foreach my $line (@outfile) { print OUT $line; } close(OUT); }
	}
    }
}

# done!
printf STDERR "INFO: Done!\n" if $VERBOSE;

# short delay if running on windows perl directly
sleep(5) if $^O eq 'MSWin32';
exit;

# ------------------------------------------------------------------------------

# the end
