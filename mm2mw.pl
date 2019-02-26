#!/usr/bin/perl
# MoinMoin to MediaWiki converter
#
# =========================================================================================
#  (c) Copyright 2007, 2008 by Rotan Hanrahan (rotan A T ieee D O T org)
# 
#  W3C® SOFTWARE NOTICE AND LICENSE
#  http://www.w3.org/Consortium/Legal/2002/copyright-software-20021231
#
#  This work (and included software, documentation such as READMEs, or other related items)
#  is being provided by the copyright holders under the following license. By obtaining,
#  using and/or copying this work, you (the licensee) agree that you have read, understood,
#  and will comply with the following terms and conditions.
#
#  Permission to copy, modify, and distribute this software and its documentation, with or
#  without modification, for any purpose and without fee or royalty is hereby granted,
#  provided that you include the following on ALL copies of the software and documentation
#  or portions thereof, including modifications:
#
#   1. The full text of this NOTICE in a location viewable to users of the
#      redistributed or derivative work. 
#   2. Any pre-existing intellectual property disclaimers, notices, or terms
#      and conditions. If none exist, the W3C Software Short Notice should be
#      included (hypertext is preferred, text is permitted) within the body of
#      any redistributed or derivative code. 
#   3. Notice of any changes or modifications to the files, including the date
#      changes were made. (We recommend you provide URIs to the location from
#      which the code is derived.) 
#
#  THIS SOFTWARE AND DOCUMENTATION IS PROVIDED "AS IS," AND COPYRIGHT HOLDERS MAKE NO
#  REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO, WARRANTIES
#  OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE OR THAT THE USE OF THE SOFTWARE OR
#  DOCUMENTATION WILL NOT INFRINGE ANY THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS OR OTHER RIGHTS.
#
#  COPYRIGHT HOLDERS WILL NOT BE LIABLE FOR ANY DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL
#  DAMAGES ARISING OUT OF ANY USE OF THE SOFTWARE OR DOCUMENTATION.
#
#  The name and trademarks of copyright holders may NOT be used in advertising or publicity
#  pertaining to the software without specific, written prior permission. Title to copyright in
#  this software and any associated documentation will at all times remain with copyright holders.
#
# ========================================================================================
# 
# Input:  1) Path to the data direcory from the MoinMoin (v1.3+) system.
#         2) To perform the upload to MediaWiki, you need the Wiki Sysop password.
#         3) Optional: A skip.txt file in the current directory. One line per wiki page name: prevents their conversion.
# Output: 1) A directory containing MediaWiki equivalents for all edited pages, including attachments.
#         2) The MediaWiki XML files for importing individual pages, and XML file(s) for the entire wiki.
#            Note: The upload can be performed completely from within this tool.

# Command format:
#    OSPrompt)  perl mmTOmw.pl [path to moin-moin directory containing data directory]
#         e.g.  perl mmTOmw.pl ./myMoinMoinWiki

# Original motivation: port the W3C DDWG wiki from MoinMoin to MediaWiki in a repeatable manner.

# Features:
# V1.0
# - Interactive "commands with menu and help" textual interface
# - Generates MediaWiki importable XML files from moin-moin directory hierarchy
#   - Provides one or more XML files for the entire wiki to be ported
#   - XML files are split to a configurable size to avoid upload size limits
#   - Also provides individual XML files for separate upload of specific pages
#   - Note: You must upload the XML files via the MediaWiki Sysop account
# - Preserves entire edit history, including timestamps, authors and comments
# - Preserves most of the original moin-moin URLs
# - Exclusion list (external file) to prevent porting of certain wiki pages
# - Only the pages mentioned in the edit history are ported
# - Direct upload of attachements/images from within this program
# - Built-in help
# - Supports many moin-moin markup features:
#   - Tables: width, style, alignment, spanning, borders, padding, cell justification
#   - Lists: bullets, numbers, nested, partial support for lettered lists
#   - Bold, Italic, Underline, Strike, Superscript, Subscript, Large/Small font
#   - Structure: headings, paragraphs, line breaks
#   - Definition styles
#   - Code styles, "Pre" styles, "Nowiki" regions
#   - Wiki links: Inline, CamelCase, Anchor text, Free links, Page inclusion
#   - Attachments: images (become [[Image]]), generic files (become [[Media]])
#   - Inline images
#   - Smilies: <!> {*} {o} {OK} {X}
#   - Wiki page redirects
#   - Wiki page name compatibility (e.g. spaces and underscores are handled correctly)
#   - Common link rewrites (RecentChanges, FindPage, SyntaxReference, SiteNavigation)

# Known limitations
# V1.0
# - Numbered lists must start at 1 (MW limitation)
# - Lists with uppercase letter 'bullets' are not supported (by MW) so are converted to lowercase
# - Cannot continue list numbering after text (e.g. a defn list) that directly follows an item in the middle of a list.
# - Cannot port [[TableOfContents]]  (But MediaWiki makes its own anyway)
# - Cannot import indented lists of definitions (which are rare)
# - Apart from REDIRECT, moin-moin page commands are ignored
# - Cannot port moin-moin slideshow pages
# - Skips all moin-moin pages whose name starts with an escaped character
# - Only works with directory hierarchies from moin-moin version 1.3 or greater


# Special considerations
# - By default, MediaWiki will not support certain file types as attachments (e.g. PDF)
# - Before uploading, you can try using the sandbox to test the generated markup
# - Strongly recommend that the php.ini on the wiki server is edited to have 4Mb upload limit instead of 2Mb

# Assumptions:
#  The target MediaWiki instance is empty.
#  You have the MediaWiki sysop account details

# The moin-moin directory hierarchy
# data/                  (The path to the 'data' directory is input to this program)
#   +---cache/ . . .
#   |
#   +---dict/ . . .
#   |
#   +---pages/
#   |     +---ExampleWikiPage/
#   |     |     +---attachments/
#   |     |     |     |
#   |     |     |     myFile.ext
#   |     |     |     SecondFile.ext
#   |     |     |
#   |     |     +---cache/ . . .
#   |     |     |
#   |     |     +---revisions/
#   |     |     |     |
#   |     |     |     00000001         (moin-moin markup of revision 1)
#   |     |     |     00000002
#   |     |     |     00000003
#   |     |     |
#   |     |     current
#   |     |
#   |     +---SecondExample/ . . .
#   |
#   +---plugin/ . . .
#   |
#   +---plugins/ . . .
#   |
#   +---user/ . . .
#   |
#   edit-log
#   error.log
#   event-log
#   intermap.txt

# The generated MediaWiki directory (containing resources for upload to server)
# myOutputDirectory-mw/
#   +---pages
#   |     +---ExampleWikiPage/
#   |     |     +---attachments/
#   |     |     |     |
#   |     |     |     myFile.ext       (Use built-in "upload" command to upload all attachments)
#   |     |     |     SecondFile.ext
#   |     |     |
#   |     |     00000001               (Generated MediaWiki markup of revision 1)
#   |     |     00000002
#   |     |     00000003
#   |     |     ExampleWikiPage.xml    (Use this to upload an individual page via Special:Upload)
#   |     |
#   |     +---SecondExample/. . .
#   |
#   allpages1.xml                      (Use these to upload the entire wiki via Special:Upload)
#   allpages2.xml
#   allpages3.xml (etc.)
#   instructions.txt                   (In case you need help)

use strict;
use Cwd;
use File::Path;
use File::Copy;
use LWP::UserAgent;
use HTTP::Request::Common;
use Data::Dumper;
use XML::LibXML;

#########################################################################################################################

# Config data (the defaults come from experiments on the DDWG wiki)
my $datapath = './mywiki/data'; # The data directory at the root of the tarball
my $targetpath = './mywiki-mw';    # Destination folder for generated MediaWiki pages
my $testpage; # If defined, this will be the only page processed
my $moinmoinurlbase = 'http://www.w3.org/YYYY/GroupName/wiki/';
my $serverindexurl = 'http://mywiki.ex'; # skip index.php and so on. It is added automatically if needed.
my $splitsize = 1000000; # 1Mb approx split size. Anwhere up to 1Mb is reasonable.
my $MaxXmlSize = '25000000'; # Limit, as per form on the Special:Import page  NOTE: Make this as big as possible on the MW server. (edit php.ini)
my @extensions = ('png', 'jpg', 'gif', 'pdf'); # Extensions that can be uploaded to MediaWiki (This feature not used, yet.)
my $prompt = 'mmTOmw> ';
my $analysed = undef;
my $converted = undef;
my $uploaded = undef;
my $loggedIn = 0;
my $maxAttempts = 1; # number of times to try uploading an attachment
my $TRACE_ATTACHMENTS = undef;

# Diagnostic settings
my $diagnosticShowComparisonLink = 0;

