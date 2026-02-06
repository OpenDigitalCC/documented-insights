#!/usr/bin/perl
# scripts/09_generate_domain_report.pl
# Generate Commission-perspective domain analysis report

use strict;
use warnings;
use utf8;
use DBI;
use POSIX qw(strftime);
use FindBin;
use lib "$FindBin::Bin/../lib";
use DomainConfig;
use DomainQuery;

binmode STDOUT, ':utf8';

print "Generating Domain Analysis Report\n";
print "==================================\n\n";

# Get domain name from command line
my $domain_name = $ARGV[0];

unless ($domain_name) {
    die "Usage: $0 <domain-name>\n\nExample: $0 taxation\n";
}

# Configuration
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

my $output_file = "/app/output/domain_${domain_name}_analysis_pattern.md";

# Load domain configuration
my $config_file = "$FindBin::Bin/../domains/${domain_name}.conf";
my $config = DomainConfig::parse_config($config_file);

unless ($config) {
    die "Failed to load domain configuration: $config_file\n";
}

print "Domain: " . $config->{domain}{name} . "\n";
print "Output: $output_file\n\n";

# Connect to database
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user, $db_pass,
    { AutoCommit => 1, RaiseError => 1, pg_enable_utf8 => 1 }
) or die "Cannot connect: $DBI::errstr\n";

print "Connected to database.\n";
print "Gathering analysis data...\n\n";

# Gather all analysis data
my $stats = DomainQuery::get_coverage_stats($dbh, $config);
my $stakeholders = DomainQuery::get_stakeholder_breakdown($dbh, $config);
my $countries = DomainQuery::get_geographic_breakdown($dbh, $config);
my $cooccur = DomainQuery::get_domain_cooccurrence($dbh, $config, 30);
my $term_usage = DomainQuery::get_term_usage_patterns($dbh, $config);
my $sentiment = DomainQuery::get_domain_sentiment($dbh, $config);

my $sub_themes = {};
if (DomainConfig::has_sub_themes($config)) {
    $sub_themes = DomainQuery::get_sub_theme_breakdown($dbh, $config);
}

$dbh->disconnect;

print "Data gathered. Generating report...\n\n";

# Open output file
open my $out, '>:encoding(UTF-8)', $output_file or die "Cannot create output: $!\n";

# Report metadata
my $date = strftime("%d %B %Y", localtime);
my $domain_title = $config->{domain}{name};
my $domain_desc = $config->{domain}{description};

# Header
print $out "# EU Open Digital Ecosystems Consultation\n\n";
print $out "## $domain_title\n\n";
print $out "Analysis date\n";
print $out ": $date\n\n";

print $out "Domain scope\n";
print $out ": $domain_desc\n\n";

if ($config->{domain}{commission_context}) {
    print $out "Commission context\n";
    print $out ": $config->{domain}{commission_context}\n\n";
}

# Executive summary
print $out "## Executive Summary\n\n";

my $matching = $stats->{matching_responses} || 0;
my $coverage = $stats->{pct_of_corpus} || 0;
my $num_countries = $stats->{countries} || 0;
my $num_stakeholders = $stats->{stakeholder_types} || 0;

print $out "This domain received substantial engagement across the consultation, with ";
print $out format_number($matching) . " responses ($coverage% of corpus) addressing ";
print $out "related themes. Respondents from $num_countries countries and $num_stakeholders ";
print $out "stakeholder types contributed, indicating broad interest across the EU.\n\n";

# Market sentiment overview
print $out "## Market Sentiment Overview\n\n";

print $out "### Coverage and Engagement\n\n";

print $out "\\begin{longtable}{lr}\n";
print $out "\\toprule\n";
print $out "Metric & Value \\\\\n";
print $out "\\midrule\n";
print $out "\\endfirsthead\n\n";
print $out "\\toprule\n";
print $out "Metric & Value \\\\\n";
print $out "\\midrule\n";
print $out "\\endhead\n\n";
print $out "\\bottomrule\n";
print $out "\\endlastfoot\n\n";

