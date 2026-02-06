#!/usr/bin/env perl
#
# scripts/12_llm_processing_summary.pl
# Simple summary of LLM processing status by domain

use strict;
use warnings;
use DBI;

# Database credentials from environment
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user, $db_pass,
    { RaiseError => 1, AutoCommit => 1 }
) or die "Cannot connect: $DBI::errstr";

# Get processing status from view
my $sth = $dbh->prepare(q{
    SELECT 
        domain,
        responses_with_positions,
        total_positions,
        distinct_categories,
        support_count,
        oppose_count,
        neutral_count,
        mixed_count
    FROM position_extraction_progress
    ORDER BY 
        CASE domain
            WHEN 'taxation' THEN 1
            WHEN 'procurement' THEN 2
            WHEN 'sovereignty' THEN 3
            WHEN 'vendor-lock' THEN 4
            WHEN 'security' THEN 5
        END
});

$sth->execute();

print "\n";
print "=" x 70, "\n";
print "LLM Processing Summary by Domain\n";
print "=" x 70, "\n\n";

my $any_data = 0;
my %seen_domains;

while (my $row = $sth->fetchrow_hashref()) {
    my $domain = $row->{domain};
    $seen_domains{$domain} = 1;
    
    my $processed = $row->{responses_with_positions} || 0;
    
    printf "%-15s %4d responses processed ", 
        ucfirst($domain), $processed;
    
    if ($processed > 0) {
        $any_data = 1;
        printf "| %3d positions | %2d categories | S:%d O:%d N:%d M:%d\n",
            $row->{total_positions},
            $row->{distinct_categories},
            $row->{support_count},
            $row->{oppose_count},
            $row->{neutral_count},
            $row->{mixed_count};
    } else {
        print "| No data yet\n";
    }
}

# Show domains not started yet
my @all_domains = qw(taxation procurement sovereignty vendor-lock security);
for my $domain (@all_domains) {
    next if $seen_domains{$domain};
    printf "%-15s %4d responses processed | No data yet\n",
        ucfirst($domain), 0;
}

print "\n";
print "Legend: S=Support, O=Oppose, N=Neutral, M=Mixed\n";
print "\n";

if (!$any_data) {
    print "No LLM extractions completed yet.\n";
    print "Run: make llm-extract DOMAIN=taxation\n";
    print "\n";
} else {
    print "Current extraction:\n";
    print "  make llm-status      - overall progress\n";
    print "  make llm-progress    - detailed by domain\n";
    print "\n";
    print "Generate reports:\n";
    print "  make report DOMAIN=taxation - pattern analysis report\n";
    print "\n";
}

$dbh->disconnect();
