#!/usr/bin/perl
# scripts/08_query_domain.pl
# Query database for domain-specific analysis

use strict;
use warnings;
use utf8;
use DBI;
use FindBin;
use lib "$FindBin::Bin/../lib";
use DomainConfig;
use DomainQuery;

binmode STDOUT, ':utf8';

print "Domain Analysis Query\n";
print "=" x 60 . "\n\n";

# Configuration
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

# Get domain name from command line
my $domain_name = $ARGV[0];

unless ($domain_name) {
    print "Usage: $0 <domain-name>\n\n";
    print "Example: $0 taxation\n\n";
    exit 1;
}

# Load domain configuration
my $config_file = "$FindBin::Bin/../domains/${domain_name}.conf";
my $config = DomainConfig::parse_config($config_file);

unless ($config) {
    die "Failed to load domain configuration: $config_file\n";
}

print "Domain: " . $config->{domain}{name} . "\n";
print "Description: " . $config->{domain}{description} . "\n\n";

# Connect to database
print "Connecting to database...\n";
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user, $db_pass,
    { AutoCommit => 1, RaiseError => 1, pg_enable_utf8 => 1 }
) or die "Cannot connect: $DBI::errstr\n";

print "Connected.\n\n";

# Get coverage statistics
print "=" x 60 . "\n";
print "COVERAGE STATISTICS\n";
print "=" x 60 . "\n\n";

my $stats = DomainQuery::get_coverage_stats($dbh, $config);

if (%$stats) {
    printf "Matching responses:     %s\n", format_number($stats->{matching_responses});
    printf "Coverage of corpus:     %.1f%%\n", $stats->{pct_of_corpus};
    printf "Countries represented:  %s\n", $stats->{countries};
    printf "Stakeholder types:      %s\n", $stats->{stakeholder_types};
    printf "Organizations:          %s\n", $stats->{organizations};
    printf "With attachments:       %s\n", format_number($stats->{with_attachments});
    print "\n";
}
else {
    print "No matching responses found.\n\n";
    exit 0;
}

# Stakeholder breakdown
print "=" x 60 . "\n";
print "STAKEHOLDER BREAKDOWN\n";
print "=" x 60 . "\n\n";

my $stakeholders = DomainQuery::get_stakeholder_breakdown($dbh, $config);

if (@$stakeholders) {
    printf "%-30s %8s %8s %10s\n", "Stakeholder Type", "Responses", "Countries", "Percentage";
    print "-" x 60 . "\n";
    
    foreach my $row (@$stakeholders) {
        printf "%-30s %8s %8s %9.1f%%\n",
            $row->{user_type},
            format_number($row->{count}),
            $row->{countries},
            $row->{percentage};
    }
    print "\n";
}

# Geographic breakdown
print "=" x 60 . "\n";
print "GEOGRAPHIC BREAKDOWN (Top 15)\n";
print "=" x 60 . "\n\n";

my $countries = DomainQuery::get_geographic_breakdown($dbh, $config);

if (@$countries) {
    printf "%-30s %8s %10s\n", "Country", "Responses", "Percentage";
    print "-" x 60 . "\n";
    
    my $count = 0;
    foreach my $row (@$countries) {
        last if ++$count > 15;
        
        printf "%-30s %8s %9.1f%%\n",
            $row->{country},
            format_number($row->{count}),
            $row->{percentage};
    }
    print "\n";
}

# Word co-occurrence
print "=" x 60 . "\n";
print "WORD CO-OCCURRENCE (Top 20)\n";
print "=" x 60 . "\n\n";

my $cooccur = DomainQuery::get_domain_cooccurrence($dbh, $config, 20);

if (@$cooccur) {
    printf "%-25s %12s %10s %8s\n", "Word", "Occurrences", "Documents", "Doc %";
    print "-" x 60 . "\n";
    
    foreach my $row (@$cooccur) {
        printf "%-25s %12s %10s %7.1f%%\n",
            $row->{word},
            format_number($row->{occurrences}),
            format_number($row->{documents}),
            $row->{doc_pct};
    }
    print "\n";
}

# Sub-theme breakdown
if (DomainConfig::has_sub_themes($config)) {
    print "=" x 60 . "\n";
    print "SUB-THEME BREAKDOWN\n";
    print "=" x 60 . "\n\n";
    
    my $sub_theme_stats = DomainQuery::get_sub_theme_breakdown($dbh, $config);
    
    if (%$sub_theme_stats) {
        my $total = $stats->{matching_responses};
        
        printf "%-30s %10s %12s\n", "Sub-theme", "Responses", "Percentage";
        print "-" x 60 . "\n";
        
        foreach my $theme (sort { $sub_theme_stats->{$b} <=> $sub_theme_stats->{$a} } 
                          keys %$sub_theme_stats) {
            my $count = $sub_theme_stats->{$theme};
            my $pct = $total > 0 ? 100.0 * $count / $total : 0;
            
            printf "%-30s %10s %11.1f%%\n",
                $theme,
                format_number($count),
                $pct;
        }
        print "\n";
        
        print "Note: Responses may appear in multiple sub-themes\n\n";
    }
}

# Term usage patterns
print "=" x 60 . "\n";
print "TERM USAGE ANALYSIS\n";
print "=" x 60 . "\n\n";

my $usage = DomainQuery::get_term_usage_patterns($dbh, $config);

if (%$usage) {
    foreach my $pattern (sort { $usage->{$b}{strength} <=> $usage->{$a}{strength} } keys %$usage) {
        my $data = $usage->{$pattern};
        
        printf "%s (strength: %.1f)\n", $pattern, $data->{strength};
        
        if ($data->{positive_context}) {
            print "  Positive framing: $data->{positive_context}\n";
        }
        
        if ($data->{negative_context}) {
            print "  Negative framing: $data->{negative_context}\n";
        }
        
        if ($data->{usage_note}) {
            print "  Usage: $data->{usage_note}\n";
        }
        
        print "\n";
    }
}

# Sentiment analysis
print "=" x 60 . "\n";
print "SENTIMENT PATTERNS\n";
print "=" x 60 . "\n\n";

my $sentiment = DomainQuery::get_domain_sentiment($dbh, $config);

if (%$sentiment) {
    printf "Action-oriented language:  %.1f%% (propose, should, must, require)\n", 
        $sentiment->{action_oriented} || 0;
    printf "Problem-focused language:  %.1f%% (barrier, problem, lack, fail)\n",
        $sentiment->{problem_focused} || 0;
    printf "Solution-focused language: %.1f%% (solution, opportunity, benefit)\n",
        $sentiment->{solution_focused} || 0;
    
    print "\n";
    
    if ($sentiment->{dominant_tone}) {
        print "Dominant tone: $sentiment->{dominant_tone}\n";
    }
    
    if ($sentiment->{advocacy_level}) {
        print "Advocacy level: $sentiment->{advocacy_level}\n";
    }
    
    print "\n";
}

$dbh->disconnect;

print "=" x 60 . "\n";
print "ANALYSIS COMPLETE\n";
print "=" x 60 . "\n";
print "Domain: " . $config->{domain}{name} . "\n";
print "Responses analysed: " . format_number($stats->{matching_responses}) . "\n";
print "Coverage: $stats->{pct_of_corpus}% of corpus\n";

sub format_number {
    my $num = shift;
    return '' unless defined $num;
    
    # Add thousand separators
    my $formatted = reverse $num;
    $formatted =~ s/(\d{3})(?=\d)/$1,/g;
    return scalar reverse $formatted;
}
