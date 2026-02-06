#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use POSIX qw(strftime);

print "Analyzing Consultation Questions\n";
print "================================\n\n";

# Configuration
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

my $output_file = '/app/output/consultation_questions_analysis.md';

# Connect to database
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user, $db_pass,
    { AutoCommit => 1, RaiseError => 1, pg_enable_utf8 => 1 }
) or die "Cannot connect: $DBI::errstr\n";

print "Connected to database.\n";
print "Generating analysis...\n\n";

# Open output file
open my $out, '>:encoding(UTF-8)', $output_file or die "Cannot create output: $!\n";

# Report header
my $date = strftime("%d %B %Y", localtime);
print $out "# EU Open Digital Ecosystems Consultation\n\n";
print $out "## Analysis of Responses to Consultation Questions\n\n";
print $out "**Analysis Date:** $date\n\n";

# Get corpus stats
my $total_responses = $dbh->selectrow_array("SELECT COUNT(*) FROM responses");
my ($total_stakeholders) = $dbh->selectrow_array("SELECT COUNT(DISTINCT user_type) FROM responses WHERE user_type IS NOT NULL");
my ($total_countries) = $dbh->selectrow_array("SELECT COUNT(DISTINCT country) FROM responses WHERE country IS NOT NULL");

print $out "**Corpus Overview:**\n\n";
print $out "- Total responses: $total_responses\n";
print $out "- Stakeholder types: $total_stakeholders\n";
print $out "- Countries represented: $total_countries\n\n";

# Question 1: Strengths, weaknesses, and barriers
print $out "## Question 1: Strengths and Weaknesses of EU Open-Source Sector\n\n";
print $out "**Question:** What are the strengths and weaknesses of the EU open-source sector? What are the main barriers that hamper (i) adoption and maintenance of high-quality and secure open source (ii) sustainable contributions to open-source communities?\n\n";

analyze_question_1($dbh, $out);

# Question 2: Added value
print $out "## Question 2: Added Value of Open Source\n\n";
print $out "**Question:** What is the added value of open source for the public and private sectors? Please provide concrete examples, including the factors that are most important to assess the added value.\n\n";

analyze_question_2($dbh, $out);

# Question 3: EU-level measures
print $out "## Question 3: Concrete Measures and Actions at EU Level\n\n";
print $out "**Question:** What concrete measures and actions may be taken at EU level to support the development and growth of the EU open-source sector and contribute to the EU's technological sovereignty and cybersecurity agenda?\n\n";

analyze_question_3($dbh, $out);

# Question 4: Technology priorities
print $out "## Question 4: Technology Areas to Prioritise\n\n";
print $out "**Question:** What technology areas should be prioritised and why?\n\n";

analyze_question_4($dbh, $out);

# Question 5: Sectors for increased use
print $out "## Question 5: Sectors for Increased Open Source Use\n\n";
print $out "**Question:** In what sectors could an increased use of open source lead to increased competitiveness and cyber resilience?\n\n";

analyze_question_5($dbh, $out);

close $out;
$dbh->disconnect;

print "Analysis complete: $output_file\n";

# Question 1 Analysis
sub analyze_question_1 {
    my ($dbh, $out) = @_;
    
    print $out "### Key Themes Identified\n\n";
    
    # Barriers mentioned
    my $barriers = $dbh->selectall_arrayref(q{
        SELECT word, total_count, document_count
        FROM word_frequency
        WHERE word IN ('procurement', 'funding', 'maintenance', 'skills', 'lock-in', 
                       'vendor-lock', 'vendor', 'barriers', 'challenges', 'obstacles',
                       'proprietary', 'dependencies', 'dependency')
        ORDER BY total_count DESC
    });
    
    print $out "**Barriers and Challenges Mentioned:**\n\n";
    print $out "\\begin{longtable}{lrr}\n";
    print $out "\\toprule\n";
    print $out "Barrier Term & Mentions & Documents \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{3}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Barrier Term & Mentions & Documents \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$barriers) {
        printf $out "%s & %d & %d \\\\\n", latex_escape($row->[0]), $row->[1], $row->[2];
    }
    print $out "\\end{longtable}\n\n";
    
    # Strengths mentioned
    my $strengths = $dbh->selectall_arrayref(q{
        SELECT word, total_count, document_count
        FROM word_frequency
        WHERE word IN ('community', 'innovation', 'transparency', 'security', 
                       'quality', 'flexibility', 'interoperability', 'collaboration',
                       'developers', 'expertise', 'ecosystem')
        ORDER BY total_count DESC
    });
    
    print $out "**Strengths Highlighted:**\n\n";
    print $out "\\begin{longtable}{lrr}\n";
    print $out "\\toprule\n";
    print $out "Strength Term & Mentions & Documents \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{3}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Strength Term & Mentions & Documents \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$strengths) {
        printf $out "%s & %d & %d \\\\\n", latex_escape($row->[0]), $row->[1], $row->[2];
    }
    print $out "\\end{longtable}\n\n";
    
    # Stakeholder perspectives
    print $out "### Stakeholder Perspectives\n\n";
    
    my $by_stakeholder = $dbh->selectall_arrayref(q{
        SELECT user_type, COUNT(*) as responses
        FROM responses
        WHERE user_type IS NOT NULL
        GROUP BY user_type
        ORDER BY COUNT(*) DESC
    });
    
    print $out "Responses by stakeholder type:\n\n";
    print $out "\\begin{longtable}{lr}\n";
    print $out "\\toprule\n";
    print $out "Stakeholder Type & Responses \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{2}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Stakeholder Type & Responses \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$by_stakeholder) {
        printf $out "%s & %d \\\\\n", latex_escape($row->[0]), $row->[1];
    }
    print $out "\\end{longtable}\n\n";
}

