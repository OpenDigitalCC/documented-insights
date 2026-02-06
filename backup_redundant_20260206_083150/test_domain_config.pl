#!/usr/bin/perl
# scripts/test_domain_config.pl
# Test domain configuration parser

use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use DomainConfig;

print "Domain Configuration Parser - Test Suite\n";
print "=" x 60 . "\n\n";

# Find all domain config files
my $domains_dir = "$FindBin::Bin/../domains";
unless (-d $domains_dir) {
    die "Domains directory not found: $domains_dir\n";
}

opendir(my $dh, $domains_dir) or die "Cannot open $domains_dir: $!\n";
my @config_files = grep { /\.conf$/ && -f "$domains_dir/$_" } readdir($dh);
closedir($dh);

unless (@config_files) {
    die "No .conf files found in $domains_dir\n";
}

print "Found " . scalar(@config_files) . " domain configuration files\n\n";

# Test each config file
my $total_tested = 0;
my $total_passed = 0;
my $total_warnings = 0;

foreach my $filename (sort @config_files) {
    my $filepath = "$domains_dir/$filename";
    
    print "Testing: $filename\n";
    print "-" x 60 . "\n";
    
    $total_tested++;
    
    # Parse config
    my $config = DomainConfig::parse_config($filepath);
    
    unless ($config) {
        print "ERROR: Failed to parse configuration\n\n";
        next;
    }
    
    $total_passed++;
    
    # Display summary
    print DomainConfig::config_summary($config);
    print "\n";
    
    # Validate
    my @warnings = DomainConfig::validate_config($config);
    if (@warnings) {
        print "Warnings:\n";
        foreach my $warning (@warnings) {
            print "  - $warning\n";
        }
        $total_warnings += scalar(@warnings);
        print "\n";
    }
    
    # Display terms if verbose
    if ($ENV{VERBOSE}) {
        print DomainConfig::format_terms($config);
    }
    
    print "\n";
}

# Summary
print "=" x 60 . "\n";
print "Test Summary\n";
print "=" x 60 . "\n";
print "Total configurations tested: $total_tested\n";
print "Successfully parsed: $total_passed\n";
print "Failed: " . ($total_tested - $total_passed) . "\n";
print "Total warnings: $total_warnings\n";

if ($total_passed == $total_tested && $total_warnings == 0) {
    print "\n✓ All tests passed with no warnings!\n";
    exit 0;
}
elsif ($total_passed == $total_tested) {
    print "\n✓ All tests passed (with warnings)\n";
    exit 0;
}
else {
    print "\n✗ Some tests failed\n";
    exit 1;
}
