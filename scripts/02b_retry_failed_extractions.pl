#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use JSON;
use File::Basename;

print "Retry Failed Extractions\n";
print "========================\n\n";

my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

my $attachment_dir = '/app/data/attachments';
my $output_dir = '/app/output/extracted_text';

# Connect to database
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user, $db_pass,
    { AutoCommit => 0, RaiseError => 1, pg_enable_utf8 => 1 }
);

my $update_sth = $dbh->prepare(q{
    UPDATE responses 
    SET attachment_path = ?,
        full_text = COALESCE(feedback, '') || E'\n\n=== ATTACHMENT ===\n\n' || ?
    WHERE ec_id = ?
});

# Read JSON to get mappings
my $json = JSON->new->utf8;
open my $fh, '<', '/app/data/all.json';
my $data = $json->decode(do { local $/; <$fh> });
close $fh;

# Build filename -> ec_id mapping
my %file_to_id;
foreach my $resp (@$data) {
    my $atts = $resp->{attachments} || [];
    foreach my $att (@$atts) {
        my $fn = $att->{fileName} || next;
        $file_to_id{$fn} = $resp->{id};
    }
}

# Get list of failed files
opendir(my $dh, $attachment_dir);
my @all_files = grep { !/^\./ } readdir($dh);
closedir($dh);

my @failed;
foreach my $file (@all_files) {
    my $safe = $file;
    $safe =~ s/[^a-zA-Z0-9._-]/_/g;
    push @failed, $file unless -f "$output_dir/${safe}.txt";
}

print "Failed files to retry: " . scalar(@failed) . "\n\n";

my $extracted = 0;
my $still_failed = 0;

foreach my $file (@failed) {
    my $path = "$attachment_dir/$file";
    my $ext = lc((fileparse($file, qr/\.[^.]*/))[2]);
    $ext =~ s/^\.//;
    
    print "Trying: $file ($ext)...\n";
    
    my $text;
    
    # Try with longer timeout and more memory
    if ($ext eq 'pdf') {
        $text = `timeout 60 pdftotext -enc UTF-8 "$path" - 2>/dev/null`;
    } elsif ($ext eq 'docx' || $ext eq 'odt' || $ext eq 'doc') {
        $text = `timeout 60 pandoc -f $ext -t plain "$path" 2>/dev/null`;
    }
    
    # Clean and check
    if ($text) {
        $text =~ s/\r\n/\n/g;
        $text =~ s/\r/\n/g;
        $text =~ s/\n{3,}/\n\n/g;
        $text =~ s/^\s+//;
        $text =~ s/\s+$//;
    }
    
    if ($text && length($text) > 100) {
        my $ec_id = $file_to_id{$file};
        
        if ($ec_id) {
            eval {
                $update_sth->execute($file, $text, $ec_id);
                $dbh->commit;
            };
            
            unless ($@) {
                my $safe = $file;
                $safe =~ s/[^a-zA-Z0-9._-]/_/g;
                open my $out, '>:utf8', "$output_dir/${safe}.txt";
                print $out $text;
                close $out;
                
                $extracted++;
                print "  SUCCESS - extracted " . length($text) . " chars\n";
                next;
            }
        }
    }
    
    $still_failed++;
    print "  FAILED\n";
}

$dbh->disconnect;

print "\n";
print "=" x 60 . "\n";
print "RETRY COMPLETE\n";
print "=" x 60 . "\n";
print "Successfully extracted: $extracted\n";
print "Still failed: $still_failed\n";