print $out "Matching responses & " . format_number($matching) . " \\\\\n";
print $out "Coverage of corpus & $coverage\\% \\\\\n";
print $out "Countries represented & $num_countries \\\\\n";
print $out "Stakeholder types & $num_stakeholders \\\\\n";
print $out "Organisations & " . format_number($stats->{organizations}) . " \\\\\n";
print $out "Responses with attachments & " . format_number($stats->{with_attachments}) . " \\\\\n";

print $out "\\end{longtable}\n\n";

# Stakeholder positions
print $out "### Stakeholder Positions\n\n";

if (@$stakeholders) {
    my $primary = $stakeholders->[0];
    my $primary_type = format_stakeholder($primary->{user_type});
    my $primary_pct = $primary->{percentage};
    
    print $out "The consultation response was dominated by ${primary_type}s ($primary_pct%), ";
    
    if (@$stakeholders > 1) {
        my $secondary = $stakeholders->[1];
        my $secondary_type = format_stakeholder($secondary->{user_type});
        my $secondary_pct = $secondary->{percentage};
        
        print $out "followed by ${secondary_type}s ($secondary_pct%). ";
    }
    
    print $out "This distribution suggests ";
    
    if ($primary->{user_type} =~ /CITIZEN/i) {
        print $out "strong grassroots interest rather than primarily industry-driven advocacy.\n\n";
    }
    elsif ($primary->{user_type} =~ /COMPANY/i) {
        print $out "significant commercial interest in policy development.\n\n";
    }
    elsif ($primary->{user_type} =~ /NGO/i) {
        print $out "organised civil society engagement.\n\n";
    }
    else {
        print $out "diverse stakeholder engagement.\n\n";
    }
    
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Stakeholder Type & Responses & Countries & Percentage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\toprule\n";
    print $out "Stakeholder Type & Responses & Countries & Percentage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$stakeholders) {
        printf $out "%s & %s & %s & %.1f\\%% \\\\\n",
            latex_escape(format_stakeholder($row->{user_type})),
            format_number($row->{count}),
            $row->{countries},
            $row->{percentage};
    }
    
    print $out "\\end{longtable}\n\n";
}

# Geographic distribution
print $out "### Geographic Distribution\n\n";

if (@$countries) {
    my $top_country = $countries->[0];
    my $top_pct = $top_country->{percentage};
    
    print $out "Geographic engagement shows concentration in " . format_country($top_country->{country});
    print $out " ($top_pct%), with notable participation from ";
    
    if (@$countries > 2) {
        print $out format_country($countries->[1]{country}) . " and " . format_country($countries->[2]{country}) . ". ";
    }
    
    print $out "The distribution across $num_countries countries indicates ";
    
    if ($num_countries > 20) {
        print $out "EU-wide relevance rather than localised concern.\n\n";
    }
    elsif ($num_countries > 10) {
        print $out "broad but uneven geographic interest.\n\n";
    }
    else {
        print $out "concentrated interest in specific member states.\n\n";
    }
    
    print $out "\\begin{longtable}{lrr}\n";
    print $out "\\toprule\n";
    print $out "Country & Responses & Percentage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\toprule\n";
    print $out "Country & Responses & Percentage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    my $count = 0;
    foreach my $row (@$countries) {
        last if ++$count > 15;
        
        printf $out "%s & %s & %.1f\\%% \\\\\n",
            latex_escape(format_country($row->{country})),
            format_number($row->{count}),
            $row->{percentage};
    }
    
    print $out "\\end{longtable}\n\n";
}

# Term usage analysis
print $out "## Term Usage Patterns\n\n";

if (%$term_usage) {
    print $out "Analysis of term concentration reveals how strongly specific concepts ";
    print $out "feature in responses compared to the broader consultation corpus. ";
    print $out "A strength score above 1.5 indicates the term appears more frequently ";
    print $out "in this domain than in general discussion.\n\n";
    
    foreach my $term (sort { $term_usage->{$b}{strength} <=> $term_usage->{$a}{strength} } 
                      keys %$term_usage) {
        my $data = $term_usage->{$term};
        my $strength = $data->{strength};
        
        print $out "**$term** (strength: " . sprintf("%.1f", $strength) . ")\n\n";
        
        print $out ": " . $data->{usage_note} . "\n\n";
        
        if ($data->{positive_context}) {
            print $out ": Positive framing – $data->{positive_context}\n\n";
        }
        
        if ($data->{negative_context}) {
            print $out ": Critical framing – $data->{negative_context}\n\n";
        }
    }
}

