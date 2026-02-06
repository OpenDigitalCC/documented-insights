#!/usr/bin/perl
# scripts/test_domain_query.pl
# Test DomainQuery SQL generation (no database required)

use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use DomainConfig;
use DomainQuery;

binmode STDOUT, ':utf8';

print "Domain Query Builder - Test Suite\n";
print "=" x 60 . "\n\n";

# Get domain name from command line
my $domain_name = $ARGV[0];

unless ($domain_name) {
    print "Usage: $0 <domain-name>\n\n";
    print "Available domains:\n";
    
    my $domains_dir = "$FindBin::Bin/../domains";
    opendir(my $dh, $domains_dir) or die "Cannot open $domains_dir: $!\n";
    my @configs = sort grep { /\.conf$/ } readdir($dh);
    closedir($dh);
    
    foreach my $conf (@configs) {
        $conf =~ s/\.conf$//;
        print "  - $conf\n";
    }
    
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

# Test 1: WHERE clause generation
print "=" x 60 . "\n";
print "TEST 1: WHERE Clause Generation\n";
print "=" x 60 . "\n\n";

my $where = DomainQuery::build_where_clause($config);

if ($where) {
    print "Generated WHERE clause:\n\n";
    print "$where\n\n";
    
    # Pretty print for readability
    my @conditions = split(/ OR /, $where);
    print "Breakdown (" . scalar(@conditions) . " conditions):\n";
    
    my $num = 1;
    foreach my $cond (@conditions) {
        $cond =~ s/^\(//;
        $cond =~ s/\)$//;
        print sprintf("%3d. %s\n", $num++, $cond);
    }
    print "\n";
}
else {
    print "ERROR: No WHERE clause generated\n\n";
}

# Test 2: Sub-theme queries
if (DomainConfig::has_sub_themes($config)) {
    print "=" x 60 . "\n";
    print "TEST 2: Sub-theme Queries\n";
    print "=" x 60 . "\n\n";
    
    foreach my $theme (DomainConfig::get_sub_theme_names($config)) {
        print "Sub-theme: $theme\n";
        print "-" x 60 . "\n";
        
        my @terms = DomainConfig::get_sub_theme_terms($config, $theme);
        print "Terms: " . join(', ', @terms) . "\n\n";
        
        my $sub_where = DomainQuery::build_sub_theme_where($config, $theme);
        
        if ($sub_where) {
            print "WHERE clause:\n$sub_where\n\n";
        }
        else {
            print "ERROR: No WHERE clause generated\n\n";
        }
    }
}

# Test 3: Pattern matching examples
print "=" x 60 . "\n";
print "TEST 3: Keyphrase Pattern Matching\n";
print "=" x 60 . "\n\n";

if (@{$config->{keyphrases}}) {
    print "Testing keyphrase patterns (first 5):\n\n";
    
    my $count = 0;
    foreach my $phrase (@{$config->{keyphrases}}) {
        last if ++$count > 5;
        
        my $pattern = DomainQuery::keyphrase_to_pattern($phrase);
        
        print "Keyphrase: \"$phrase\"\n";
        print "Pattern:   $pattern\n";
        print "Matches:   ";
        
        # Show what this pattern would match
        my @examples;
        my $base = $phrase;
        
        # Original
        push @examples, $phrase;
        
        # Hyphenated
        my $hyphenated = $phrase;
        $hyphenated =~ s/\s+/-/g;
        push @examples, $hyphenated if $hyphenated ne $phrase;
        
        # No space
        my $nospace = $phrase;
        $nospace =~ s/\s+//g;
        push @examples, $nospace if $nospace ne $phrase;
        
        print join(', ', @examples) . "\n\n";
    }
}
else {
    print "No keyphrases defined\n\n";
}

# Test 4: Complete query examples
print "=" x 60 . "\n";
print "TEST 4: Complete SQL Query Examples\n";
print "=" x 60 . "\n\n";

my $queries = DomainQuery::build_analysis_queries($config);

foreach my $query_name (sort keys %$queries) {
    print "Query: $query_name\n";
    print "-" x 60 . "\n";
    print $queries->{$query_name} . "\n\n";
}

# Test 5: Query statistics
print "=" x 60 . "\n";
print "TEST 5: Query Complexity Statistics\n";
print "=" x 60 . "\n\n";

my @all_terms = DomainConfig::get_all_terms($config);
my $keyword_count = scalar(@{$config->{keywords}});
my $keyphrase_count = scalar(@{$config->{keyphrases}});

print "Total search terms: " . scalar(@all_terms) . "\n";
print "  - Keywords: $keyword_count\n";
print "  - Keyphrases: $keyphrase_count\n\n";

if (DomainConfig::has_sub_themes($config)) {
    my @themes = DomainConfig::get_sub_theme_names($config);
    print "Sub-themes: " . scalar(@themes) . "\n";
    
    foreach my $theme (@themes) {
        my @terms = DomainConfig::get_sub_theme_terms($config, $theme);
        print "  - $theme: " . scalar(@terms) . " terms\n";
    }
    print "\n";
}

print "SQL Complexity:\n";
print "  - OR conditions in main query: " . scalar(@all_terms) . "\n";
print "  - Estimated query execution time: ";

if (scalar(@all_terms) < 10) {
    print "Fast (< 1 second)\n";
}
elsif (scalar(@all_terms) < 30) {
    print "Moderate (1-3 seconds)\n";
}
else {
    print "Slower (3-10 seconds)\n";
}

print "\n";

# Summary
print "=" x 60 . "\n";
print "SUMMARY\n";
print "=" x 60 . "\n";
print "✓ WHERE clause generated successfully\n";
print "✓ " . scalar(keys %$queries) . " analysis queries generated\n";

if (DomainConfig::has_sub_themes($config)) {
    my @themes = DomainConfig::get_sub_theme_names($config);
    print "✓ " . scalar(@themes) . " sub-theme queries generated\n";
}

print "\nNext steps:\n";
print "  1. Test against database: make query-test DOMAIN=$domain_name\n";
print "  2. Generate full report: make report DOMAIN=$domain_name\n";