if ($#ARGV >= 0) {
    $datapath = $ARGV[0] . '/data';
    $targetpath = $ARGV[0] . '-mw';
    if (! -d $datapath) {
	die "Directory $datapath not found.\n";
    }
}
else {
    print "Searching for a sub-directory with a Moin-Moin data directory...\n";
    opendir(SUBDIRS, cwd()) || die "Cannot open current directory";
    my @allSubDirs = grep { /^[^\.\(].*/ } readdir(SUBDIRS);
    closedir(SUBDIRS);
    foreach (@allSubDirs) {
	if (-d) {
	    if (-e "$_/data") {
		$datapath = cwd() . "/$_/data";
		$targetpath = cwd() . "/$_" . '-mw';
		print "Found what looks like a Moin-Moin data sub-directory.\n";
		last;
	    }
	}
    }
}
if ($#ARGV >= 1) {$targetpath = $ARGV[1];}
if ($#ARGV >= 2) {$testpage = $ARGV[2];}  # for diagnostic use only

$datapath =~ s/\/$//; $targetpath =~ s/\/$//;

# Collected data
my (@allWikiDirs, @portingDirectories, @deletingDirectories,
    %wikiRevisions, %wikiRevisionComments, %wikiRevisionAuthors, %wikiRevisionTimestamps, @allRevisions, $revisionsTotal,
    %users, @allAttachments, %wikiAttachments, %wikiAttachmentsInDirectory, %wikiAttachmentReferences, $attachmentsTotal,
    %mmLoggedNames, %wikiPageName, %lastRevision, @skip);

# Temporary variables
my ($wikiDirName, $wikiDirPath, $targetDirectory, $copyDirectory, $copyPath,
    $revisionPath, $revisionNumber, $revisionComment, $revisionsPath, $revisionTimestamp,
    $attachment, $attachmentPath, $attachmentsPath, @logItems, $comment, $mmPageDirectory, $p, $wn);

# UA for HTTP uploads
my $ua = LWP::UserAgent->new(
			     agent => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)' ,
			     'cookie_jar' => {file => "wpcookies.txt", autosave => 1}
			     );

# List of pages that are to be skipped (in addition to the ones that were not created by wiki authors)
if (-e 'skip.txt') {
    open(SKIP,'<skip.txt');
    chomp(@skip = <SKIP>);
    close(SKIP);
}

#########################################################################################################################

$| = 1;
print "mmTOmw : Copyright (c) Rotan Hanrahan 2007,2008.\n";
print "This is free software under the W3C License. See source for details.\n";
print "http://www.w3.org/Consortium/Legal/2002/copyright-software-20021231\n";
showsettings();
print "  Type '?' for help\n$prompt";
while (defined(my $command = <STDIN>)) {
    $command =~ s/(^\s*|\s*$)//gs;
		   if ($command =~ /^(quit|exit|bye|end|stop|halt|finish|q|q!|terminate|eoj)$/i) {
		       print "Finished\n";
		       exit 0;
		   }
		   elsif ($command eq 'set') {
		       showsettings();
		   }
		   elsif ($command =~ /^(\?|help|assist|h)$/i) {
		       print "  HELP\n";
		       print "  src [<dir>]              Shot/Set source moinmoin data directory\n";
		       print "  dst [<dir>]              Show/Set destination directory for conversion\n";
		       print "  url [<url>]              Show/Set MW home (eg http://.../wiki/index.php)\n";
		       print "  mmurl [<url>]            Show/Set MM home (eg http://.../source/wiki)\n";
		       print "  split <bytes>            Set approx split size for MediaWiki XML files\n";
		       print "  analyse                  Analyse moinmoin logs and directories\n";
		       print "  convert                  Analyse and then convert pages to MediaWiki format\n";
		       print "  login                    Log in to current MediaWiki server (as Wiki Sysop)\n";
		       print "  upload                   Upload pages and attachments to MediaWiki server\n";
		       print "  set                      Display settings and results of analysis\n";
		       print "  list all|pages|deletes|attachments      Post analysis summaries\n";
		       print "  quit|exit|stop...\n";
		       print "\n";
		       print "  Typical use case:\n";
		       print "  1. Set moinmoin source directory, destination directory & MediaWiki home URL.\n";
		       print "  2. 'Convert' the MM pages to MW pages, and cache results in dest directory.\n";
		       print "  3. 'Upload' the converted data directly to the live MediaWiki server.\n";
		   }
		   elsif ($command =~ /^(src|source)(\s+(\S*))?/i) {
		       if (defined $3) { $datapath = $3; }
		       print "  src = $datapath\n";
		   }
		   elsif ($command =~ /^(dst|dest|destination)(\s+(\S*))?/i) {
		       if (defined $converted) {
			   print "  You cannot change the destination after conversion.\n";
		       }
		       else {
			   if (defined $3) { $targetpath = $3; }
			   print "  dst = $targetpath\n";
		       }
		   }
		   elsif ($command =~ /^(url|mwurl)(\s+(\S+))?/i) {
		       if (defined $3) { $serverindexurl = $3; $loggedIn = 0; }
		       print "  url = $serverindexurl\n";
		   }
		   elsif ($command =~ /^(mmurl|mm)(\s+(\S+))?/i) {
		       if (defined $3) { $moinmoinurlbase = $3; }
		       $moinmoinurlbase =~ s/\/$//;
		       print "  mmURL = $moinmoinurlbase\n";
		   }
		   elsif ($command =~ /^split(\s+(\d+))?$/i) {
		       if (defined $2) { $splitsize = $2; }
		       print "  Split XML files at approx $splitsize bytes\n";
		   }
		   elsif ($command =~ /^(analyse|analyze)$/i) {
		       if (defined $analysed) {
			   print "  To re-do the analysis, restart this program.\n";
		       }
		       else {
			   analyse();
			   showsettings();
		       }
		   }
		   elsif ($command =~ /^list(\s.*)?/i) {
		       if (!defined $analysed) {
			   print "  The list command is only available after analysis.\n";
		       }
		       else {
			   if ($command eq 'list') {
			       print "  list all     : Lists all pages, deletes, attachments and users\n";
			       print "  list pages   : Lists pages to be ported to MediaWiki\n";
			       print "  list deletes : Lists deleted pages that will not be ported\n";
			       print "  list attach  : Lists all attachments\n";
			       print "  list users   : Lists all the moinmoin users\n";
			   }
			   if ($command eq 'list all' || $command =~ /^list\s+pages?/i) {
			       foreach (@portingDirectories) {
				   print "  page   $_\n";
			       }
			   }
			   if ($command eq 'list all' || $command =~ /^list\s+deletes?/i) {
			       foreach (@deletingDirectories) {
				   print "  delete $_\n";
			       }
			   }
			   if ($command eq 'list all' || $command =~ /^list\s+attach/i) {
			       foreach (sort keys %wikiAttachmentsInDirectory) {
				   print '  attach ' . join(', ',@{$wikiAttachmentsInDirectory{$_}}) . "\n      to $_\n";
			       }
			   }
			   if ($command eq 'list all' || $command =~ /^list\s+users?/i) {
			       foreach (sort values %users) {
				   print "  user   $_\n";
			       }
			   }
		       }
		   }
		   elsif ($command =~ /^convert(\s+(\S+))?/) {
		       if (defined $converted) {
			   print "  To repeat the conversion, restart this program.\n";
		       }
		       else {
			   my $timestamp = time();
			   analyse();
			   convert($1 . $testpage);
			   print '  Convertion took ' . (time() - $timestamp) . " seconds.\n";
		       }
		   }
		   elsif ($command eq 'login') {
		       LogIn($serverindexurl);
		   }
		   elsif ($command eq 'upload') {
		       my $timestamp = time();
		       if (!defined $analysed) {
			   print "  Performing analysis to discover attachments...\n";
			   analyse();
		       }
		       if ($ENV{TRACE_ATTACHMENTS}) {
			   open $TRACE_ATTACHMENTS, '>&', $ENV{TRACE_ATTACHMENTS} || die;
		       }
		       Upload($serverindexurl);
		       if ($TRACE_ATTACHMENTS) {
			   close $TRACE_ATTACHMENTS || die;
		       }
		       print '  Upload took ' . (time() - $timestamp) . " seconds.\n";
		   }
		   elsif ($command ne '') {
		       print "  Type '?' for help\n";
		   }
		   print $prompt;
	       }

###########################################################################################################

    sub showsettings {
	print "  src   = $datapath\n";
	print "  dst   = $targetpath\n";
	print "  URL   = $serverindexurl\n";
	print "  mmURL = $moinmoinurlbase\n";
	print "  Split = $splitsize\n";
	if (defined $analysed) {
	    print "  Analysis:\n";
	    print "    " . scalar @portingDirectories . " wiki pages to be ported.\n";
	    print "    " . scalar @deletingDirectories . " wiki pages are deleted and not to be ported.\n";
	    print "    $revisionsTotal revisions in total to be ported.\n";
	    print "    $attachmentsTotal attachments to be ported.\n";
	    print '    ' . (keys %users) . " users recorded in the moinmoin logs.\n";
	}
    }

    sub convert {
	if (defined $converted) { return; }
	my $testpage = shift;
	
	# Create destination folders
	if (!-e "$targetpath") { mkdir("$targetpath") || die "Could not create $targetpath"; }
	if (!-e "$targetpath/pages") { mkdir("$targetpath/pages") || die "Could not create $targetpath/pages"; }
	
	# For each source moinmoin revision, generate a corresponding target MediaWiki document
	my $pageid = 0;
	my $allsize = 0;  # Accumulated XML output to "allpagesNNN.xml". Reset to zero after each split.
	my $allindex = 1; # Index of the split XML files. Increments after each split.
	my @exportedpages;
	open(EXPORTALL,">$targetpath/allpages$allindex.xml") || die "Could not open export file $targetpath/allpages$allindex.xml ($!)";
	ExportPreamble(\*EXPORTALL);
	foreach $wikiDirName (@portingDirectories) {
	    $pageid++;
	    if ($testpage) { next if ($wikiDirName ne $testpage); }
	    $wikiDirPath = "$datapath/pages/$wikiDirName";
	    my $estimatedConvertedSize = sizeOfDirectory("$wikiDirPath/revisions") * 1.25; # Assuming 25% overhead in MediaWiki versions
	    #print "  Estimated size: $wikiDirName = $estimatedConvertedSize bytes\n";
	    $targetDirectory = "$targetpath/pages/$wikiDirName";
	    if (!-e $targetDirectory) { mkdir($targetDirectory) || die "Could not create $targetDirectory"; }
	    (my $title = $wikiDirName) =~ s/\s/_/g; # Not needed for MoinMoin names, but here just in case.
	    open(EXPORTPAGE,">$targetDirectory/$title.xml") || die "Could not open export file $title.xml ($!)";
	    if ($allsize + $estimatedConvertedSize > $splitsize) { # Split the output so that the imports are not much more than $splitsize each
		ExportEnd(\*EXPORTALL);
		if ($allsize > $MaxXmlSize) {
		    print "  WARNING: XML file 'allpages$allindex' exceeds MediaWiki limit.\n";
		}
		$allsize = 0;
		$allindex++;
		open(EXPORTALL,">$targetpath/allpages$allindex.xml") || die "Could not open export file $targetpath/allpages$allindex.xml ($!)";
		ExportPreamble(\*EXPORTALL);
	    }
	    ExportPreamble(\*EXPORTPAGE);
	    ExportPageBegin(\*EXPORTPAGE,$wikiDirName,$pageid);
	    ExportPageBegin(\*EXPORTALL,$wikiDirName,$pageid);
	    foreach $revisionNumber (@{$wikiRevisions{$wikiDirName}}) {
		$revisionPath = "$wikiDirPath/revisions/$revisionNumber";
		$revisionTimestamp = $wikiRevisionTimestamps{$wikiDirName . '#' . $revisionNumber};
		$revisionComment = $wikiRevisionComments{$wikiDirName . '#' . $revisionNumber};
		my $authorID = $wikiRevisionAuthors{$wikiDirName . '#' . $revisionNumber};
		my $mwmarkup = ConvertMM2MW($revisionPath,"$targetDirectory/$revisionNumber",$wikiDirName,$revisionNumber,$revisionComment,$revisionTimestamp);
		ExportPageRevision(\*EXPORTPAGE,$mwmarkup,$revisionNumber,$revisionTimestamp,$revisionComment,$users{$authorID},$authorID);
		ExportPageRevision(\*EXPORTALL,$mwmarkup,$revisionNumber,$revisionTimestamp,$revisionComment,$users{$authorID},$authorID);
		$allsize += length($mwmarkup);
	    }
	    ExportPageEnd(\*EXPORTPAGE);
	    ExportEnd(\*EXPORTPAGE);
	    ExportPageEnd(\*EXPORTALL);
	    push(@exportedpages,$title);
	    if ($testpage) { print "All revisions of $testpage have been created.\n"; last; }
	    foreach $attachment (@{$wikiAttachmentsInDirectory{$wikiDirName}}) {
		$attachmentPath = "$datapath/pages/$wikiDirName/attachments/$attachment";
		$copyDirectory = "$targetpath/pages/$wikiDirName/attachments";
		$copyPath = "$copyDirectory/$attachment";
		if (!-e $copyDirectory) { mkdir($copyDirectory) || die "Could not create $copyDirectory"; }
		copy($attachmentPath,$copyPath) || die "Could not copy attachment $wikiDirName/$attachment - $!";
	    }
	    print "Generated $wikiDirName\n";
	}
	ExportEnd(\*EXPORTALL);
	
	open(INSTRUCTIONS,">$targetpath/instructions.txt") || die "Could not open instructions";
	print INSTRUCTIONS "# To upload the XML files to MediaWiki, log in as Sysop and go to 'Special:Import' page.\n";
	print INSTRUCTIONS "\n\nPages for importing to the target MediaWiki server are:\n";
	foreach (@exportedpages) {
	    print INSTRUCTIONS "  $_\n";
	}
	close(INSTRUCTIONS);
	
	print "Conversion complete.\n";

    }

    sub analyse {
	if (defined $analysed) { return; }
	open(EDITLOG, "<${datapath}/edit-log") || die "Cannot open edit-log";
	while (my $logline = <EDITLOG>) {
	    @logItems = split(/\t{1}/,$logline);
	    if ($logItems[3] ne 'BadContent') {
		$revisionTimestamp   = $logItems[0];
		$revisionNumber      = $logItems[1];
		# 99999999 corresponds to attachments (see http://moinmo.in/MoinDev/Storage)
		if($revisionNumber == '99999999') {
		    next;
		}
		$wikiDirName         = $logItems[3];
		my $revisionAuthorID = $logItems[6];
		chomp($comment = $logItems[8]);
		$mmLoggedNames{$wikiDirName} = 1;
		$wikiRevisionTimestamps{$wikiDirName . '#' . $revisionNumber} = $revisionTimestamp;
		$wikiRevisionAuthors{$wikiDirName . '#' . $revisionNumber} = $revisionAuthorID;
		if ($comment ne '') {
		    $wikiRevisionComments{$wikiDirName . '#' . $revisionNumber} = $comment;
		}
		$lastRevision{$wikiDirName} = $revisionNumber;
	    }
	}
	close(EDITLOG);
	
	# %mmLoggedNames is a map from directories mentioned in the edit-log file to TRUE
	# %wikiRevisionComments is a map from "directory#revision" to comments (for individual revisions)
	# %lastRevision is a map from directories mentioned to the last revision recorded in the log
	#     (Note: if the last revision file is not found, the wiki page has been deleted, possibly spam.)
	
	opendir(WIKIDIRS, "${datapath}/pages") || die "Cannot open data/pages";
	@allWikiDirs = grep { /^[^\.\(].*/ && "$(datapath}/pages/$_" } readdir(WIKIDIRS);  # list of all moinmoin wiki page directories
	closedir(WIKIDIRS);
	
	foreach $mmPageDirectory (@allWikiDirs) {
	    if ($mmLoggedNames{$mmPageDirectory}) {
		if (-e "$datapath/pages/$mmPageDirectory/revisions/$lastRevision{$mmPageDirectory}") {
		    push(@portingDirectories,$mmPageDirectory);
		}
		else {
		    push(@deletingDirectories,$mmPageDirectory);
		}
	    }
	}
	
	# @portingDirectories now lists all the new wiki directories that exist and are to be ported to MediaWiki format
	# @deletingDirectories now lists all the wiki directories that will not be ported as the last revision was a deletion
	# These directory names will be used as hash keys for all pages from now.
	
	foreach $p (@portingDirectories) {
	    ($wn = $p) =~ s/_/ /g;    # "_" is replaced by space
	    $wn =~ s/\(2f\)/\//gi;    # (2f) is replaced by "/"
	    $wikiPageName{$p} = $wn;
	}
	
	# %wikiPageName now maps directory names to wiki names
	
	foreach $p (@portingDirectories) {
	    $revisionsPath = "${datapath}/pages/$p/revisions";
	    if (-e $revisionsPath) {
		opendir(REVISIONSDIR, $revisionsPath) || die "Cannot open $revisionsPath";
		@allRevisions = sort grep { /^[^\.].*/ } readdir(REVISIONSDIR);
		closedir(REVISIONSDIR);
		if (@allRevisions) {
		    $wikiRevisions{$p} = [ @allRevisions ];
		}
		$revisionsTotal += scalar @allRevisions;
	    }
	}
	
	# %wikiRevisions now maps directory names to lists of revisions
	
	foreach $p (@portingDirectories) {
	    $attachmentsPath = "${datapath}/pages/$p/attachments";
	    if (-e $attachmentsPath) {
		opendir(ATTACHMENTSDIR, $attachmentsPath) || die "Cannot open $attachmentsPath";
		@allAttachments = sort grep { /^[^\.].*/ } readdir(ATTACHMENTSDIR);
		closedir(ATTACHMENTSDIR);
		foreach $attachment (@allAttachments) {
		    my $pagename = ConvertToMWName_($p);
		    $pagename =~ s/\//\$\$/g; # "/" -> "$$"
		    $wikiAttachments{$pagename . '$' . $attachment} = "pages/$p/attachments/$attachment";
		}
		$wikiAttachmentsInDirectory{$p} = [ @allAttachments ];
		$attachmentsTotal += $#allAttachments + 1;
	    }
	}
	
	# %wikiAttachmentsInDirectory now maps directory names to lists of attachments
	# %wikiAttachments now maps MW upload names to the local paths of the upload files
	
	opendir(USERSDIR,"${datapath}/user") || die "Could not open ";
	foreach (grep { /^[\d\.]{3,}(?<!\.trail)$/ } readdir(USERSDIR)) {
	    my $userid = $_;
	    open(USER,"<${datapath}/user/$userid") || die "Could not open user file $userid";
	    my $userdata = do { local( $/ ); <USER> };
	    close(USER);
	    $userdata =~ m/\bname=(\w*)/s;
	    $users{$userid} = $1;
	}
	closedir(USERDIR);
	
	# %users now maps moinmoin user IDs to user names
	
	$analysed = 1;
    }

    sub ExportBegin { # Params: TitleWithSpaces,Directory,PageID
	my $spacedtitle = shift;
	my $directory = shift;
	my $pageid = shift;
	(my $title = $spacedtitle) =~ s/\s/_/g; # Not needed for MoinMoin names, but here just in case.
	open(EXPORT,">$directory/$title.xml") || die "Could not open export file $title.xml ($!)";
	ExportPreamble(\*EXPORT);
	ExportPageBegin(\*EXPORT,$spacedtitle,$pageid);
    }

    sub ExportPreamble { # Param: \*FileHandle
	my $filehandle = shift;
	print $filehandle
	    "<mediawiki\n" .
	    "  xmlns=\"http://www.mediawiki.org/xml/export-0.3/\"\n" .
	    "  xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n" .
	    "  xsi:schemaLocation=\"http://www.mediawiki.org/xml/export-0.3/ http://www.mediawiki.org/xml/export-0.3.xsd\"\n" .
	    "  version=\"0.3\"\n" .
	    "  xml:lang=\"en\">\n";
    }

    sub ExportPageBegin { # Params: \*FileHandle,TitleWithSpaces,PageID
	my $filehandle = shift;
	my $spacedtitle = shift;
	my $pageid = shift;
	print $filehandle
	    "  <page>\n" .
	    "    <title>" . XMLEscaped(ConvertToMWName($spacedtitle)) . "</title>\n" .
	    "    <id>$pageid</id>\n";
    }

    sub ExportPageRevision { # Params: \*FileHandle,MWMarkup,RevisionID,TimeStamp,Comment,User,UserID  Note: TS=YYYY-MM-DDThh:mm:ssZ
	my $filehandle = shift;
	my $mwmarkup = shift;       # MediaWiki markup (not XML escaped)
	my $revisionid = 0 + shift; # Numeric ID with no leading zeros
	my ($ss,$mm,$hh,$md,$MM,$YY,undef,undef,undef) = gmtime(substr(shift,0,10));
	my $timestamp = sprintf('%04d-%02d-%02dT%02d:%02d:%02dZ',$YY+1900,$MM+1,$md,$hh,$mm,$ss);
	my $comment = shift;        # No line breaks
	my $username = shift;       # Name of MediaWiki user
	my $userid = shift;         # Numeric ID of MediaWiki user
	print $filehandle
	    "    <revision>\n" .
	    "      <id>$revisionid</id>\n" .
	    "      <timestamp>$timestamp</timestamp>\n" .
	    "      <contributor>\n" .
	    "        <username>$username</username>\n" .
	    "        <id>$userid</id>\n" .
	    "      </contributor>\n" .
	    "      <comment>".XMLEscaped($comment)."</comment>\n" .
	    "      <text xml:space=\"preserve\">";
	print $filehandle XMLEscaped($mwmarkup);
	print $filehandle
	    "</text>\n" .
	    "    </revision>\n";
    }

    sub ExportPageEnd { # Param: \*FileHandle
	my $filehandle = shift;
	print $filehandle "  </page>\n";
    }

    sub ExportEnd { # Param: \*FileHandle
	my $filehandle = shift;
	print $filehandle
	    "</mediawiki>\n";
	close($filehandle);
    }

    sub sizeOfDirectory {
	my $directoryPath = shift;
	my $totalBytes = 0;
	opendir(SIZEDIR,$directoryPath) || die "Could not open ";
	foreach (grep { /^[^\.].*/ } readdir(SIZEDIR)) {
	    $totalBytes += -s "$directoryPath/$_";
	}
	closedir(SIZEDIR);
	return $totalBytes;
    }


# Escape reserved XML characters by replacing with markup entities
    sub XMLEscaped {
	my $text = shift;
	$text =~ s/&/&amp;/go;
	$text =~ s/</&lt;/go;
	$text =~ s/>/&gt;/go;
	$text =~ s/'/&apos;/go; #'
	$text =~ s/"/&quot;/go; #"
	return $text;
    }

# See here for moinmoin syntax: http://www.w3.org/2005/MWI/DDWG/wiki/SyntaxReference
# And here: http://www.w3.org/2005/MWI/DDWG/wiki/HelpOnEditing
    sub ConvertMM2MW { # Params: infile,outfile,mmname,revision,comment,timestamp
	my $infile = shift;
	my $outfile = shift;
	my $mmname = shift;
	my $revision = shift;
	my $comment = shift;
	my $edittimestamp = shift;
	my $mwname = ConvertToMWName($mmname);
	my $editdate =  gmtime(substr($edittimestamp,0,10));
	my $doc = ConvertToMW($infile,$mwname);
	open(OUTFILE, ">$outfile") || die "Could not open $outfile";
	print OUTFILE "<!-- MoinMoin name:  $mmname -->\n";
	print OUTFILE "<!-- Comment:        $comment -->\n";
	print OUTFILE "<!-- WikiMedia name: $mwname -->\n";
	print OUTFILE "<!-- Page revision:  $revision -->\n";
	print OUTFILE "<!-- Original date:  $editdate ($edittimestamp) -->\n";
	print OUTFILE "\n";
	print OUTFILE $doc;
	close OUTFILE;
	close INFILE;
	return $doc;
    }

# This converts a MoinMoin page name to a MediaWiki name, with spaces instead of underscores
    sub ConvertToMWName { # Param: moinmoinpagename
	(my $a = shift) =~ s/\((.*?)\)/DeHex($1)/ige;
	$a =~ s/Category(.*)/Category:$1/;
	$a =~ s/_/ /g;
	return $a;
    }

# This converts a MoinMoin page name to a MediaWiki name, with underscores for spaces
    sub ConvertToMWName_ { # Param: moinmoinpagename
	(my $a = shift) =~ s/\((.*?)\)/DeHex($1)/ige;
	$a =~ s/\s/_/g;
	return $a;
    }

# This converts embedded hex "...(HH...HH)..." into real characters
    sub DeHex { # Param: string of hex bytes
	my $x = uc shift;
	my @y;
	return pack('(H2)*',(@y = (split(' ',(($x =~ s/(..)/$1 /g),$x)),@y)));
    }

# This converts a MoinMoin table row into a MediaWiki table row
# See: http://www.w3.org/2005/MWI/DDWG/wiki/SyntaxReference
# See: http://www.mediawiki.org/wiki/Help:Tables
    sub ProcessTableRow {
  chomp(my $mmtr = shift);
  my $x;
  my $style;
  my $celltext;
  my $startspanpos;
  # Convert long colspans into ||<-N> format
  while (($startspanpos = index($mmtr,'||||')) >= 0) {
    my $spans = substr($mmtr,$startspanpos); $spans =~ m/^(\|*)/; $spans = $1;
    my $endspanpos = rindex($mmtr,'|',$startspanpos);
    substr($mmtr,$startspanpos,length($spans)) = '||<-' . (length($spans) / 2) . '>';
  }
  my @cells = split(/\|\|/,$mmtr);
  @cells = @cells[1..@cells-2];
  my $mwcells = '';
  foreach $x (@cells) {
    if ( $x =~ m/^\s*((<.[^>]+>|<\(>|<:>|<\)>)+)(.+)/ ) {
      $style = $1;
      $celltext = $3;
      # combinations
      $style =~ s/<(\(|:|\)|\^|v)([^>]+)>/<$1><$2>/g;   # e.g.  <:90%>  -->  <:><90%>
      # background colour
      $style =~ s/<(#[^:]*?):>/bgcolor="$1" /g;
      $style =~ s/<bgcolor=([^>]+)>/bgcolor=$1 /g;
      # alignment
      $style =~ s/<\(>/align="left" /g;
      $style =~ s/<style="align\s*:\s*(left|right|center);">/align="$1" /g;
#      $style =~ s/<style="align\s*:\s*left;">/align="left" /g;
      $style =~ s/<\:>/align="center" /g;
#      $style =~ s/<style="align\s*:\s*center;">/align="center" /g;
      $style =~ s/<\)>/align="right" /g;
#      $style =~ s/<style="align\s*:\s*right;">/align="right" /g;
      $style =~ s/<\^>/valign="top" /g;
#      $style =~ s/<style="vertical-align\s*:\s*top;">/valign="top" /g;
      $style =~ s/<v>/valign="bottom" /g;
      $style =~ s/<style="vertical-align\s*:\s*(top|bottom);">/valign="$1" /g;
      # rowspan
      $style =~ s/<\|(\d+)>/rowspan="$1" /g;
      $style =~ s/<(rowspan=[^>]+)>/$1 /g;
      # colspan
      $style =~ s/<-(\d+)>/colspan="$1" /g;
      $style =~ s/<(colspan=[^>]+)>/$1 /g;
      # width
      $style =~ s/<(\d+)\%>/width="$1%" /g;
      # everything else
      $style =~ s/tablewidth=".+"/ /g;
      $style =~ s/<(rowbgcolor)[^>]+>/ /g;
      $style =~ s/<(\w+=[^>])>/$1 /g;
      $mwcells .= "|$style|$celltext\n";
    }
    else {
      $mwcells .= "| $x\n";
    }
  }
  return $mwcells;
}

sub ConvertToMW { # Params: MMFilePath, MMName
  my $mmfile = shift;
  open(INFILE, "<$mmfile") || die "Could not open $mmfile";
  my $mwname = shift;
  (my $mwname_ = $mwname) =~ s/\s/_/g; # MW name with "_" instead of " "
  my $prev = '';
  my $listprefix = '';
  my $replacementprefix;
  my $tabledepth = 0;
  my $line;
  my @lines;
  my $replacement;
  my $incode = 0;
  my $toc = 0;
  my $previouslistindent = '';
  my @indents;
  my @bullets;
  while ($_ = ($line = <INFILE>)){
 		next if /^----$/; 	# remove unneeded header lines

    if (/\}\}\}/) {
      $incode = 0; # Current line contains }}} marking end of code
    }
    if ($incode) {
      push(@lines,$line); # In the middle of 'code', so don't convert the wiki markup
      next;
    }
    if (/\{\{\{(?!.*\}\}\})/) {
      $incode = 1; # Current line contains {{{ with no following }}}, so all subsequent lines will be code. (But wiki-convert this line!)
    }

    # Line-by-line conversions. Most of these will not span across multiple lines.

    # MoinMoin command conversions
    $line =~ s/^\#REDIRECT \[\[(.*?)\]\]/[[ConvertToMWName($1)]]/e;   # Redirect
    # Comment out any remaining moinmoin commands (lines starting with #)
    $line =~ s/^(\#.*)$/<!-- $1 -->/;
      
    # Normalisation of indented lists
    #    A. xxxxxxx                  indent = '   '               bullet = A   level = 0
    #         1. xxxxxx              indent = '        '          bullet = 1   level = 1
    #         1. xxxxxx              indent = '        '          bullet = 1   level = 1
    #      A. xxxxxxxx               indent = '     '             bullet = A   level = 0
    #           a. xxxxxxx           indent = '           '       bullet = a   level = 1
    #                * xxxxxxxx      indent = '                 ' bullet = *   level = 2
    #                * xxxxxxxx      indent = '                 ' bullet = *   level = 2
    # Becomes:
    # * '''A)''' xxxxxxx
    # *# xxxxxx
    # *# xxxxxx
    # * '''B)''' xxxxxxxx
    # ** '''a)''' xxxxxxx
    # *** xxxxxxxx
    # *** xxxxxxxx

    # Common errors #
    $line =~ s/^(\s*)\.\s/$1* /; # Replace false bullet
    $line =~ s/\x0b/^k/g; # Replace ^k
    $line =~ s/\x0f/^o/g; # Replace ^o
    $line =~ s/\x00/^@/g; # Replace ^@
    $line =~ s/\x08/^h/g; # Replace ^h
    $line =~ s/\x03/^c/g; # Replace ^c
    $line =~ s/\x0c/^l/g; # Replace ^l
    $line =~ s/\x1b/^[/g; # Replace ^l
    $line =~ s/\x0d//g; # Replace ^m
    
    $line =~ s/^(\s*\*)(\S)/$1 $2/; # Insert missing space after bullet in moin-moin list (common error)
    
    if ($line =~ /^([A-Za-z]\.|\*)\s+.+$/) {
      $line = " $line"; # indent lines that look like list elements that have forgotted their leading space
    }
    
    if ($line =~ /^\s(\s*)((\d+|[\*aAi])\.|\*)\s+(.*)$/) {
      my $currentindent = $1;
      my $text = $4;
#      my $bullet = substr($2,0,1);
      my $bullet = $2;
      $bullet =~ s/\.//;
      my $b;
      if ($bullet eq 'i') { $bullet = '1'; } # Don't support Roman bullets (not yet, anyway)
      my $indentlevel = scalar(@indents);
      if ($indentlevel == 0) { # This is the beginning of a new outermost list
        $indents[0] = $currentindent; # record the initial indentation
        $bullets[0] = $bullet;        # and the initial bullet
      }
      else { # At least one line of the list has already been processed
        # Is this indent bigger, smaller or the same as the previous indent?
        my $previousindent = $indents[$indentlevel-1];
        if (length($currentindent) < length($previousindent)) { # list is receding
          while ($indentlevel > 0 && length($currentindent) <= length($previousindent)) { # recede
            $indentlevel--;
            $previousindent = $indentlevel?$indents[$indentlevel-1]:''; # examine the "previous previous" indents
          }
          # At this point the current indent matches the indent at $indentlevel-1
          $indentlevel--; # Now $indentlevel is the correct list level for the current line
          if ($indentlevel <= 0) { $indentlevel = 0; } # Unless the list appears to have started at a level greater than 1 !
          $#indents = $indentlevel; # As we have receded to an outer level, the recorded inner level indents should be removed
          #$#indents = $indentlevel?$indentlevel-1:0; $indentlevel--;
          $b = $bullets[$indentlevel]; # When you recede to an outer level, you *must* continue that level's bullet type
          if ($b =~ /[A-Ya-y]/) {
            $bullets[$indentlevel] = chr ( ord ($b) + 1);  # When continuing a level, increment lettered bullets
          }
        }
        else { # list is not receding
          if (length($currentindent) > length($previousindent)) { # this line is indented further than the previous line
            $indents[$indentlevel] = $currentindent;  # record the new indentation
            $bullets[$indentlevel] = $bullet;         # and the new bullet
          }
          else { # level has remained the same
            $indentlevel--;                 # have not actually indented further, so undo the level increment
            $b = $bullets[$indentlevel];    # and examine the bullet from this same level ...
            if ($b =~ /[A-Ya-y]/) {
              $bullets[$indentlevel] = chr ( ord ($b) + 1);   # ... to see if it is a letter bullet that requires incrementing.
            }
          }
        }
      }
      my $bulletleader = '';
      for my $i (0..$indentlevel) { # MediaWiki list item starts with sequence of bullets from level 0 upwards
        $b = $bullets[$i];
        if ($b eq '*' || $b =~ /[A-Za-z]/) {
          $bulletleader .= '*';   # Dot or lettered bullet
        }
        else {
          $bulletleader .= '#';   # Digit
        }
      }
      if ($b =~ /[A-Za-z]/) {
        $bulletleader .= " '''$b)'''"; # MediaWiki syntax doesn't have lettered bullets, so insert the letter as a bold extra
      }
      $line ="$bulletleader $text\n";
    }
    elsif ($line !~ /^\s*$/) { # We have stopped processing a list; this line is from something else.
      $#indents = -1;
    }
    else { # This is a blank line. If it occurs in the middle of a list, we can have trouble.
      $line = "<!--BLANK-->\n"; # Use "blank line" marker. Will be removed after all lines are processed.
    }
    
    $_ = $line; # Simplify subsequent regex substitutions

    # List conversion (DEPRECATED. Replaced by code above.)
      #s/^ \*(\s*.*?)/\*$1/;     	       # 1  ' * xxx'    ->  '* xxx'
      #s/^  \*(\s*.*?)/\*\*$1/;	         # 2  '  * xxx'   ->  '** xxx'
      #s/^   \*(\s*.*?)/\*\*\*$1/;        # 3  '   * xxx'  ->  '*** xxx'
      #s/^    \*(\s*.*?)/\*\*\*\*$1/;     # 4             etc.
      #s/^     \*(\s*.*?)/\*\*\*\*\*$1/;  # 5
      #s/^(\s+1\.)#(\d+)/$1 <!-- ! Should start numbering at $2 -->/; # Remove number starts. MW syntax only permits starting at 1
      #s/^(\s+)(\d+)\.\s*$/:$2./;         # Common idiom. A number on its own on a line. Almost like a numbered list, but not.
      #s/^ \d+\.\s+(.*)$/# $1/;           # 1  ' 1. xxx'    ->  '# xxxx'         Note: numbering is forced to start at 1
      #s/^  \d+\.\s+(.*)$/## $1/;         # 2  '  1. xxx'   ->  '## xxxx'
      #s/^   \d+\.\s+(.*)$/### $1/;       # 3  '   1. xxx'  ->  '### xxxx'
      #s/^    \d+\.\s+(.*)$/#### $1/;     # 4             etc.
      #s/^     \d+\.\s+(.*)$/##### $1/;   # 5
      #s/^ (a|A)\.\s+(.*)$/# $2/;         # 1  ' a. xxx'    ->  '# xxxx'
      #s/^  (a|A)\.\s+(.*)$/## $2/;       # 2  '  a. xxx'   ->  '## xxxx'
      #s/^   (a|A)\.\s+(.*)$/### $2/;     # 3  '   a. xxx'  ->  '### xxxx'
      #s/^    (a|A)\.\s+(.*)$/#### $2/;   # 4  '          etc.
      #s/^     (a|A)\.\s+(.*)$/##### $2/; # 5

    # Markup conversion (when on a single line)
  		s/\^(.*?)\^/\<sup\>$1\<\/sup\>/g;                      # ^ * ^     ->  <sup> * </sup>
  		s/\,\,(.*?)\,\,/\<sub\>$1\<\/sub\>/g;                  # ,, * ,,   ->  <sub> * </sub>
 		  s/__(.*?)__/\<u\>$1\<\/u\>/g;                          # __ * __   ->  <u> * </u>
 		  s/--\((.*?)\)--/\<s\>$1\<\/s\>/g;                      # --( * )-- ->  <s> * </s>
# Mediawiki seems to understand ''', '' and '''''
# 		  s/'''(.*?)'''/\<b\>$1\<\/b\>/g;                        # ''' * ''' ->  <b> * </b>
# 		  s/''(.*?)''/\<i\>$1\<\/i\>/g;                          # '' * ''   ->  <i> * </i>
      s/~\+(.*?)\+~/\<span style="font-size: larger"\>$1\<\/span\>/g;     # ~+xxx+~  ->  <span style="font-size: larger">xxx</span>
      s/~-(.*?)-~/\<span style="font-size: smaller"\>$1\<\/span\>/g;      # ~-xxx-~  ->  <span style="font-size: smaller">xxx</span>
      s/^ (.*?):: (.*)$/; $1 : $2/;                          # x:: y     ->  ; x : y
  		s/\[\[BR\]\]/\<br\>/g;                                 # [[BR]]    ->  <br>

      # Categories
      s/\[http:Category(\w+)\]/[[Category:$1]]/g;
      s/\["[^["]*\bCategory(\w+)"\]/[[Category:$1]]/g; #"
      s/\[\[?CategoryCategory\]?\]//g;
      s/\bCategoryCategory\b//g;
      s/\[\[?Category(([A-Z][a-z0-9]+)+)\]?\]/[[Category:$1]]/g;
      s/\bCategory(([A-Z][a-z0-9]+)+)\b/[[Category:$1]]/g;
      if($mwname =~ /^Category/) {
	  s/----\s*//s;
	  s/'''List of pages in this category:'''\s*//s;
	  s/To add a page to this category, add a link to this page on the last line of the page. You can add multiple categories to a page\.\s*//s;
	  s/Describe the pages in this category\.\.\.\s*//s;
          s/\[\[FullSearch(\([^)]*\))?\]\]\s*//s;
      }


		# Link conversion
    ## comment these out as MoinMoin link syntax has changed since 1.5
    ## see http://moinmo.in/HelpOnLinking
    # s/\[\#([^\s|]+)[\s|]+([^\]]+)\]/\[\[\#$1|$2\]\]/g;     # [#Foo bar]   ->  [[#Foo|bar]]
    #	s/(?<!\[)\[\#([^\s:]+)\]/\[\[\#$1\]\]/g;                      # [# * ]   ->  [[ * ]]
    #	s/\[\"(.*?)\"\]/\[\[$1\]\]/g;                          # [" * "]  ->  [[ * ]]    (This may be covered by Free Link below)
                s/\[:([^:\]]+):([^\]]+)\]/[[$1|$2]]/g;                 # [:HTML/AddedElementEmbed:embed] -> [[HTML/AddedElementEmbed|embed]]
  		s/\[\:(.*?)\]/\[\[$1\]\]/g;                            # [: * ]   ->  [[ * ]]
    
    # Images
      s/\binline:(\S+\.(png|jpg|gif))/[[Image:$1]]/g;        # inline:mypic.png  ->  [[Image:mypic.png]]

		# One-line wrappers
	    s/\{\{\{(.*?)\}\}\}/<code\>\<nowiki\>$1\<\/nowiki\>\<\/code\>/g;	# {{{ * }}}  ->  <code><nowiki> * </nowiki></code>

		# Multi-line wrappers
  		s/\{\{\{(.*?)/\n\<pre\>\<nowiki\>$1/g;	                 # {{{ *   ->  <pre><nowiki> *
  		s/(.*?)\}\}\}/$1\<\/nowiki\><\/pre\>\n/g;                #  * }}}  ->  * <\pre><\nowiki>
      s/--\(/<span style="text-decoration: line-through">/g; # --(  ->  <span style="text-decoration: line-through">  # could also use <s>   ?
      s/\)--/<\/span>/g;                                     # >--  ->  </span>                                       # could also use </s>  ?

    # Smileys
      s/<!>/<span style="font-size: x-large; color: red">!<\/span>/g;             # <!>  ->  <span style="font-size: x-large; color: red">!</span>
      s/\{\*\}/<span style="font-size: x-large; color: orange">*<\/span>/g;       # {*}  ->  <span style="font-size: x-large; color: orange">*</span>
      s/\{o\}/<span style="font-size: x-large; color: cyan">&curren;<\/span>/g;   # {o}  ->  <span style="font-size: x-large; color: cyan">&curren;</span>
      s/\{OK\}/<span style="font-size: large; color: green; background: yellow">OK<\/span>/g;  # {OK} ->  <span style="font-size: large; color: green; background: yellow">OK</span>
      s/\{X\}/<span style="font-size: large; color: white; background: red">X<\/span>/g;  # {OK} ->  <span style="font-size: large; color: white; background: red">X</span>
      # To Do : the rest of the smileys

    # Wiki links
    ## comment these out as MoinMoin link syntax has changed since 1.5
    ## see http://moinmo.in/HelpOnLinking
      # s/\/CommentPage/???/g;                               # To Do
      s/\[\[GetText\((\w+)\)\]\]/$1/g;                       # [[GetText(xx)]] -> xx
#      s/((?<!)[A-Z][a-z]+[A-Z][a-z]+[A-Za-z]*)([^`])/[[$1]]$2/g;  #`# CamelCaseWord -> [[CamelCaseWord]]
#      s/((?<!\w)[A-Z]\w*[a-z]\w*[A-Z]\w+)/[[$&]]/g;
      s/\[\[(http:[^\|]+)\|([^\]]+)\]\]/[$1 $2]/g;
      s/\[\[(https:[^\|]+)\|([^\]]+)\]\]/[$1 $2]/g;
      s/\[\[(http:[^\|]+)\]\]/$1/g;
      s/\[\[(https:[^\|]+)\]\]/$1/g;

      if(s/<<TableOfContents>>//g) {     # Cannot support TOC mid-text, but can put comment in.
	  $toc = 1;
      }
      s/= Table of Contents =//g;
      s/== Table of Contents ==//g;
      s/=== Table of Contents ===//g;
      s/<<FullSearch(\([^)]*\))?>>//g;

      s/(?<![\&!\/#])\b([A-Z][a-z0-9]+){2,}(\/([A-Z][a-z0-9]+){2,})*\b/[[$&]]/g;                   #`# CamelCaseWord -> [[CamelCaseWord]]
      s/!([A-Z][a-z]+[A-Z][a-z]+[A-Za-z]*)([^`])/$1$2/g;     #`# !CamelCaseWord -> CamelCaseWord
      s/\[\[\[(\w+)\]\]\s+(.+?)\]/[[$1|$2]]/g;               # [[[WikiPageName]] words] -> [[WikiPageName|words]]
      s/\[([^\]]+)\[\[(.*?)\]\](.*?)\]/[$1$2$3]/g;           # [...[[...]]...]   ->  [.........]  repair accidental [[CamelCasing]]
      s/<<Anchor\((\w+)\)>>/<span id="$1"><\/span>/g;    # [[Anchor(name)]] -> <span id="name"></span>
      s/<<Include\((.*?)\)>>/{{:$1}}/g;                  # [[Include(OtherPage)]]  ->  {{:OtherPage}}
      
    # Boilerplate Phrases
      s/This wiki is powered by \[\[MoinMoin\]\]//g;
      s/<<FindPage>>/[[Special:Search|FindPage]]/g;
      s/(<<SyntaxReference>>)/(\[http:\/\/meta.wikimedia.org\/wiki\/Help:Editing SyntaxReference\])/g;
      s/<<SiteNavigation>>/\[\[Special:Specialpages|SiteNavigation\]\]/g;
      s/<<RecentChanges>>/\[\[Special:Recentchanges|RecentChanges\]\]/g;

    # Final tidy
      s/``//g;   # NonLinkCamel``CaseWord  ->  NonLinkCamelCaseWord
      s/\{\{attachment:([^\s\/]+\.(png|jpg|gif)) ([^\]]+)\}\}/[[Image:$mwname_\/attachments\/$1|$2]]/g;  # [attachment:file.png/jpg/gif]  ->  [[Image:MoinMoinPageName/attachments/file.ext]]
      s/\{\{attachment:(\S+\.(png|jpg|gif)) ([^\]]+)\}\}/[[Image:$1|$2]]/g;  # [attachment:file.png/jpg/gif]  ->  [[Image:MoinMoinPageName/attachments/file.ext]]
      s/\{\{attachment:([^\s\/]+\.(png|jpg|gif))\}\}/[[Image:$mwname_\/attachments\/$1]]/g;              # [attachment:file.png/jpg/gif]  ->  [[Image:MoinMoinPageName/attachments/file.ext]]
      s/\{\{attachment:(\S+\.(png|jpg|gif))\}\}/[[Image:$1]]/g;              # [attachment:file.png/jpg/gif]  ->  [[Image:MoinMoinPageName/attachments/file.ext]]
      s/\{\{attachment:([^\s\/]+) ([^\]]+)\}\}/[[Media:$mwname_\/attachments\/$1|$2]]/g;                 # [attachment:file.ext]  ->  [[Media:MoinMoinPageName/attachments/file.ext]]
      s/\{\{attachment:(\S+) ([^\]]+)\]/[[Media:$1|$2]]/g;                 # [attachment:file.ext]  ->  [[Media:MoinMoinPageName/attachments/file.ext]]
      s/\{\{attachment:([^\s\/]+)\}\}/[[Media:$mwname_\/attachments\/$1]]/g;                             # [attachment:file.ext]  ->  [[Media:MoinMoinPageName/attachments/file.ext]]
      s/\{\{attachment:(\S+)\}\}/[[Media:$1]]/g;                             # [attachment:file.ext]  ->  [[Media:MoinMoinPageName/attachments/file.ext]]

      # Final cleaning in case some pbs got introduced by the CamelCase regexp					    
      s/\[([^\]]+)\[\[(.*?)\]\](.*?)\]/[$1$2$3]/g;           # [...[[...]]...]   ->  [.........]  repair accidental [[CamelCasing]]

    $replacement = $_;
    
    # The following code adjusts the markup for typical nested lists.
    # It does not deal with nested indented lists of definitions, though these are not normal in moinmoin
    # NOTE: This list processing may no longer be necessary following the list transform updates
    #if ($listprefix) { # if we are already processing a list
    #  if ($replacement =~ m/^([#\*]+)/) { # if we are continuing a list
    #    $replacementprefix = $1;
    #    if (length($replacementprefix) < length($listprefix)) { # list has un-indented
    #      $listprefix = substr($listprefix,0,length($replacementprefix)); # shrink the prefix accordingly
    #    }
    #    substr($replacement,0,length($listprefix)) = $listprefix; # ensure the current prefix matches the previous
    #    $replacement =~ m/^([#\*]+)/;
    #    $listprefix = $1;
    #  }
    #}
    #else {
    #  if ($replacement =~ m/^([#\*]+)/) { # if we have started a list
    #    $listprefix = $1;
    #  }
    #}
    # end of list processing

    if ($tabledepth == 0) { # are we outside a table?
      if ($replacement =~ m/^\|\|/) { # and are we starting a new table?
        $tabledepth++; # yes, we are now in a new table
        $replacement = "{| border=\"1\" cellpadding=\"2\" cellspacing=\"0\"\n" . ProcessTableRow($replacement);
      }
    }
    else { # we are possibly in the middle of a table
      if ($replacement !~ m/^\|\|/) { # no more table markup, so we are exiting the table
        $replacement = "|}\n" . $replacement;
        $tabledepth--;
      }
      else { # we are continuing to another row of the table
        $replacement = "|-\n" . ProcessTableRow($replacement);
      }
    }

    # Transform attachment URLs MoinMoinPageName/attachments/filename.ext  ->  MoinMoinPageName$filename.ext   $$
    while ($replacement =~ m/\[\[(Image|Media):([^\]\/]*?)\//) {
	$replacement =~ s/\[\[(Image|Media):([^\]\/]*?)\//[[$1:$2\$\$/;
    }
    $replacement =~ s/\$\$attachments\$\$/\$/g;
    while ($replacement =~ m/\[\[(Image|Media):(.*?)\]\]/g) {
      $wikiAttachmentReferences{$2} += 1;
    }
    $replacement =~ s/\[\[(Image|Media)(:[^\]]+)\$\$([^\]\$]+)]\]/[[$1$2\$$3]]/g;							   

    push(@lines,$replacement);
    $prev = $replacement; # remember the previously generated MW line (e.g. for list prefix comparisons)
  } # end while <line>
  close(INFILE);

  my $doc = "";
  if(!$toc) {
      $doc = "__NOTOC__\n";
  }
  $doc .= join('',@lines);

  
  # Global edits to the entire document
  $doc =~ s/<!--BLANK-->\n(<!--BLANK-->\n)+/<!--BLANK-->\n/gs; # Collapse multipled BLANK lines into one
  $doc =~ s/([ \t]*[\*\#][^\n]+\n)<!--BLANK-->\n(?=[ \t]*[\*\#])/$1$2/gs; # Remove BLANKs that occur in the middle of lists
  $doc =~ s/<!--BLANK-->\n/\n/gs; # Reinstate remaining BLANKs as actual blank lines
  
  if ($diagnosticShowComparisonLink) {
    $doc = "''Compare'': $moinmoinurlbase$mwname_\n\n" . $doc; # Diagnostic
  }
  return $doc;
}

# Interactive login
sub LogIn { # Params: MediaWikiURL
  my $mwurl = shift;
  if ($loggedIn) { return 1; }
	print "  Enter the MediaWiki Sysop user name: ";
	my $username = <STDIN>;
	$username =~ s/\s*$//;
	print "  Enter the password: ";
	my $password = <STDIN>;
	$password =~ s/\s*$//;
	print "  Logging into MediaWiki server...\n";
	if (!LogInToServer($mwurl,$username,$password)) {
	  print "  Failed to log in. Check username and password.\n";
	  return 0;
	}
	print "  Logged in successfully.\n";
	return 1;
}

# Non-interactive login
sub LogInToServer { # Params: MediaWikiURL,username,password
  my $wikiurl = shift;
 	my %params = ();
	$params{'lgname'} = shift;
	$params{'lgpassword'} = shift;
	$params{'action'} = 'login';
	$params{'format'} = 'xml';
	my $response = $ua->request(
		POST "$wikiurl/api.php" ,
		Content_Type => 'application/x-www-form-urlencoded' ,
		Content => [ %params ]
	);
	$loggedIn = 0;
#	print Data::Dumper->Dump([$response], [qw(response)]);
	my $dom = XML::LibXML->load_xml(string => $response->{'_content'});
#	print $dom->toStringHTML();
	my $node = $dom->findnodes("//login[\@result]")->get_node(1);
#	print $node->getAttribute('result');
#	print "\n";
	my $loginResult = $node->getAttribute('result');
	
	
	if ($loginResult eq 'NeedToken') {
		print "Need token...\n";
		$params{'lgtoken'} = $node->getAttribute('token');
		my $response = $ua->request(
			POST "$wikiurl/api.php" ,
			Content_Type => 'application/x-www-form-urlencoded' ,
			Content => [ %params ]
		);
#		print Data::Dumper->Dump([$response], [qw(response)]);
		$dom = XML::LibXML->load_xml(string => $response->{'_content'});
#		print $dom->toStringHTML();
		$node = $dom->findnodes("//login")->get_node(1);
		$loginResult = $node->getAttribute('result');
	}	

	if ($loginResult eq 'Success') {
		$loggedIn = 1;
		print "success\n";
	} 
	
	return $loggedIn;
}

# Upload via HTTP. Useful if you don't have Sysop privs and thus can't use the XML import
sub UploadToServer { # Params: title,content,comment
  my $pagetitle = shift;
  my $pagecontent = shift;
  my $comment = shift;
	my $response = $ua->request(GET "$serverindexurl?title=$pagetitle&action=edit");
	my @lines = split /\n/, $response->content();
	my $token = '';
	my $edittime = '';
	foreach (@lines) {
		if (/wpEditToken/) {
			s/type=.?hidden.? *value="(.+)" *name/$1/i;
			$token = $1;
		}
		if (/wpEdittime/) {
			s/type=.?hidden.? *value="(.+)" *name/$1/i;
			$edittime = $1 || '';
		}
	}
	my %params = ();
	$params{'wpTextbox1' } = $pagecontent;
	$params{'wpEdittime' } = $edittime;
	$params{'wpSave'     } = 'Save page';
	$params{'wpSection'  } = '';
	$params{'wpSummary'  } = $comment;
	$params{'wpEditToken'} = $token;
	$params{'title' }      = $pagetitle;
	$params{'action' }     = 'submit';
	$response = $ua->request(
		POST "$serverindexurl?title=${pagetitle}&action=submit" ,
		Content_Type => 'application/x-www-form-urlencoded' ,
		Content => [ %params ]
	);
	my $response_location = $response->{'_headers'}->{'location'} || '';
	if ($response_location =~ /[\/=]$pagetitle/i) {
		return 1; # Success
	}
	return 0; # Failure
}

sub printResults {
    my ($body) = @_;
    if ($body =~ m{<p>Importing pages...\n</p>}mgc) {
	my $end = substr($body, pos $body);
	if ($end !~ m{<hr />}mgc) { die "unknown upload reponse terminator: $end"; }
	my $meat = substr($end, 0, (pos $end) - 5);
	print $meat;
    } elsif ($body =~ m{<!-- start content -->}mgc) {
	my $end = substr($body, pos $body);
	if ($end !~ m{<!-- end content -->}mgc) { die "unknown upload reponse terminator: $end"; }
	my $meat = substr($end, 0, (pos $end) - 19);
	print $meat;
    } else {
	die "unknown upload reponse: $body";
    }
}

sub UploadAttachmentToServer { # Params: WikiURL,FilePath,MWName,Comment
  # Markup from Upload page (layout markup has been deleted)
  #	<form id='upload' method='post' enctype='multipart/form-data' action="/mediawiki/index.php/Special:Upload">
  #   <label for='wpUploadFile'>Source filename:</label>
  #		<input tabindex='1' type='file' name='wpUploadFile' id='wpUploadFile' onchange='fillDestFilename("wpUploadFile")' size='40' />
  #   <input type='hidden' name='wpSourceType' value='file' />
  #   <label for='wpDestFile'>Destination filename:</label>
  #   <input tabindex='2' type='text' name='wpDestFile' id='wpDestFile' size='40' value="" />
  #   <label for='wpUploadDescription'><p>Summary:</p></label>
  #   <textarea tabindex='3' name='wpUploadDescription' id='wpUploadDescription' rows='6' cols='80'></textarea>
  #   <input tabindex='7' type='checkbox' name='wpWatchthis' id='wpWatchthis'  value='true' />
  #   <label for='wpWatchthis'>Watch this page</label>
  #   <input tabindex='8' type='checkbox' name='wpIgnoreWarning' id='wpIgnoreWarning' value='true' />
  #   <label for='wpIgnoreWarning'>Ignore any warnings</label>
  #		<input tabindex='9' type='submit' name='wpUpload' value="Upload file" />
  #	</form>
	my $wikiurl  = shift;
	my $filepath = shift;
	my $mwname   = shift;
	my $comment  = shift;
	
	my $response = $ua->request(
		POST "$wikiurl/api.php",
		Content_Type => 'multipart/form-data',
		Content =>
			[
                 action        => 'query',
                 prop        => 'info',
                 intoken => 'edit',
                 titles     => 'Main Page',
                 format=>'xml'
			]
	);
	
#	print Data::Dumper->Dump([$response], [qw(response)]);

	my $dom = XML::LibXML->load_xml(string => $response->{'_content'});
#	print $dom->toStringHTML();
	my $node = $dom->findnodes("//page")->get_node(1);
	my $editToken = $node->getAttribute('edittoken');
#	print "EditToken: ";
#	print $editToken;
#	print "\n";

	$response = $ua->request(
		POST "$wikiurl/api.php",
		Content_Type => 'multipart/form-data',
		Content =>
			[
                 action        => 'upload',
                 token => $editToken,
                 format=>'xml',
                 filename=>$mwname,
                 comment=>$comment,
                 file        => [$filepath]
			]
	);
	
#	print Data::Dumper->Dump([$response], [qw(response)]);
#	print $response->{'_content'};
	$dom = XML::LibXML->load_xml(string => $response->{'_content'});
	my $node = $dom->findnodes("//upload")->get_node(1);
	if (($node) && ($node->getAttribute('result') eq 'Success'))
	{
		return 1;
	}
	
	return 0;
	
}

sub UploadXmlToServer { # Params: WikiURL,XmlFilePath
  #Markup from the MediaWiki Import page
  #<form enctype='multipart/form-data' method='post' action="/mediawiki/index.php?title=Special:Import&amp;action=submit">
  #		<input type='hidden' name='action' value='submit' />
  #		<input type='hidden' name='source' value='upload' />
  #		<input type='hidden' name='MAX_FILE_SIZE' value='2000000' />
  #		<input type='file' name='xmlimport' value='' size='30' />
  #		<input type='submit' value="Upload file" />
  #	</form>
	my $wikiurl  = shift;
	my $filepath = shift;
	my $mwname   = shift;
	
	my $response = $ua->request(
		POST "$wikiurl/api.php",
		Content_Type => 'multipart/form-data',
		Content =>
			[
                 action        => 'query',
                 prop        => 'info',
                 intoken => 'import',
                 titles     => 'Main Page',
                 format=>'xml'
			]
	);
	
#	print Data::Dumper->Dump([$response], [qw(response)]);

	my $dom = XML::LibXML->load_xml(string => $response->{'_content'});
#	print $dom->toStringHTML();
	my $node = $dom->findnodes("//page")->get_node(1);
	my $importToken = $node->getAttribute('importtoken');
	print "ImportToken: ";
	print $importToken;
	print "\n";
	
	$response = $ua->request(
		POST "$wikiurl/api.php",
		Content_Type => 'multipart/form-data',
		Content =>
			[
                 action        => 'import',
                 token => $importToken,
                 format=>'xml',
                 xml        => [$filepath]
			]
	);
	
#	print Data::Dumper->Dump([$response], [qw(response)]);
#	print $response->{'_content'};
	$dom = XML::LibXML->load_xml(string => $response->{'_content'});
	if ($dom->findnodes("//page")->size() > 0)
	{
		return 1;
	}
	
	return 0;
}

# Upload XML and attachments to server
sub Upload { # Params: MediaWikiURL
	if (defined $uploaded) { return; }
	my $mwurl = shift;
	if (!LogIn($mwurl)) { return; }
	opendir(ALLXMLDIR, $targetpath) || die "Cannot open target directory $targetpath";
	my @allXmlFiles = grep { /^allpages.*\.xml$/ && "$targetpath/$_" } readdir(ALLXMLDIR);
	closedir(ALLXMLDIR);
	my $xmlFile;
	foreach $xmlFile (@allXmlFiles) {
  	print "  Importing into MediaWiki: $xmlFile ... ";
  	if (UploadXmlToServer($mwurl,"$targetpath/$xmlFile")) {
    	print "Done.\n";
  	}
  	else {
    	print "Failed.\n\n  Further action aborted.\n";
    	return;
  	}
	}
	print "  =====\n  ALL PAGES APPEAR TO HAVE IMPORTED SUCCESSFULLY. Now uploading attachments...\n  =====\n";
	my $failCount = 0;
	foreach $attachment (keys %wikiAttachments) {
	    my $attachmentPath = "$targetpath/$wikiAttachments{$attachment}";
	    (my $originalURL = $attachment) =~ s/\$\$/\//g;
	    $originalURL =~ s/\$/?action=AttachFile&do=get&target=/;
	    $originalURL = "$moinmoinurlbase/$originalURL";
	    print "  Uploading $attachment ... ";
	    my $attempts = 0;
	    if ($TRACE_ATTACHMENTS) {
		print $TRACE_ATTACHMENTS "$originalURL    $attachment\n"; # guessing at path structure
	    }
	    while ($attempts < $maxAttempts) {
		$attempts++;
		if (UploadAttachmentToServer($mwurl,$attachmentPath,$attachment,"Original URL $originalURL")) {
		    print "Done.\n";
		    last;
		}
		else {
		    if ($attempts < $maxAttempts) {
			print 'Retrying... ';
		    }
		    else {
			print "FAILED\n";
			$failCount++;
		    }
		}
	    }
	}
	if ($failCount) {
	    print "  WARNING: $failCount upload" . ($failCount>1?'s':'') . " failed.\n";
	}
}

__END__

# Notes and useful references ============================================================
# Wiki page folder name is the name of the wiki page
# Filename may contain ...(xx)... embedded hex character.
#  Example: AideD(27)Administration = AideD'Administration
#  Example: AideAuxD(c3a9)veloppeurs = AideAuxDéveloppeurs
#  Example: AideDeL(27c389)dition(2f)SousPages = AideDeL(27)(c389)dition(2f)SousPages = AideDeL'Édition.SousPages
# The "." (2f) is a path delimiter for wiki subpages.
#  Example: AideDeL'Édition.SousPages = AideDeL'Édition/SousPages
#  Note: The MediaWiki equivalents will just have "/" in the name. They will not be true subpages.
# The "_" is used to represent a space in the wiki page name.
# Note how some hex codes are 2 hex digits, while others are 4 hex digits. How are these decoded?
# See: http://moinmoin.wikiwikiweb.de/PageNames
# See: http://moinmoin.wikiwikiweb.de/StorageRefactoring/PagesAsBundles
# See: http://moinmoin.wikiwikiweb.de/QuotingWikiNames
# See: http://en.wikipedia.org/wiki/Wikipedia:Subpages
# See: http://moinmoin.wikiwikiweb.de/MoinMoinVsMediaWiki   (helpful but discovered after most of the code was written!)
# See: http://en.wikipedia.org/wiki/Help:Export
# See: mhttp://cpan.uwinnipeg.ca/htdocs/libwww-perl/HTTP/Request/Common.html
# See: http://lwp.interglacial.com/ch05_07.htm    (Deals with file uploads)
