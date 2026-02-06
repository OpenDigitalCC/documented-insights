#!/usr/bin/perl
use strict;
use warnings;

=pod

=head1 NAME

LLM Position Report Integration - Add LLM-extracted positions to domain reports

=head1 USAGE

This module provides functions to query position_analysis and format
LLM-extracted positions for inclusion in domain markdown reports.

Add to 09_generate_domain_report.pl after "Sentiment and Advocacy Patterns" section.

=cut

package LLMPositionReport;

use DBI;

# ============================================================================
# Database Queries for Position Analysis
# ============================================================================

sub get_position_distribution {
    my ($dbh, $domain) = @_;
    
    my $sql = qq{
        SELECT 
            p.position_category,
            p.position_type,
            COUNT(*) as response_count,
            ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY p.position_category), 1) as pct_of_category,
            COUNT(DISTINCT r.user_type) as stakeholder_types,
            COUNT(DISTINCT r.country) as countries,
            ROUND(100.0 * COUNT(CASE WHEN p.strength='strong' THEN 1 END) / COUNT(*), 1) as pct_strong,
            ROUND(100.0 * COUNT(CASE WHEN p.strength='moderate' THEN 1 END) / COUNT(*), 1) as pct_moderate,
            ROUND(100.0 * COUNT(CASE WHEN p.strength='weak' THEN 1 END) / COUNT(*), 1) as pct_weak
        FROM position_analysis p
        JOIN responses r ON p.response_id = r.id
        WHERE p.domain = ?
        GROUP BY p.position_category, p.position_type
        ORDER BY COUNT(*) DESC
    };
    
    my $sth = $dbh->prepare($sql);
    $sth->execute($domain);
    
    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }
    
    return \@results;
}

sub get_stakeholder_distribution {
    my ($dbh, $domain, $category) = @_;
    
    my $sql = qq{
        SELECT 
            r.user_type,
            p.position_type,
            COUNT(*) as response_count,
            ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY r.user_type), 1) as pct_of_stakeholder,
            ROUND(100.0 * COUNT(CASE WHEN p.strength='strong' THEN 1 END) / COUNT(*), 1) as pct_strong
        FROM position_analysis p
        JOIN responses r ON p.response_id = r.id
        WHERE p.domain = ?
          AND p.position_category = ?
        GROUP BY r.user_type, p.position_type
        ORDER BY COUNT(*) DESC
    };
    
    my $sth = $dbh->prepare($sql);
    $sth->execute($domain, $category);
    
    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }
    
    return \@results;
}

sub get_sample_arguments {
    my ($dbh, $domain, $category, $position_type, $limit) = @_;
    $limit ||= 3;
    
    my $sql = qq{
        SELECT 
            r.country,
            r.user_type,
            p.argument_summary,
            p.specific_proposal,
            p.strength
        FROM position_analysis p
        JOIN responses r ON p.response_id = r.id
        WHERE p.domain = ?
          AND p.position_category = ?
          AND p.position_type = ?
          AND p.argument_summary IS NOT NULL
          AND p.argument_summary != ''
        ORDER BY 
            CASE p.strength 
                WHEN 'strong' THEN 1 
                WHEN 'moderate' THEN 2 
                WHEN 'weak' THEN 3 
            END,
            LENGTH(p.argument_summary) DESC
        LIMIT ?
    };
    
    my $sth = $dbh->prepare($sql);
    $sth->execute($domain, $category, $position_type, $limit);
    
    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }
    
    return \@results;
}

sub get_specific_proposals {
    my ($dbh, $domain, $category) = @_;
    
    my $sql = qq{
        SELECT 
            p.specific_proposal,
            COUNT(*) as mention_count,
            COUNT(DISTINCT r.user_type) as stakeholder_types
        FROM position_analysis p
        JOIN responses r ON p.response_id = r.id
        WHERE p.domain = ?
          AND p.position_category = ?
          AND p.specific_proposal IS NOT NULL
          AND p.specific_proposal != ''
        GROUP BY p.specific_proposal
        ORDER BY COUNT(*) DESC
        LIMIT 10
    };
    
    my $sth = $dbh->prepare($sql);
    $sth->execute($domain, $category);
    
    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }
    
    return \@results;
}

