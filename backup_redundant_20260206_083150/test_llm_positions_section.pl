#!/usr/bin/perl
use strict;
use warnings;
use DBI;

=pod

=head1 NAME

test_llm_positions_section.pl - Preview LLM positions section output

=head1 USAGE

Test the LLM position report section before integrating into main report:

    docker exec documented-insights-perl \
        perl /app/scripts/test_llm_positions_section.pl taxation

Output written to: output/test_llm_positions_taxation.md

=cut

# Database configuration
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_password = $ENV{POSTGRES_PASSWORD} || 'changeme';

# Get domain from command line
my $domain = shift @ARGV or die "Usage: $0 <domain>\n";

# Valid domains
my %valid_domains = map { $_ => 1 } qw(taxation procurement sovereignty vendor-lock security);
die "Invalid domain: $domain\n" unless $valid_domains{$domain};

# Connect to database
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user,
    $db_password,
    { RaiseError => 1, AutoCommit => 1 }
) or die "Cannot connect to database: $DBI::errstr\n";

# Output file
my $output_file = "/app/output/test_llm_positions_${domain}.md";
open my $out, '>', $output_file or die "Cannot write to $output_file: $!\n";

# Load module
use lib '/app/lib';
require LLMPositionReport;

# Generate section
print "Generating LLM positions section for $domain...\n";

# Write header
print $out "# Test LLM Positions Section\n\n";
print $out "Domain: $domain\n\n";
print $out "---\n\n";

# Generate positions section
LLMPositionReport::generate_positions_section($dbh, $domain, $out);

close $out;

print "Output written to: $output_file\n";
print "\nTo view:\n";
print "  cat $output_file\n";
print "  # Or convert to HTML:\n";
print "  pandoc -f markdown -t html -s $output_file -o /app/output/test_llm_positions_${domain}.html\n";

$dbh->disconnect;
