#!/usr/bin/perl
# scripts/02_extract_attachments.pl

use strict;
use warnings;
use DBI;
use JSON;
use File::Path qw(make_path);
use File::Basename;

print "Attachment Text Extractor\n";
print "=========================\n\n";

# Configuration
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

my $json_file = '/app/data/all.json';
my $attachment_dir = '/app/data/attachments';
my $output_dir = '/app/output/extracted_text';

# Create output directory
make_path($output_dir) unless -d $output_dir;

# Check extraction tools
print "Checking extraction tools...\n";
my $has_pdftotext = system('which pdftotext > /dev/null 2>&1') == 0;
my $has_pandoc = system('which pandoc > /dev/null 2>&1') == 0;

print "  pdftotext: " . ($has_pdftotext ? "✓" : "✗") . "\n";
print "  pandoc: " . ($has_pandoc ? "✓" : "✗") . "\n\n";

unless ($has_pdftotext || $has_pandoc) {
    die "ERROR: No extraction tools found.\n";
}

# Connect to database
print "Connecting to database...\n";
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user,
    $db_pass,
    { AutoCommit => 0, RaiseError => 1, PrintError => 0, pg_enable_utf8 => 1 }
) or die "Cannot connect: $DBI::errstr\n";

print "Connected.\n\n";

# Check directories
unless (-d $attachment_dir) {
    die "ERROR: Attachment directory not found: $attachment_dir\n";
}

# Count files
my $file_count = 0;
opendir(my $dh, $attachment_dir);
while (readdir($dh)) {
    next if /^\./;
    $file_count++;
}
closedir($dh);

print "Files in attachment directory: $file_count\n\n";

if ($file_count == 0) {
    print "No attachments found.\n";
    exit 0;
}

# Read JSON
print "Loading JSON...\n";
my $json = JSON->new->utf8;
open my $json_fh, '<', $json_file or die "Cannot open JSON: $!\n";
my $json_text = do { local $/; <$json_fh> };
close $json_fh;

my $data = $json->decode($json_text);
print "Parsed " . scalar(@$data) . " responses\n\n";

# Prepare database update
my $update_sth = $dbh->prepare(q{
    UPDATE responses 
    SET attachment_path = ?,
        full_text = COALESCE(feedback, '') || E'\n\n=== ATTACHMENT ===\n\n' || ?
    WHERE ec_id = ?
});

print "Processing attachments...\n\n";

my $total = 0;
my $extracted = 0;
my $failed = 0;
my $no_file = 0;

foreach my $response (@$data) {
    my $ec_id = $response->{id};
    my $attachments = $response->{attachments} || [];
    
    next unless ref($attachments) eq 'ARRAY' && @$attachments > 0;
    
    foreach my $att (@$attachments) {
        my $filename = $att->{fileName} || next;
        my $file_path = "$attachment_dir/$filename";
        
        $total++;
        
        unless (-f $file_path) {
            $no_file++;
            next;
        }
        
        my $text = extract_text($file_path, $has_pdftotext, $has_pandoc);
        
        if ($text && length($text) > 100) {
            eval {
                $update_sth->execute($filename, $text, $ec_id);
                $dbh->commit;
                $extracted++;
                
                # Save extracted text
                my $safe_name = $filename;
                $safe_name =~ s/[^a-zA-Z0-9._-]/_/g;
                my $txt_file = "$output_dir/${safe_name}.txt";
                open my $txt_fh, '>:encoding(UTF-8)', $txt_file;
                print $txt_fh $text;
                close $txt_fh;
            };
            
            if ($@) {
                warn "Database error for EC ID $ec_id: $@\n";
                $failed++;
            }
        } else {
            $failed++;
        }
        
        if ($extracted % 50 == 0 && $extracted > 0) {
            printf("Extracted: %d | Failed: %d | Missing: %d | Total: %d\n",
                $extracted, $failed, $no_file, $total);
        }
    }
}

$dbh->disconnect;

print "\n";
print "=" x 60 . "\n";
print "EXTRACTION COMPLETE\n";
print "=" x 60 . "\n";
print "Total attachments processed: $total\n";
print "Successfully extracted: $extracted\n";
print "Failed extraction: $failed\n";
print "Files not found: $no_file\n";

if ($extracted > 0) {
    print "\nExtracted text saved to: $output_dir\n";
    print "\nNext: make index\n";
}

sub extract_text {
    my ($file, $has_pdf, $has_pandoc) = @_;
    
    my $ext = lc((fileparse($file, qr/\.[^.]*/))[2]);
    $ext =~ s/^\.//;
    
    my $text = '';
    
    if ($ext eq 'pdf' && $has_pdf) {
        $text = `pdftotext -enc UTF-8 -layout "$file" - 2>/dev/null`;
    }
    elsif ($ext eq 'txt') {
        # Read text files directly
        open my $fh, '<:encoding(UTF-8)', $file;
        $text = do { local $/; <$fh> };
        close $fh;
    }
    elsif (($ext eq 'docx' || $ext eq 'odt' || $ext eq 'doc' || $ext eq 'rtf') && $has_pandoc) {
        $text = `pandoc -f $ext -t plain "$file" 2>/dev/null`;
    }
    else {
        return undef;
    }
    
    # Clean text
    $text =~ s/\r\n/\n/g;
    $text =~ s/\r/\n/g;
    $text =~ s/\n{3,}/\n\n/g;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    
    return $text;
}