sub get_evidence_citations {
    my ($dbh, $domain, $category) = @_;
    
    my $sql = qq{
        SELECT 
            UNNEST(p.evidence_cited) as citation,
            COUNT(*) as mention_count
        FROM position_analysis p
        WHERE p.domain = ?
          AND p.position_category = ?
          AND array_length(p.evidence_cited, 1) > 0
        GROUP BY citation
        ORDER BY COUNT(*) DESC
        LIMIT 15
    };
    
    my $sth = $dbh->prepare($sql);
    $sth->execute($domain, $category);
    
    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }
    
    return \@results;
}

# ============================================================================
# Formatting Functions
# ============================================================================

sub format_position_category {
    my ($category) = @_;
    
    # Convert underscore_separated to Title Case
    my $formatted = $category;
    $formatted =~ s/_/ /g;
    $formatted =~ s/\b(\w)/\U$1/g;
    
    return $formatted;
}

sub format_stakeholder_type {
    my ($type) = @_;
    
    my %labels = (
        'EU_CITIZEN' => 'EU Citizens',
        'COMPANY' => 'Companies',
        'NGO' => 'NGOs',
        'PUBLIC_AUTHORITY' => 'Public Authorities',
        'BUSINESS_ASSOCIATION' => 'Business Associations',
        'ACADEMIC_INSTITUTION' => 'Academic Institutions',
        'TRADE_UNION' => 'Trade Unions',
    );
    
    return $labels{$type} || $type;
}

sub format_position_type {
    my ($type) = @_;
    
    return '' unless defined $type;
    
    my %labels = (
        'support' => 'Support',
        'oppose' => 'Oppose',
        'neutral' => 'Neutral',
        'mixed' => 'Mixed',
    );
    
    return $labels{$type} || $type;
}

# ============================================================================
# Report Generation
# ============================================================================

