[!CAUTION] UNDER CONSTRUCTION > This pipeline is currently under active development. Features, parameters, and subworkflows are subject to change.

Overview

This Nextflow pipeline is designed for modular genomic analysis across multiple sequencing platforms. It supports automated database setup, quality control, assembly metrics, AMR (Antimicrobial Resistance) gene detection, and consolidated reporting.
Features

    Multi-Platform Support: Dedicated workflows for ONT, Illumina, and specialized protocols.

    Automated DB Management: Built-in routine to initialize and configure required databases (AMRFinder, Bakta, PlasmidFinder).

    Consolidated Reporting: Generates HTML summaries of AMR findings and comprehensive run reports.

```mermaid
flowchart LR

%% --- STYLING ---
classDef nodeStyle fill:#ffffff,stroke:#1e293b,stroke-width:2px,color:#1e293b,rx:4,ry:4;
classDef mainNode fill:#ffffff,stroke:#1e293b,stroke-width:4px,color:#1e293b,rx:10,ry:10;
classDef condNode fill:#fff7ed,stroke:#f97316,stroke-width:2px,color:#9a3412,rx:4,ry:4;

%% --- NODES ---
subgraph INPUTS
    direction TB
    inp_sheet("<b>Sample Sheet</b>"):::nodeStyle
    inp_fastq("<b>FASTQs</b>"):::nodeStyle
    mode_select{{"<b>MODE SELECTION</b>"}}:::mainNode
end

subgraph QC ["QUALITY CONTROL"]
    direction TB
    ont_qc("<b>fastplong</b><br/>Long Reads QC"):::nodeStyle
    iln_qc("<b>fastp</b><br/>Short Reads QC"):::nodeStyle
end

subgraph ONT ["ONT PIPELINE"]
    direction LR
    ont_asm("<b>Flye</b><br/>De novo Assembly"):::nodeStyle
    ont_med("<b>Medaka</b><br/>Long Read Polish"):::nodeStyle
end

subgraph ILN ["ILN PIPELINE"]
    iln_asm("<b>Shovill</b><br/>De novo Assembly"):::nodeStyle
end

subgraph HYBRID ["HYBRID POLISH"]
    direction LR
    subgraph H_ASM ["HYBRID ASSEMBLY"]
        direction TB
        sp_asm("<b>Flye</b><br/>Hybrid SP Assembly"):::nodeStyle
        lp_asm("<b>Unicycler</b><br/>Hybrid LP Assembly"):::nodeStyle
    end
    hyb_med("<b>Medaka</b><br/>Long Read Polish"):::nodeStyle
    hyb_bwa("<b>BWA MEM2</b><br/>Short Read Align"):::nodeStyle
    hyb_poly("<b>Polypolish</b><br/>Short Read Polish"):::nodeStyle
end

subgraph DOWNSTREAM ["DOWNSTREAM ANALYSIS"]
    direction TB
    final_node("<b>Final Assembly</b>"):::nodeStyle
    
    subgraph TOOLS ["ANALYSIS TOOLS"]
        direction LR
        t1("<b>QUAST</b><br/>Metrics"):::nodeStyle
        t2("<b>Bakta</b><br/>Annotation"):::nodeStyle
        t3("<b>MLST</b><br/>Typing"):::nodeStyle
        t4("<b>rMLST</b><br/>Species ID"):::nodeStyle
        t5("<b>PlasmidFinder</b><br/>Plasmids"):::nodeStyle
        t6("<b>MOB-suite</b><br/>Mobility"):::nodeStyle
        t7("<b>AMRFinderPlus</b><br/>ARGs/VGs"):::nodeStyle
        t8("<b>VirulenceFinder</b><br/>Listeria, E.coli, S.aureus, Entero.<br/>E.faecalis/faecium"):::condNode
    end
end

subgraph OUTPUTS
    direction TB
    pub("<b>Results Publisher</b>"):::nodeStyle
    rep_fin("<b>FINAL REPORT</b>"):::nodeStyle
end

%% --- CONNECTIONS ---
mode_select --> ont_qc & iln_qc

%% Blue: Long Reads
ont_qc --> ont_asm
ont_qc --> sp_asm
ont_qc --> lp_asm
ont_qc --> hyb_med

%% Red: Short Reads
iln_qc --> iln_asm
iln_qc --> sp_asm
iln_qc --> lp_asm
iln_qc --> hyb_bwa

%% Yellow: Draft Assembly & LP Polish
ont_asm --> ont_med
sp_asm --> hyb_med
lp_asm --> hyb_med
hyb_med --> hyb_bwa
hyb_med --> hyb_poly

%% Black: SR Align to Polish
hyb_bwa --> hyb_poly

%% Green: Final Assembly
ont_med --> final_node
iln_asm --> final_node
hyb_poly --> final_node
final_node --> t1 & t2 & t3 & t4 & t5 & t6 & t7 & t8

%% Orange: Species Logic
t4 -- "Species Info" --> t7
t4 -- "Match Filter" --> t8

%% Black: Outputs
t1 & t2 & t3 & t4 & t5 & t6 & t7 & t8 --> pub
pub --> rep_fin

%% --- LINK COLORS (GITHUB ONLY SUPPORTS BASIC STYLING) ---
linkStyle 2,3,4,5 stroke:#2563eb,stroke-width:2px;
linkStyle 6,7,8,9 stroke:#dc2626,stroke-width:2px;
linkStyle 10,11,12,13,14 stroke:#eab308,stroke-width:2px;
linkStyle 16,17,18,19,20,21,22,23,24,25,26 stroke:#16a34a,stroke-width:3px;
linkStyle 27,28 stroke:#f97316,stroke-width:2px;
```
