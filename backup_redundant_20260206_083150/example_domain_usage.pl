#!/usr/bin/perl
# scripts/example_domain_usage.pl
# Example: How to use DomainConfig module

use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use DomainConfig;

# Get domain name from command line
my $domain_name = $ARGV[0] or die "Usage: $0 <domain-name>\n";

# Construct filepath
my $filepath = "$FindBin::Bin/../domains/${domain_name}.conf";

print "Loading domain configuration...\n";
print "File: $filepath\n\n";

# Parse configuration
my $config = DomainConfig::parse_config($filepath);

unless ($config) {
    die "Failed to parse configuration\n";
}

print "✓ Configuration loaded successfully\n\n";

# Display metadata
print "=" x 60 . "\n";
print "DOMAIN METADATA\n";
print "=" x 60 . "\n";
print "Name: " . $config->{domain}{name} . "\n";
print "Description: " . $config->{domain}{description} . "\n";

if ($config->{domain}{commission_context}) {
    print "Commission Context: " . $config->{domain}{commission_context} . "\n";
}

if ($config->{domain}{urgency}) {
    print "Urgency: " . $config->{domain}{urgency} . "\n";
}

print "\n";

# Display search terms
print "=" x 60 . "\n";
print "SEARCH TERMS\n";
print "=" x 60 . "\n";
print DomainConfig::format_terms($config);

# Display statistics
print "=" x 60 . "\n";
print "STATISTICS\n";
print "=" x 60 . "\n";

my @all_terms = DomainConfig::get_all_terms($config);
print "Total search terms: " . scalar(@all_terms) . "\n";
print "  - Keywords: " . scalar(@{$config->{keywords}}) . "\n";
print "  - Keyphrases: " . scalar(@{$config->{keyphrases}}) . "\n";

if (DomainConfig::has_sub_themes($config)) {
    my @themes = DomainConfig::get_sub_theme_names($config);
    print "Sub-themes: " . scalar(@themes) . "\n";
    
    foreach my $theme (@themes) {
        my @terms = DomainConfig::get_sub_theme_terms($config, $theme);
        print "  - $theme: " . scalar(@terms) . " terms\n";
    }
}

print "\n";

# Validation
print "=" x 60 . "\n";
print "VALIDATION\n";
print "=" x 60 . "\n";

my @warnings = DomainConfig::validate_config($config);

if (@warnings) {
    print "Warnings found:\n";
    foreach my $warning (@warnings) {
        print "  ⚠ $warning\n";
    }
}
else {
    print "✓ No validation warnings\n";
}

print "\n";

# Example: Generate SQL WHERE clause (mock)
print "=" x 60 . "\n";
print "EXAMPLE SQL WHERE CLAUSE\n";
print "=" x 60 . "\n";

my @conditions;

# Keywords
if (@{$config->{keywords}}) {
    my $keyword_pattern = join('|', @{$config->{keywords}});
    push @conditions, "lower(full_text) ~ '\\b($keyword_pattern)\\b'";
}

# Keyphrases (would use to_tsquery in real implementation)
if (@{$config->{keyphrases}}) {
    foreach my $phrase (@{$config->{keyphrases}}) {
        my $pattern = $phrase;
        $pattern =~ s/\s+/.?/g;  # Flexible whitespace
        push @conditions, "lower(full_text) ~ '$pattern'";
    }
}

if (@conditions) {
    my $where_clause = join("\n   OR ", @conditions);
    print "WHERE (\n   $where_clause\n)\n";
}

print "\n";
print "=" x 60 . "\n";
print "Next steps:\n";
print "  1. Use this config to generate analysis queries\n";
print "  2. Execute queries against database\n";
print "  3. Generate Commission-perspective report\n";
print "=" x 60 . "\n";