sub generate_positions_section {
    my ($dbh, $domain, $out) = @_;
    
    # Get processing status for this domain
    my $status_sth = $dbh->prepare(q{
        SELECT 
            responses_with_positions,
            total_positions,
            distinct_categories
        FROM position_extraction_progress
        WHERE domain = ?
    });
    $status_sth->execute($domain);
    my $status = $status_sth->fetchrow_hashref();
    
    # Get overall LLM processing stats
    my ($total_done, $total_failed, $total_remaining) = $dbh->selectrow_array(q{
        SELECT 
            COUNT(*) FILTER (WHERE llm_extracted = TRUE),
            COUNT(*) FILTER (WHERE llm_extraction_failed = TRUE),
            COUNT(*) FILTER (WHERE llm_extracted = FALSE AND llm_extraction_failed = FALSE)
        FROM responses
    });
    
    my $processed = $status ? $status->{responses_with_positions} : 0;
    my $total_all = $total_done + $total_failed + $total_remaining;
    my $pct_complete = $total_all > 0 ? sprintf("%.1f", 100 * $total_done / $total_all) : 0;
    
    print $out "## Stakeholder Positions\n\n";
    
    # Processing status notice
    if ($pct_complete < 100) {
        print $out "**LLM Processing Status**: $total_done responses analysed across all domains ";
        print $out "($pct_complete% complete, $total_remaining remaining). ";
        print $out "**This domain**: $processed responses. ";
        print $out "Results are partial and will update as processing continues.\n\n";
    } elsif ($processed > 0) {
        print $out "**LLM Processing Status**: Complete. Analysed $processed responses for this domain.\n\n";
    }
    
    if ($processed > 0) {
        print $out "Analysis of positions extracted through LLM analysis of consultation responses. ";
        print $out "Extracted " . ($status->{total_positions} || 0) . " positions across ";
        print $out ($status->{distinct_categories} || 0) . " categories.\n\n";
    }
    
    
    # Get position distribution
    my $positions = get_position_distribution($dbh, $domain);
    
    if (!@$positions) {
        print $out "No positions extracted for this domain (LLM analysis may not have been run).\n\n";
        return;
    }
    
    # Overview statistics
    print $out "### Position Overview\n\n";
    
    # Group by category for overview table
    my %categories;
    my $total_positions = 0;
    
    for my $pos (@$positions) {
        my $cat = $pos->{position_category};
        my $type = $pos->{position_type} || 'neutral';  # Default to neutral if missing
        
        $categories{$cat} ||= {
            support => 0,
            oppose => 0,
            neutral => 0,
            mixed => 0,
            total => 0,
            strong => 0,
        };
        
        $categories{$cat}->{$type} += $pos->{response_count};
        $categories{$cat}->{total} += $pos->{response_count};
        $categories{$cat}->{strong} += (($pos->{pct_strong} || 0) / 100) * $pos->{response_count};
        $total_positions += $pos->{response_count};
    }
    
    # Position distribution table
    print $out "\\begin{longtable}{lrrrr}\n";
    print $out "\\toprule\n";
    print $out "Position Category & Support & Oppose & Neutral/Mixed & Total \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    
    print $out "\\toprule\n";
    print $out "Position Category & Support & Oppose & Neutral/Mixed & Total \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    for my $cat (sort { $categories{$b}->{total} <=> $categories{$a}->{total} } keys %categories) {
        my $data = $categories{$cat};
        my $neutral_mixed = $data->{neutral} + $data->{mixed};
        
        printf $out "%s & %d & %d & %d & %d \\\\\n",
            format_position_category($cat),
            $data->{support},
            $data->{oppose},
            $neutral_mixed,
            $data->{total};
    }
    
    print $out "\\end{longtable}\n\n";
    
    # Detailed position analysis
    print $out "### Detailed Position Analysis\n\n";
    
    # Process each major category
    for my $cat (sort { $categories{$b}->{total} <=> $categories{$a}->{total} } keys %categories) {
        my $cat_data = $categories{$cat};
        
        # Skip if very few positions
        next if $cat_data->{total} < 3;
        
        print $out "#### " . format_position_category($cat) . "\n\n";
        
        # Get position breakdown for this category
        my @cat_positions = grep { $_->{position_category} eq $cat } @$positions;
        
        # Overview as definition list
        print $out "Total responses\n";
        printf $out ": %d positions extracted across %d distinct responses\n\n",
            $cat_data->{total},
            scalar(grep { $_->{position_category} eq $cat } @$positions);
        
        # Support/oppose breakdown
        my @support = grep { $_->{position_type} eq 'support' } @cat_positions;
        my @oppose = grep { $_->{position_type} eq 'oppose' } @cat_positions;
        
        if (@support) {
            my $support_count = $support[0]->{response_count} || 0;
            my $support_pct = sprintf("%.1f", 100 * $support_count / $cat_data->{total});
            my $strong_pct = $support[0]->{pct_strong} || 0;
            
            print $out "Support position\n";
            printf $out ": %d responses (%s%%), %.1f%% express strong advocacy\n\n",
                $support_count, $support_pct, $strong_pct;
            
            # Stakeholder breakdown for support
            my $stakeholders = get_stakeholder_distribution($dbh, $domain, $cat);
            my @support_stakeholders = grep { $_->{position_type} eq 'support' } @$stakeholders;
            
            if (@support_stakeholders) {
                print $out "Primary stakeholders (support)\n";
                print $out ": ";
                my @formatted;
                for my $sh (@support_stakeholders[0..2]) {
                    last unless $sh;
                    my $count = $sh->{response_count} || 0;
                    my $type = format_stakeholder_type($sh->{user_type} || '');
                    push @formatted, sprintf("%s (%d)", $type, $count) if $type;
                }
                print $out join(", ", @formatted) . "\n\n" if @formatted;
            }
            
            # Sample arguments
            my $arguments = get_sample_arguments($dbh, $domain, $cat, 'support', 2);
            if (@$arguments) {
                print $out "Core arguments (support)\n";
                print $out ": ";
                my @arg_texts;
                for my $arg (@$arguments) {
                    next unless $arg && $arg->{argument_summary};
                    my $text = $arg->{argument_summary};
                    $text =~ s/\s+/ /g;  # Normalize whitespace
                    $text =~ s/\n/ /g;
                    push @arg_texts, $text;
                }
                print $out join("; ", @arg_texts) . "\n\n" if @arg_texts;
            }
        }
        
        if (@oppose) {
            my $oppose_count = $oppose[0]->{response_count} || 0;
            my $oppose_pct = sprintf("%.1f", 100 * $oppose_count / $cat_data->{total});
            my $strong_pct = $oppose[0]->{pct_strong} || 0;
            
            print $out "Opposition position\n";
            printf $out ": %d responses (%s%%), %.1f%% express strong opposition\n\n",
                $oppose_count, $oppose_pct, $strong_pct;
            
            # Sample arguments for opposition
            my $arguments = get_sample_arguments($dbh, $domain, $cat, 'oppose', 2);
            if (@$arguments) {
                print $out "Core arguments (oppose)\n";
                print $out ": ";
                my @arg_texts;
                for my $arg (@$arguments) {
                    next unless $arg && $arg->{argument_summary};
                    my $text = $arg->{argument_summary};
                    $text =~ s/\s+/ /g;
                    $text =~ s/\n/ /g;
                    push @arg_texts, $text;
                }
                print $out join("; ", @arg_texts) . "\n\n" if @arg_texts;
            }
        }
        
        # Specific proposals
        my $proposals = get_specific_proposals($dbh, $domain, $cat);
        if (@$proposals) {
            print $out "Specific proposals mentioned\n";
            print $out ": ";
            my @proposal_texts;
            for my $prop (@$proposals[0..2]) {  # Top 3
                next unless $prop && $prop->{specific_proposal};
                my $text = $prop->{specific_proposal};
                $text =~ s/\s+/ /g;
                $text =~ s/\n/ /g;
                push @proposal_texts, sprintf("%s (%d mentions)", $text, $prop->{mention_count});
            }
            print $out join("; ", @proposal_texts) . "\n\n" if @proposal_texts;
        }
        
        # Evidence citations
        my $evidence = get_evidence_citations($dbh, $domain, $cat);
        if (@$evidence && @$evidence >= 3) {
            print $out "Evidence cited\n";
            print $out ": ";
            my @citations;
            for my $ev (@$evidence[0..4]) {  # Top 5
                next unless $ev && $ev->{citation};
                my $text = $ev->{citation};
                $text =~ s/\s+/ /g;
                push @citations, sprintf("%s (%d)", $text, $ev->{mention_count});
            }
            print $out join("; ", @citations) . "\n\n" if @citations;
        }
    }
}

