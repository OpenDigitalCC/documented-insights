#!/usr/bin/env perl
#
# scripts/combine_reports_for_pdf.pl
# Combine pattern and LLM reports with encoding cleanup
#
# Usage: perl scripts/combine_reports_for_pdf.pl <domain>

use strict;
use warnings;
use Encode qw(decode encode);

my $domain = $ARGV[0] or die "Usage: $0 <domain>\n";

my $pattern_file = "output/domain_${domain}_analysis_pattern.md";
my $llm_file = "output/domain_${domain}_analysis_llm.md";
my $output_file = "output/domain_${domain}_analysis_combined.md";

# Check pattern file exists
die "Pattern file not found: $pattern_file\n" unless -f $pattern_file;

# Open output file as binary, we'll write UTF-8 bytes
open my $out, '>:raw', $output_file
    or die "Cannot create $output_file: $!\n";

# Function to read file and clean encoding
sub read_and_clean {
    my ($filename) = @_;
    
    # Read entire file as bytes
    open my $fh, '<:raw', $filename or die "Cannot read $filename: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;
    
    # Try to decode as UTF-8, fall back to Latin-1 if needed
    my $text;
    eval {
        $text = decode('UTF-8', $content, Encode::FB_CROAK);
    };
    if ($@) {
        # Not valid UTF-8, try Latin-1
        $text = decode('ISO-8859-1', $content);
    }
    
    # Clean up problematic characters that LaTeX can't handle
    $text =~ s/\x{0080}/ /g;  # Replace U+0080 with space
    $text =~ s/[\x{0080}-\x{009F}]//g;  # Remove C1 control characters
    
    return $text;
}

# Read and clean pattern file
my $pattern_text = read_and_clean($pattern_file);

# Write pattern section
print $out encode('UTF-8', $pattern_text);

# Add LLM section if it exists
if (-f $llm_file) {
    print $out encode('UTF-8', "\n---\n\n");  # Section separator
    
    my $llm_text = read_and_clean($llm_file);
    print $out encode('UTF-8', $llm_text);
    
    binmode(STDERR, ':encoding(UTF-8)');
    print STDERR "✓ Combined: Pattern + LLM\n";
} else {
    binmode(STDERR, ':encoding(UTF-8)');
    print STDERR "⚠ LLM file not found, using pattern only\n";
}

close $out;
binmode(STDERR, ':encoding(UTF-8)');
print STDERR "✓ Created: $output_file (UTF-8 encoded, cleaned)\n";