# Question 2 Analysis
sub analyze_question_2 {
    my ($dbh, $out) = @_;
    
    print $out "### Value Factors Mentioned\n\n";
    
    my $value_factors = $dbh->selectall_arrayref(q{
        SELECT word, total_count, document_count,
               ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct_docs
        FROM word_frequency
        WHERE word IN ('cost', 'savings', 'risk', 'lock-in', 'security', 'innovation',
                       'transparency', 'control', 'independence', 'flexibility',
                       'interoperability', 'sovereignty', 'resilience', 'quality',
                       'competitive', 'competitiveness', 'value')
        ORDER BY total_count DESC
    });
    
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Value Factor & Mentions & Documents & \\% Docs \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{4}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Value Factor & Mentions & Documents & \\% Docs \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$value_factors) {
        printf $out "%s & %d & %d & %.1f\\%% \\\\\n", 
            latex_escape($row->[0]), $row->[1], $row->[2], $row->[3];
    }
    print $out "\\end{longtable}\n\n";
    
    # Public vs Private sector mentions
    print $out "### Public vs Private Sector Context\n\n";
    
    my $public_count = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM response_words WHERE word = 'public'"
    );
    my $private_count = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM response_words WHERE word = 'private'"
    );
    
    print $out "- Public sector mentions: $public_count\n";
    print $out "- Private sector mentions: $private_count\n\n";
}

# Question 3 Analysis
sub analyze_question_3 {
    my ($dbh, $out) = @_;
    
    print $out "### Proposed Measures and Actions\n\n";
    
    my $measures = $dbh->selectall_arrayref(q{
        SELECT word, total_count, document_count
        FROM word_frequency
        WHERE word IN ('funding', 'support', 'investment', 'procurement', 'standards',
                       'regulation', 'policy', 'governance', 'framework', 'certification',
                       'infrastructure', 'education', 'training', 'awareness',
                       'coordination', 'collaboration', 'partnership')
        ORDER BY total_count DESC
    });
    
    print $out "\\begin{longtable}{lrr}\n";
    print $out "\\toprule\n";
    print $out "Measure/Action Term & Mentions & Documents \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{3}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Measure/Action Term & Mentions & Documents \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$measures) {
        printf $out "%s & %d & %d \\\\\n", latex_escape($row->[0]), $row->[1], $row->[2];
    }
    print $out "\\end{longtable}\n\n";
    
    # Sovereignty and cybersecurity context
    print $out "### Sovereignty and Cybersecurity Context\n\n";
    
    my $sovereignty_docs = $dbh->selectrow_array(
        "SELECT COUNT(DISTINCT response_id) FROM response_words WHERE word IN ('sovereignty', 'sovereign')"
    );
    my $security_docs = $dbh->selectrow_array(
        "SELECT COUNT(DISTINCT response_id) FROM response_words WHERE word IN ('security', 'cybersecurity')"
    );
    
    print $out "- Responses mentioning sovereignty: $sovereignty_docs\n";
    print $out "- Responses mentioning security/cybersecurity: $security_docs\n\n";
}

# Question 4 Analysis
sub analyze_question_4 {
    my ($dbh, $out) = @_;
    
    print $out "### Technology Areas Mentioned\n\n";
    
    my $technologies = $dbh->selectall_arrayref(q{
        SELECT word, total_count, document_count,
               ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct_docs
        FROM word_frequency
        WHERE word IN ('cloud', 'cybersecurity', 'security', 'artificial', 'intelligence',
                       'hardware', 'automotive', 'manufacturing', 'iot', 'internet',
                       'edge', 'network', 'data', 'infrastructure', 'blockchain',
                       'quantum', 'operating', 'systems', 'containers', 'kubernetes')
        ORDER BY total_count DESC
    });
    
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Technology Area & Mentions & Documents & \\% Docs \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{4}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Technology Area & Mentions & Documents & \\% Docs \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$technologies) {
        printf $out "%s & %d & %d & %.1f\\%% \\\\\n",
            latex_escape($row->[0]), $row->[1], $row->[2], $row->[3];
    }
    print $out "\\end{longtable}\n\n";
}

# Question 5 Analysis
sub analyze_question_5 {
    my ($dbh, $out) = @_;
    
    print $out "### Sectors Mentioned\n\n";
    
    my $sectors = $dbh->selectall_arrayref(q{
        SELECT word, total_count, document_count,
               ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct_docs
        FROM word_frequency
        WHERE word IN ('public', 'government', 'healthcare', 'health', 'education',
                       'finance', 'banking', 'transport', 'energy', 'telecommunications',
                       'automotive', 'manufacturing', 'agriculture', 'defence', 'military',
                       'research', 'academic', 'administration')
        ORDER BY total_count DESC
    });
    
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Sector & Mentions & Documents & \\% Docs \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{4}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Sector & Mentions & Documents & \\% Docs \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$sectors) {
        printf $out "%s & %d & %d & %.1f\\%% \\\\\n",
            latex_escape($row->[0]), $row->[1], $row->[2], $row->[3];
    }
    print $out "\\end{longtable}\n\n";
    
    # Competitiveness and resilience
    print $out "### Competitiveness and Resilience Context\n\n";
    
    my $competitiveness_docs = $dbh->selectrow_array(
        "SELECT COUNT(DISTINCT response_id) FROM response_words WHERE word IN ('competitive', 'competitiveness')"
    );
    my $resilience_docs = $dbh->selectrow_array(
        "SELECT COUNT(DISTINCT response_id) FROM response_words WHERE word = 'resilience'"
    );
    
    print $out "- Responses mentioning competitiveness: $competitiveness_docs\n";
    print $out "- Responses mentioning resilience: $resilience_docs\n\n";
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