1;

__END__

=head1 INTEGRATION

Add to 09_generate_domain_report.pl after the "Sentiment and Advocacy Patterns" section:

    # Load LLM position report module
    require './lib/LLMPositionReport.pm';
    
    # Generate stakeholder positions section (if LLM data exists)
    LLMPositionReport::generate_positions_section($dbh, $domain_name, $out);

=head1 OUTPUT FORMAT

Produces markdown following British English conventions:

- Definition lists for metadata (not bold labels)
- LaTeX longtables for data
- Narrative analysis in prose
- Blank lines before block elements
- En-dashes for ranges

Example output:

## Stakeholder Positions

### Position Overview

\begin{longtable}{lrrrr}
...
Public Funding & 45 & 8 & 2 & 55 \\
Tax Incentive & 23 & 12 & 5 & 40 \\
\end{longtable}

### Detailed Position Analysis

#### Public Funding

Total responses
: 55 positions extracted across 48 distinct responses

Support position
: 45 responses (81.8%), 68.9% express strong advocacy

Primary stakeholders (support)
: EU Citizens (28), NGOs (12), Companies (5)

Core arguments (support)
: Market failure necessitates public investment in digital public goods; OSS provides critical infrastructure requiring sustained funding

Specific proposals mentioned
: Direct grants to core projects (12 mentions); Procurement set-asides (8 mentions)

=cut