# Sentiment analysis
print $out "## Sentiment and Advocacy Patterns\n\n";

if (%$sentiment) {
    my $action = $sentiment->{action_oriented} || 0;
    my $problem = $sentiment->{problem_focused} || 0;
    my $solution = $sentiment->{solution_focused} || 0;
    
    print $out "Language analysis reveals the tone and advocacy intensity of responses ";
    print $out "addressing this domain.\n\n";
    
    print $out "\\begin{longtable}{lr}\n";
    print $out "\\toprule\n";
    print $out "Language Pattern & Percentage of Responses \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\toprule\n";
    print $out "Language Pattern & Percentage of Responses \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    print $out "Action-oriented language & " . sprintf("%.1f", $action) . "\\% \\\\\n";
    print $out "Problem-focused language & " . sprintf("%.1f", $problem) . "\\% \\\\\n";
    print $out "Solution-focused language & " . sprintf("%.1f", $solution) . "\\% \\\\\n";
    
    print $out "\\end{longtable}\n\n";
    
    if ($sentiment->{dominant_tone}) {
        print $out "::: widebox\n";
        print $out $sentiment->{dominant_tone};
        if ($sentiment->{advocacy_level}) {
            print $out " – Advocacy level: $sentiment->{advocacy_level}";
        }
        print $out "\n:::\n\n";
    }
}

# Co-occurring themes
print $out "## Related Themes and Context\n\n";

if (@$cooccur) {
    print $out "Terms that frequently co-occur with domain concepts reveal the broader ";
    print $out "context in which respondents frame this policy area.\n\n";
    
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Co-occurring Term & Occurrences & Documents & Document \\% \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\toprule\n";
    print $out "Co-occurring Term & Occurrences & Documents & Document \\% \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    my $count = 0;
    foreach my $row (@$cooccur) {
        last if ++$count > 20;
        
        printf $out "%s & %s & %s & %.1f\\%% \\\\\n",
            latex_escape($row->{word}),
            format_number($row->{occurrences}),
            format_number($row->{documents}),
            $row->{doc_pct};
    }
    
    print $out "\\end{longtable}\n\n";
}

# Sub-theme analysis
if (%$sub_themes) {
    print $out "## Sub-theme Distribution\n\n";
    
    print $out "Responses addressing this domain cluster around distinct sub-themes, ";
    print $out "revealing specific areas of concern or opportunity. Note that responses ";
    print $out "may address multiple sub-themes.\n\n";
    
    print $out "\\begin{longtable}{lrr}\n";
    print $out "\\toprule\n";
    print $out "Sub-theme & Responses & Percentage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\toprule\n";
    print $out "Sub-theme & Responses & Percentage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $theme (sort { $sub_themes->{$b} <=> $sub_themes->{$a} } keys %$sub_themes) {
        my $count = $sub_themes->{$theme};
        my $pct = $matching > 0 ? 100.0 * $count / $matching : 0;
        
        printf $out "%s & %s & %.1f\\%% \\\\\n",
            latex_escape(format_theme($theme)),
            format_number($count),
            $pct;
    }
    
    print $out "\\end{longtable}\n\n";
}

# Commission insights
print $out "## Policy Considerations\n\n";

print $out "### Market Structure Signals\n\n";

# Analyse stakeholder distribution
if (@$stakeholders) {
    my $citizen_pct = 0;
    my $business_pct = 0;
    my $ngo_pct = 0;
    
    foreach my $s (@$stakeholders) {
        if ($s->{user_type} =~ /CITIZEN/i) {
            $citizen_pct += $s->{percentage};
        }
        elsif ($s->{user_type} =~ /COMPANY|BUSINESS/i) {
            $business_pct += $s->{percentage};
        }
        elsif ($s->{user_type} =~ /NGO/i) {
            $ngo_pct += $s->{percentage};
        }
    }
    
    if ($citizen_pct > 40) {
        print $out "- Strong grassroots engagement suggests public concern extends beyond industry advocacy\n";
    }
    
    if ($business_pct > 30) {
        print $out "- Significant commercial interest indicates market impact expectations\n";
    }
    
    if ($ngo_pct > 15) {
        print $out "- Organised civil society engagement suggests broader societal implications\n";
    }
    
    print $out "\n";
}

