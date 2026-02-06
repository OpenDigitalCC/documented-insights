#!/usr/bin/perl
# lib/DomainConfig.pm
# Parser for domain configuration files

package DomainConfig;

use strict;
use warnings;
use utf8;

# Parse a domain configuration file
# Returns hashref with domain data or undef on error
sub parse_config {
    my ($filepath) = @_;
    
    unless (-f $filepath) {
        warn "Config file not found: $filepath\n";
        return undef;
    }
    
    open my $fh, '<:encoding(UTF-8)', $filepath or do {
        warn "Cannot open $filepath: $!\n";
        return undef;
    };
    
    my $config = {
        filepath => $filepath,
        domain => {},
        keywords => [],
        keyphrases => [],
        sub_themes => {},
        exclusions => []
    };
    
    my $current_section = '';
    my $line_num = 0;
    
    while (my $line = <$fh>) {
        $line_num++;
        
        # Remove comments and trim
        $line =~ s/#.*$//;
        $line =~ s/^\s+|\s+$//g;
        
        # Skip blank lines
        next if $line eq '';
        
        # Section header
        if ($line =~ /^\[(\w+(?:-\w+)*)\]$/) {
            $current_section = $1;
            next;
        }
        
        # Section content
        if ($current_section eq 'domain') {
            parse_domain_field($config, $line, $line_num);
        }
        elsif ($current_section eq 'keywords') {
            push @{$config->{keywords}}, lc($line);
        }
        elsif ($current_section eq 'keyphrases') {
            push @{$config->{keyphrases}}, lc($line);
        }
        elsif ($current_section eq 'sub-themes') {
            parse_sub_theme($config, $line, $line_num);
        }
        elsif ($current_section eq 'exclusions') {
            push @{$config->{exclusions}}, lc($line);
        }
        elsif ($current_section) {
            warn "Unknown section: [$current_section] at line $line_num\n";
        }
        else {
            warn "Content outside section at line $line_num: $line\n";
        }
    }
    
    close $fh;
    
    # Validate required fields
    unless ($config->{domain}{name}) {
        warn "Missing required field: domain.name in $filepath\n";
        return undef;
    }
    
    unless ($config->{domain}{description}) {
        warn "Missing required field: domain.description in $filepath\n";
        return undef;
    }
    
    unless (@{$config->{keywords}} || @{$config->{keyphrases}}) {
        warn "No keywords or keyphrases defined in $filepath\n";
        return undef;
    }
    
    return $config;
}

# Parse a field in [domain] section
sub parse_domain_field {
    my ($config, $line, $line_num) = @_;
    
    if ($line =~ /^(\w+)\s*=\s*(.+)$/) {
        my ($key, $value) = ($1, $2);
        $config->{domain}{$key} = $value;
    }
    else {
        warn "Invalid domain field at line $line_num: $line\n";
    }
}

# Parse a sub-theme definition
sub parse_sub_theme {
    my ($config, $line, $line_num) = @_;
    
    if ($line =~ /^(\w+(?:-\w+)*)\s*=\s*(.+)$/) {
        my ($theme_name, $terms) = ($1, $2);
        
        # Split on commas and trim
        my @terms = map { 
            s/^\s+|\s+$//g; 
            lc($_) 
        } split(/,/, $terms);
        
        $config->{sub_themes}{$theme_name} = \@terms;
    }
    else {
        warn "Invalid sub-theme definition at line $line_num: $line\n";
    }
}

# Get all search terms (keywords + keyphrases)
sub get_all_terms {
    my ($config) = @_;
    
    return (
        @{$config->{keywords}},
        @{$config->{keyphrases}}
    );
}

# Get terms for a specific sub-theme
sub get_sub_theme_terms {
    my ($config, $theme_name) = @_;
    
    return () unless exists $config->{sub_themes}{$theme_name};
    return @{$config->{sub_themes}{$theme_name}};
}

# Get list of sub-theme names
sub get_sub_theme_names {
    my ($config) = @_;
    
    return sort keys %{$config->{sub_themes}};
}

# Check if config has sub-themes defined
sub has_sub_themes {
    my ($config) = @_;
    
    return scalar(keys %{$config->{sub_themes}}) > 0;
}

# Validate configuration (detailed checks)
sub validate_config {
    my ($config) = @_;
    
    my @warnings;
    
    # Check for duplicate terms
    my %seen;
    foreach my $term (get_all_terms($config)) {
        if ($seen{$term}++) {
            push @warnings, "Duplicate term: $term";
        }
    }
    
    # Check for very short keywords
    foreach my $kw (@{$config->{keywords}}) {
        if (length($kw) < 3) {
            push @warnings, "Very short keyword (< 3 chars): $kw";
        }
    }
    
    # Check for empty sub-themes
    foreach my $theme (get_sub_theme_names($config)) {
        my @terms = get_sub_theme_terms($config, $theme);
        unless (@terms) {
            push @warnings, "Empty sub-theme: $theme";
        }
    }
    
    return @warnings;
}

# Summary of configuration
sub config_summary {
    my ($config) = @_;
    
    my $summary = '';
    $summary .= "Domain: " . $config->{domain}{name} . "\n";
    $summary .= "Description: " . $config->{domain}{description} . "\n";
    $summary .= "Keywords: " . scalar(@{$config->{keywords}}) . "\n";
    $summary .= "Keyphrases: " . scalar(@{$config->{keyphrases}}) . "\n";
    
    if (has_sub_themes($config)) {
        $summary .= "Sub-themes: " . scalar(keys %{$config->{sub_themes}}) . "\n";
    }
    
    if (@{$config->{exclusions}}) {
        $summary .= "Exclusions: " . scalar(@{$config->{exclusions}}) . "\n";
    }
    
    return $summary;
}

# Format for display
sub format_terms {
    my ($config) = @_;
    
    my $output = '';
    
    if (@{$config->{keywords}}) {
        $output .= "Keywords:\n";
        $output .= "  " . join(', ', @{$config->{keywords}}) . "\n\n";
    }
    
    if (@{$config->{keyphrases}}) {
        $output .= "Keyphrases:\n";
        foreach my $phrase (@{$config->{keyphrases}}) {
            $output .= "  - $phrase\n";
        }
        $output .= "\n";
    }
    
    if (has_sub_themes($config)) {
        $output .= "Sub-themes:\n";
        foreach my $theme (get_sub_theme_names($config)) {
            my @terms = get_sub_theme_terms($config, $theme);
            $output .= "  $theme: " . join(', ', @terms) . "\n";
        }
        $output .= "\n";
    }
    
    return $output;
}

1;
