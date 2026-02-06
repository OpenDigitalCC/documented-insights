#!/usr/bin/perl
# scripts/01_load_json.pl

use strict;
use warnings;
use DBI;
use JSON;
use utf8;

print "JSON Data Loader\n";
print "================\n\n";

# Configuration
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

my $json_file = '/app/data/all.json';

# Check file exists
unless (-f $json_file) {
    die "ERROR: JSON file not found: $json_file\n";
}

my $size_mb = sprintf("%.1f", (-s $json_file) / 1024 / 1024);
print "JSON file: $json_file\n";
print "File size: ${size_mb} MB\n\n";

# Connect to database
print "Connecting to database...\n";
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user,
    $db_pass,
    { AutoCommit => 0, RaiseError => 1, PrintError => 0, pg_enable_utf8 => 1 }
) or die "Cannot connect: $DBI::errstr\n";

print "Connected.\n\n";

# Clear existing data
print "Clearing existing data...\n";
$dbh->do("TRUNCATE responses CASCADE");
$dbh->commit;

# Read and parse JSON
print "Loading and parsing JSON...\n";
my $json = JSON->new->utf8;  # Handle UTF-8 properly

open my $json_fh, '<', $json_file or die "Cannot open JSON: $!\n";
my $json_text = do { local $/; <$json_fh> };
close $json_fh;

my $data;
eval {
    $data = $json->decode($json_text);
};
if ($@) {
    die "JSON parsing error: $@\n";
}

my $total = scalar(@$data);
print "Parsed $total responses\n\n";

# Prepare insert
my $insert_sth = $dbh->prepare(q{
    INSERT INTO responses (
        ec_id, country, organization, user_type, feedback, 
        language, date_feedback, full_text, has_attachment
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
});

print "Loading into database...\n";
my $loaded = 0;
my $skipped = 0;

foreach my $response (@$data) {
    my $ec_id = $response->{id};
    my $country = $response->{country} || '';
    my $organization = $response->{organization} || '';
    my $user_type = $response->{userType} || '';
    my $feedback = $response->{feedback} || '';
    my $language = $response->{language} || '';
    my $date_str = $response->{dateFeedback} || '';
    
    # Parse date: "2026/02/03 23:59:55" -> "2026-02-03"
    my $date_feedback = undef;
    if ($date_str =~ m{^(\d{4})/(\d{2})/(\d{2})}) {
        $date_feedback = "$1-$2-$3";
    }
    
    # Check for attachments
    my $has_attachment = 0;
    my $attachments = $response->{attachments} || [];
    if (ref($attachments) eq 'ARRAY' && @$attachments > 0) {
        $has_attachment = 1;
    }
    
    # Use feedback as initial full_text
    my $full_text = $feedback;
    
    eval {
        $insert_sth->execute(
            $ec_id,
            $country,
            $organization,
            $user_type,
            $feedback,
            $language,
            $date_feedback,
            $full_text,
            $has_attachment
        );
    };
    
    if ($@) {
        warn "Error loading EC ID $ec_id: $@\n";
        $skipped++;
        next;
    }
    
    $loaded++;
    
    if ($loaded % 100 == 0) {
        $dbh->commit;
        printf("Loaded: %d/%d (%.1f%%)\n", $loaded, $total, 100 * $loaded / $total);
    }
}

$dbh->commit;

# Final stats
my $in_db = $dbh->selectrow_array("SELECT COUNT(*) FROM responses");

print "\n";
print "=" x 60 . "\n";
print "LOAD COMPLETE\n";
print "=" x 60 . "\n";
print "Total in JSON: $total\n";
print "Successfully loaded: $loaded\n";
print "Skipped: $skipped\n";
print "Total in database: $in_db\n";

# Stats
print "\n";
print "Statistics:\n";
print "-" x 60 . "\n";

my $with_feedback = $dbh->selectrow_array(
    "SELECT COUNT(*) FROM responses WHERE feedback IS NOT NULL AND feedback != ''"
);
print "Responses with feedback: $with_feedback\n";

my $with_attachments = $dbh->selectrow_array(
    "SELECT COUNT(*) FROM responses WHERE has_attachment = true"
);
print "Responses with attachments: $with_attachments\n";

my $by_country = $dbh->selectall_arrayref(
    "SELECT country, COUNT(*) as c FROM responses 
     WHERE country IS NOT NULL AND country != '' 
     GROUP BY country ORDER BY c DESC LIMIT 5"
);
if (@$by_country) {
    print "\nTop 5 countries:\n";
    foreach my $row (@$by_country) {
        printf("  %-10s %d\n", $row->[0], $row->[1]);
    }
}

my $by_type = $dbh->selectall_arrayref(
    "SELECT user_type, COUNT(*) as c FROM responses 
     WHERE user_type IS NOT NULL AND user_type != '' 
     GROUP BY user_type ORDER BY c DESC LIMIT 5"
);
if (@$by_type) {
    print "\nTop 5 user types:\n";
    foreach my $row (@$by_type) {
        printf("  %-20s %d\n", $row->[0], $row->[1]);
    }
}

$dbh->disconnect;

print "\nNext: make download-attachments\n";