print $out "### Advocacy Intensity\n\n";

if (%$sentiment) {
    if ($sentiment->{action_oriented} > 40) {
        print $out "- High action-oriented language indicates stakeholders expect policy intervention\n";
    }
    
    if ($sentiment->{solution_focused} > $sentiment->{problem_focused} * 1.3) {
        print $out "- Solution-focused framing suggests constructive engagement\n";
    }
    elsif ($sentiment->{problem_focused} > $sentiment->{solution_focused} * 1.3) {
        print $out "- Problem-focused framing indicates dissatisfaction with current state\n";
    }
    
    print $out "\n";
}

print $out "### Geographic Considerations\n\n";

if ($num_countries > 20) {
    print $out "- Broad geographic engagement suggests EU-level relevance\n";
}
elsif ($num_countries > 10) {
    print $out "- Moderate geographic spread indicates uneven member state interest\n";
}

if (@$countries && $countries->[0]{percentage} > 25) {
    print $out "- Concentration in " . format_country($countries->[0]{country});
    print $out " may reflect national policy priorities or industrial structure\n";
}

print $out "\n";

# Methodology note
print $out "## Methodology\n\n";

print $out "This analysis examines consultation responses through domain-specific keyword ";
print $out "and keyphrase matching. Coverage statistics indicate the proportion of responses ";
print $out "addressing the domain. Term usage strength compares domain-specific frequency ";
print $out "to corpus-wide frequency. Sentiment analysis identifies language patterns without ";
print $out "attributing positions to individual respondents.\n\n";

my @all_terms = DomainConfig::get_all_terms($config);
my $keyword_count = scalar(@{$config->{keywords}});
my $keyphrase_count = scalar(@{$config->{keyphrases}});

print $out "Search parameters\n";
print $out ": " . scalar(@all_terms) . " terms ($keyword_count keywords, $keyphrase_count keyphrases)\n\n";

print $out "Analysis date\n";
print $out ": $date\n\n";

# Close output file
close $out;

print "Report generated: $output_file\n";
print "Convert to HTML: pandoc -f markdown -o output/${domain_name}_report.html $output_file\n";

# Helper functions
sub format_number {
    my $num = shift;
    return '' unless defined $num;
    
    my $formatted = reverse $num;
    $formatted =~ s/(\d{3})(?=\d)/$1,/g;
    return scalar reverse $formatted;
}

sub latex_escape {
    my $text = shift;
    return '' unless defined $text;
    
    $text =~ s/\\/\\textbackslash{}/g;
    $text =~ s/([&%\$#_\{\}])/\\$1/g;
    $text =~ s/~/\\textasciitilde{}/g;
    $text =~ s/\^/\\textasciicircum{}/g;
    
    return $text;
}

sub format_stakeholder {
    my $type = shift;
    return '' unless defined $type;
    
    $type =~ s/_/ /g;
    $type = lc($type);
    $type =~ s/\b(\w)/\u$1/g;
    $type =~ s/Ngo/NGO/;
    $type =~ s/Eu/EU/;
    
    return $type;
}

sub format_country {
    my $code = shift;
    return '' unless defined $code;
    
    my %countries = (
        'DEU' => 'Germany',
        'FRA' => 'France',
        'NLD' => 'Netherlands',
        'ITA' => 'Italy',
        'BEL' => 'Belgium',
        'POL' => 'Poland',
        'ESP' => 'Spain',
        'AUT' => 'Austria',
        'GBR' => 'United Kingdom',
        'SWE' => 'Sweden',
        'USA' => 'United States',
        'PRT' => 'Portugal',
        'ROU' => 'Romania',
        'FIN' => 'Finland',
        'CHE' => 'Switzerland',
    );
    
    return $countries{$code} || $code;
}

sub format_theme {
    my $theme = shift;
    return '' unless defined $theme;
    
    $theme =~ s/_/ /g;
    $theme =~ s/\b(\w)/\u$1/g;
    
    return $theme;
}
