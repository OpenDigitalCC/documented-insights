#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use File::Path qw(make_path);
use Time::HiRes qw(sleep);

print "Re-download Corrupt Files\n";
print "==========================\n\n";

my $json_file = '/app/data/all.json';
my $attachment_dir = '/app/data/attachments';
my $base_url = 'https://ec.europa.eu/info/law/better-regulation/api/download';

# Read JSON
my $json = JSON->new->utf8;
open my $fh, '<', $json_file;
my $data = $json->decode(do { local $/; <$fh> });
close $fh;

# Build filename -> documentId mapping
my %file_to_doc;
foreach my $resp (@$data) {
    my $atts = $resp->{attachments} || [];
    foreach my $att (@$atts) {
        my $fn = $att->{fileName} || next;
        my $doc_id = $att->{documentId} || next;
        $file_to_doc{$fn} = $doc_id;
    }
}

# Test which files are corrupt
my @corrupt;

print "Testing files for corruption...\n";

my @test_files = (
    'OpenSource.docx',
    'EU Commission Call for Evidence.docx',
    'ERMsubmission.docx',
    'Icecat_Response_EU_Open_Source_Call_for_Evidence 08012026.docx',
    'reponse-detaillee-en-francais_dinum.docx',
    'Stellungnahme zur Initiative »Auf dem Weg zu europäischen offenen digitalen Ökosystemen«.docx',
    'Sources.odt',
    'DTD_short_description.odt',
    'ARES69111-BOUDICA.odt',
    'OmnisCloud-ResponsToCallForEvidence-EODESt.odt',
    'eu_open_digital_ecosystems_feedback_LWsystems.odt',
    'Stellungnahme zur OpenSource-Strategie der EU.odt',
    '20260111-Antwort-EU Feedback OSS-ENG.odt',
    'EU_Open_Digital_Ecosystem_20260203.odt',
    '2026-02-02 Stellungnahme EU Open Digital Ecosystems Dataport.odt'
);

foreach my $file (@test_files) {
    my $path = "$attachment_dir/$file";
    next unless -f $path;
    
    my $ext = $file =~ /\.([^.]+)$/ ? lc($1) : '';
    
    my $test;
    if ($ext eq 'docx') {
        $test = `pandoc -f docx -t plain "$path" 2>&1`;
        if ($test =~ /couldn't unpack|error/i) {
            push @corrupt, $file;
            print "  CORRUPT: $file\n";
        }
    } elsif ($ext eq 'odt') {
        $test = `pandoc -f odt -t plain "$path" 2>&1`;
        if ($test =~ /error|failed/i || length($test) < 50) {
            push @corrupt, $file;
            print "  CORRUPT: $file\n";
        }
    }
}

my $total = scalar(@corrupt);
print "\nFound $total corrupt files to re-download\n\n";

if ($total == 0) {
    print "No corrupt files found!\n";
    exit 0;
}

# Re-download corrupt files
my $ua = LWP::UserAgent->new(
    timeout => 120,
    agent => 'Mozilla/5.0',
    ssl_opts => { verify_hostname => 0 }
);

my $success = 0;
my $failed = 0;

print "Re-downloading...\n";
print "-" x 60 . "\n";

foreach my $file (@corrupt) {
    my $doc_id = $file_to_doc{$file};
    unless ($doc_id) {
        warn "No document ID for: $file\n";
        $failed++;
        next;
    }
    
    my $url = "$base_url/$doc_id";
    my $path = "$attachment_dir/$file";
    
    # Delete corrupt file
    unlink $path;
    
    print "Downloading: $file\n";
    
    # Try download with retries
    my $attempts = 0;
    my $downloaded = 0;
    
    while ($attempts < 3 && !$downloaded) {
        $attempts++;
        
        my $response = $ua->get($url, ':content_file' => $path);
        
        if ($response->is_success && -f $path && -s $path > 1000) {
            # Verify it's not corrupt
            my $ext = $file =~ /\.([^.]+)$/ ? lc($1) : '';
            my $test;
            
            if ($ext eq 'docx') {
                $test = `pandoc -f docx -t plain "$path" 2>&1`;
                if ($test !~ /couldn't unpack|error/i && length($test) > 50) {
                    $downloaded = 1;
                }
            } elsif ($ext eq 'odt') {
                $test = `pandoc -f odt -t plain "$path" 2>&1`;
                if ($test !~ /error|failed/i && length($test) > 50) {
                    $downloaded = 1;
                }
            }
            
            if ($downloaded) {
                $success++;
                print "  SUCCESS - " . (-s $path) . " bytes\n";
            } else {
                unlink $path;
                sleep 2;
            }
        } elsif ($attempts < 3) {
            sleep 2;
        }
    }
    
    unless ($downloaded) {
        $failed++;
        print "  FAILED after $attempts attempts\n";
    }
    
    sleep 0.5;
}

print "\n";
print "=" x 60 . "\n";
print "RE-DOWNLOAD COMPLETE\n";
print "=" x 60 . "\n";
print "Successfully re-downloaded: $success\n";
print "Still failed: $failed\n";

if ($success > 0) {
    print "\nRun 'make extract' again to extract the fixed files\n";
}
