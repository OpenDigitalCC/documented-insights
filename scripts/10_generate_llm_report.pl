#!/usr/bin/env perl
#
# 10_generate_llm_report.pl
# Generate LLM position analysis report for a domain
#
# Usage: perl scripts/10_generate_llm_report.pl <domain>

use strict;
use warnings;
use DBI;
use lib './lib';
use LLMPositionReport;

my $domain = $ARGV[0] or die "Usage: $0 <domain>\n";

# Database credentials
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

# Connect to database
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user, $db_pass,
    { RaiseError => 1, AutoCommit => 1 }
) or die "Cannot connect: $DBI::errstr";

# Output file
my $output_file = "output/domain_${domain}_analysis_llm.md";

print "Generating LLM Position Report\n";
print "=" x 50, "\n";
print "Domain: $domain\n";
print "Output: $output_file\n";
print "\n";

# Check if LLM data exists
my $llm_count = $dbh->selectrow_array(
    "SELECT COUNT(*) FROM position_analysis WHERE domain = ?",
    undef, $domain
);

if ($llm_count == 0) {
    print "No LLM position data available for this domain.\n";
    print "Run: make llm-extract DOMAIN=$domain\n";
    
    # Create placeholder file
    open(my $out, '>', $output_file) or die "Cannot write: $!";
    print $out "# LLM Position Analysis - " . ucfirst($domain) . "\n\n";
    print $out "No position data available yet.\n\n";
    print $out "LLM extraction not yet run for this domain.\n\n";
    print $out "Run: `make llm-extract DOMAIN=$domain`\n";
    close $out;
    
    $dbh->disconnect();
    exit 0;
}

# Open output file
open(my $out, '>', $output_file) or die "Cannot write to $output_file: $!";

# Generate report header
print $out "# LLM Position Analysis - " . ucfirst($domain) . "\n\n";
print $out "Generated: " . scalar(localtime) . "\n\n";

# Generate LLM positions section
LLMPositionReport::generate_positions_section($dbh, $domain, $out);

# Close file
close $out;

# Disconnect
$dbh->disconnect();

print "Report generated: $output_file\n";
print "\n";
