#!/usr/bin/perl
# scripts/02a_download_attachments.pl

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use File::Path qw(make_path);
use Time::HiRes qw(sleep time);

print "Attachment Downloader (from JSON)\n";
print "==================================\n\n";

my $json_file = '/app/data/all.json';
my $attachment_dir = '/app/data/attachments';
my $failed_log = '/app/output/failed_downloads.txt';

# Base URL
my $base_url = 'https://ec.europa.eu/info/law/better-regulation/api/download';

# Create directory
make_path($attachment_dir) unless -d $attachment_dir;

# HTTP client - slower, more patient
my $ua = LWP::UserAgent->new(
    timeout => 120,  # Longer timeout
    agent => 'Mozilla/5.0',
    ssl_opts => { verify_hostname => 0 }
);

# Read JSON
my $json = JSON->new->utf8;
open my $json_fh, '<', $json_file or die "Cannot open JSON: $!\n";
my $json_text = do { local $/; <$json_fh> };
close $json_fh;

my $data = $json->decode($json_text);
my $total_responses = scalar(@$data);
print "Parsed $total_responses responses\n";

# Collect downloads
my @downloads;
foreach my $response (@$data) {
    my $attachments = $response->{attachments} || [];
    next unless ref($attachments) eq 'ARRAY' && @$attachments > 0;
    
    foreach my $att (@$attachments) {
        my $filename = $att->{fileName} || next;
        my $doc_id = $att->{documentId} || next;
        
        push @downloads, {
            ec_id => $response->{id},
            filename => $filename,
            doc_id => $doc_id,
            url => "$base_url/$doc_id",
            path => "$attachment_dir/$filename"
        };
    }
}

my $total = scalar(@downloads);
print "Total attachments: $total\n";

# Check existing
my $existing = 0;
foreach my $dl (@downloads) {
    $existing++ if -f $dl->{path} && -s $dl->{path} > 100;
}
print "Already downloaded: $existing\n";
print "To download: " . ($total - $existing) . "\n\n";

if ($existing == $total) {
    print "All files already downloaded!\n";
    exit 0;
}

my $est_min = int(($total - $existing) * 0.5 / 60);
print "Estimated time: ~$est_min minutes (with 0.5s delay per file)\n\n";

my $downloaded = 0;
my $failed = 0;
my $skipped = 0;
my $start_time = time();
my @failed_list;

# Open failed log
open my $failed_fh, '>', $failed_log;

print "Starting downloads (progress every 5 files)...\n";
print "-" x 60 . "\n";

foreach my $dl (@downloads) {
    my $filename = $dl->{filename};
    my $url = $dl->{url};
    my $path = $dl->{path};
    
    # Skip if exists
    if (-f $path && -s $path > 100) {
        $skipped++;
        next;
    }
    
    # Try download with retry on 500
    my $attempts = 0;
    my $success = 0;
    
    while ($attempts < 3 && !$success) {
        $attempts++;
        
        my $response = $ua->get($url, ':content_file' => $path);
        
        if ($response->is_success && -f $path && -s $path > 100) {
            $downloaded++;
            $success = 1;
        } elsif ($response->code == 500 && $attempts < 3) {
            # Retry 500 errors
            sleep 2;  # Wait longer before retry
            next;
        } else {
            # Failed after retries
            last;
        }
    }
    
    unless ($success) {
        $failed++;
        unlink $path if -f $path;
        push @failed_list, { filename => $filename, url => $url };
        print $failed_fh "$filename\t$url\n";
    }
    
    # Progress every 5 files
    if (($downloaded + $failed) % 5 == 0 || $downloaded == 1) {
        my $elapsed = time() - $start_time;
        my $rate = ($downloaded + $failed) / $elapsed;
        my $remaining = $total - $downloaded - $skipped - $failed;
        my $eta = $remaining > 0 ? $remaining / $rate / 60 : 0;
        
        printf("Downloaded: %4d | Skipped: %4d | Failed: %4d | Total: %4d/%d (%.1f%%) | ETA: %.1f min\n",
            $downloaded, $skipped, $failed, 
            $downloaded + $skipped, $total,
            100 * ($downloaded + $skipped) / $total, $eta);
    }
    
    # Slower rate limit
    sleep 0.5;
}

close $failed_fh;

my $duration = sprintf("%.1f", (time() - $start_time) / 60);

print "\n";
print "=" x 60 . "\n";
print "DOWNLOAD COMPLETE\n";
print "=" x 60 . "\n";
print "Total: $total\n";
print "Downloaded: $downloaded\n";
print "Already existed: $skipped\n";
print "Failed: $failed\n";
print "Duration: $duration minutes\n";

if ($failed > 0) {
    print "\nFailed downloads logged to: $failed_log\n";
    print "You can retry these later.\n";
}

# Show file types
if ($downloaded + $skipped > 0) {
    print "\nFile types:\n";
    my %types;
    opendir(my $dh, $attachment_dir);
    while (my $file = readdir($dh)) {
        next if $file =~ /^\./;
        if ($file =~ /\.([^.]+)$/) {
            $types{lc($1)}++;
        }
    }
    closedir($dh);
    
    foreach my $ext (sort { $types{$b} <=> $types{$a} } keys %types) {
        printf("  %-10s %3d files\n", $ext, $types{$ext});
    }
}

print "\nNext: make extract\n";
