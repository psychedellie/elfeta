#!/bin/bash

# Initialize variables
FILE_LIST=()
mkdir -p Results/AMRFinderPlus
OUTPUT_FILE=""

# --- Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --files)
            shift
            while [[ "$#" -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
                FILE_LIST+=("$1")
                shift
            done
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift
            shift
            ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
done

if [ ${#FILE_LIST[@]} -eq 0 ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Must provide --files and --output."
    exit 1
fi

# Columns to exclude entirely (never shown in HTML)
excluded_columns=("Protein identifier" "Strand" "Sequence name" "Target length" "Reference sequence length" "HMM id" "HMM description" "HMM accession" "Protein id")

# --- HTML Generation Start ---

cat <<'EOF' > "$OUTPUT_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AMRFinderPlus Report</title>
    
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/datatables/1.10.21/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/responsive/2.2.9/js/dataTables.responsive.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.2.2/js/dataTables.buttons.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.1.3/jszip.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.2.2/js/buttons.html5.min.js"></script>
    
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/datatables/1.10.21/css/jquery.dataTables.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/responsive/2.2.9/css/responsive.dataTables.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.2.2/css/buttons.dataTables.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">

    <style>
        :root {
            /* REFINED THEME: Less Black, Softer Blue */
            --bg-body: #f4f6f8;        
            --bg-card: #ffffff;        
            
            --primary-color: #34495e;  /* Softer Slate */
            --secondary-color: #3498db;/* Classic Blue */
            
            /* Table Header Colors */
            --header-bg: #e9ecef;      
            --header-text: #2c3e50;    
            --header-border: #bdc3c7;  
            
            --text-main: #2c3e50;
            --text-muted: #7f8c8d;
            
            --border-color: #dfe6e9;
        }

        body { 
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; 
            background-color: var(--bg-body); 
            color: var(--text-main); 
            margin: 0; 
            padding: 25px; 
        }

        .container { 
            max-width: 98%; 
            margin: 0 auto; 
            background: var(--bg-card); 
            border-radius: 8px; 
            box-shadow: 0 2px 15px rgba(0,0,0,0.05); 
            padding: 25px; 
            border: 1px solid #e1e4e8;
        }
        
        /* HEADER */
        .header { 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            margin-bottom: 30px; 
            padding-bottom: 15px; 
            border-bottom: 2px solid var(--secondary-color);
        }
        .header h1 { margin: 0; color: var(--primary-color); font-weight: 600; font-size: 1.8rem; letter-spacing: -0.5px; }
        .header-info { color: var(--text-muted); font-weight: 500; }

        /* STATS CARDS - SWEETER BLUE */
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { 
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color)); 
            color: white; 
            padding: 25px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            border: none;
        }
        .stat-value { font-size: 2.0em; font-weight: 700; margin: 10px 0; } /* Reduced Font */
        .stat-label { font-size: 0.85em; text-transform: uppercase; letter-spacing: 1px; opacity: 0.9; font-weight: 600; }

        /* DATATABLES STYLING */
        .dataTables_wrapper { margin-top: 20px; }
        table.dataTable { width: 100% !important; margin: 0 auto !important; font-size: 0.85em; border-collapse: collapse !important; }
        
        /* Header: CENTER ALIGNED VERTICALLY */
        table.dataTable thead th { 
            background-color: var(--header-bg) !important; 
            color: var(--header-text) !important; 
            padding: 12px 10px !important; 
            text-align: center !important; 
            vertical-align: middle !important; /* Centered Vertically */
            font-weight: 700;
            border-bottom: 2px solid var(--header-border) !important;
        }

        /* Body: Right Aligned */
        table.dataTable tbody td { 
            padding: 10px 10px !important; 
            text-align: right !important; 
            border-bottom: 1px solid #e0e0e0 !important; 
            vertical-align: middle;
            color: #2c3e50;
        }
        table.dataTable tbody tr:hover { background-color: #f8f9fa !important; }
        
        /* EXPORT BUTTONS */
        .dt-buttons .dt-button { 
            background: var(--secondary-color) !important; 
            color: white !important; 
            border: none !important; 
            border-radius: 4px !important; 
            padding: 4px 12px !important; 
            font-size: 0.85em !important; 
            margin-right: 5px;
            font-weight: 600;
        }
        .dt-buttons .dt-button:hover { background: var(--primary-color) !important; box-shadow: 0 2px 5px rgba(0,0,0,0.2); }

        /* SLIM SEARCH BOX */
        div.dataTables_filter { margin-bottom: 10px; }
        div.dataTables_filter label { font-weight: normal; white-space: nowrap; }
        div.dataTables_filter input { 
            border: 1px solid #bdc3c7; 
            border-radius: 4px; 
            padding: 2px 8px; 
            margin-left: 12px; 
            height: 26px; 
            font-size: 0.9em;
            width: 200px;
        }

        /* CHILD ROW (DETAILS GRID) */
        table.dataTable > tbody > tr.child > td.child { padding: 25px !important; background-color: #f8f9fa !important; border-top: 3px solid var(--secondary-color); text-align: left !important; }
        .child-details-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; width: 100%; text-align: left; }
        .detail-item { background: white; border: 1px solid #e1e4e8; border-radius: 6px; padding: 15px; box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
        .detail-label { font-size: 0.8em; text-transform: uppercase; color: #7f8c8d; margin-bottom: 6px; font-weight: 700; letter-spacing: 0.5px; border-bottom: 1px solid #eee; padding-bottom: 4px; display: block; }
        .detail-value { font-size: 1em; color: var(--text-main); word-wrap: break-word; line-height: 1.4; font-weight: 500; margin-top: 5px; }

        /* Plus icon style */
        table.dataTable.dtr-inline.collapsed > tbody > tr > td.dtr-control:before {
            background-color: var(--secondary-color);
            border: none;
            box-shadow: none;
            color: white;
            font-weight: bold;
            line-height: 14px;
        }
        
        .footer-legend { margin-top: 30px; padding: 20px; background-color: #f8f9fa; border-left: 5px solid var(--secondary-color); border-radius: 6px; font-size: 0.9em; }
        .footer-legend h4 { margin-top: 0; margin-bottom: 10px; color: var(--primary-color); font-weight: 700; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-dna"></i> AMRFinderPlus Results</h1>
            <div class="header-info">Generated: <span id="generation-date"></span></div>
        </div>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">Samples</div>
                <div class="stat-value" id="stat-samples">0</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Unique Genes</div>
                <div class="stat-value" id="stat-elements">0</div>
            </div>
             <div class="stat-card">
                <div class="stat-label">Phenotypes</div>
                <div class="stat-value" id="stat-subclasses">0</div>
            </div>
        </div>

        <table id="report-table" class="display responsive nowrap hover stripe order-column" style="width:100%">
            <thead>
EOF

# 2. Dynamic Table Header Generation
# ----------------------------------
first_file="${FILE_LIST[0]}"
declare -a exclude_indices=()

if [ -f "$first_file" ]; then
    header=$(head -n 1 "$first_file")
    IFS=$'\t' read -r -a columns <<< "$header"
    
    echo "                <tr>" >> "$OUTPUT_FILE"
    echo "                    <th>Sample ID</th>" >> "$OUTPUT_FILE"
    
    for i in "${!columns[@]}"; do
        col_name="${columns[$i]}"
        
        # --- RENAME COLUMNS ---
        if [[ "$col_name" == "Contig id" ]]; then col_name="Contig"; fi
        if [[ "$col_name" == "Subclass" ]]; then col_name="Predicted Phenotype"; fi
        if [[ "$col_name" == "Element symbol" ]]; then col_name="Element"; fi
        if [[ "$col_name" == *"% Coverage"* ]]; then col_name="% Coverage"; fi
        if [[ "$col_name" == *"% Identity"* ]]; then col_name="% Identity"; fi
        # ----------------------

        # Check if column should be excluded
        if [[ ! " ${excluded_columns[@]} " =~ " ${columns[$i]} " ]]; then
            echo "                    <th>${col_name}</th>" >> "$OUTPUT_FILE"
        else
            exclude_indices+=("$i")
        fi
    done
    echo "                </tr>" >> "$OUTPUT_FILE"
fi

cat <<'EOF' >> "$OUTPUT_FILE"
            </thead>
            <tbody>
EOF

# 3. Dynamic Data Row Generation
# ----------------------------------
for file in "${FILE_LIST[@]}"; do
    filename=$(basename "$file")
    
    # --- CLEAN SAMPLE ID: Remove extension, then remove '_amrf' ---
    base="${filename%.*}"
    sample_id="${base%_amrf}"
    # -------------------------------------------------------------
    
    # Skip header row (tail -n +2)
    tail -n +2 "$file" | while IFS=$'\t' read -r -a columns; do
        echo "                <tr>" >> "$OUTPUT_FILE"
        echo "                    <td>$sample_id</td>" >> "$OUTPUT_FILE"
        
        for i in "${!columns[@]}"; do
            if [[ ! " ${exclude_indices[@]} " =~ " $i " ]]; then
                # Safe html escaping for content
                content="${columns[$i]//\"/&quot;}"
                echo "                    <td>$content</td>" >> "$OUTPUT_FILE"
            fi
        done
        echo "                </tr>" >> "$OUTPUT_FILE"
    done
done

# 4. Footer and JavaScript Logic
# ----------------------------------
cat <<'EOF' >> "$OUTPUT_FILE"
            </tbody>
        </table>

        <div class="footer-legend">
            <h4><i class="fas fa-info-circle"></i> Guide</h4>
            <p><strong>Note:</strong> Technical details (Method, Class, Alignment Length, etc.) are hidden in the main view to keep the table clean. Click the blue <strong>(+)</strong> button on the left of any row to view full details.</p>
        </div>
    </div>

    <script>
        $(document).ready(function() {
            $("#generation-date").text(new Date().toLocaleString());

            // 1. Identify Column Indices dynamically for Hiding/Stats
            var headers = $('#report-table thead th').map(function() { return $(this).text().trim().toLowerCase(); }).get();
            
            var cols_to_hide_in_child = []; // Columns to hide from main view (show in child row)
            var cols_priority = [0, 1]; // Sample ID and Element Name always visible

            // Find specific column indices
            var idx_class = -1, idx_subclass = -1, idx_element = -1, idx_type = -1, idx_scope = -1, idx_method = -1, idx_align_len = -1;
            
            headers.forEach(function(h, i) {
                // Identify columns we want to HIDE (Method, Class, Type, Scope, Alignment Length)
                if(h === 'type' || h === 'element type') idx_type = i;
                if(h === 'scope') idx_scope = i;
                if(h === 'class') idx_class = i;
                if(h === 'method') idx_method = i;
                if(h.includes('alignment length')) idx_align_len = i;
                
                // Identify columns for STATS
                if(h === 'element' || h === 'gene symbol') idx_element = i;
                if(h.includes('predicted phenotype')) idx_subclass = i;

                // Identify columns we want VISIBLE (High Priority)
                if(h.includes('predicted phenotype')) cols_priority.push(i);
                if(h.includes('coverage') || h.includes('identity')) cols_priority.push(i);
            });

            // Push all "Technical" columns to the hide list
            if(idx_type > -1) cols_to_hide_in_child.push(idx_type);
            if(idx_scope > -1) cols_to_hide_in_child.push(idx_scope);
            if(idx_class > -1) cols_to_hide_in_child.push(idx_class);
            if(idx_method > -1) cols_to_hide_in_child.push(idx_method);
            if(idx_align_len > -1) cols_to_hide_in_child.push(idx_align_len);

            // 2. Initialize DataTable
            var table = $('#report-table').DataTable({
                dom: 'Bfrtip',
                pageLength: 25,
                lengthMenu: [ [10, 25, 50, -1], [10, 25, 50, "All"] ],
                buttons: ['copyHtml5', 'excelHtml5', 'csvHtml5'],
                order: [[0, "asc"]],
                responsive: {
                    details: {
                        renderer: function ( api, rowIdx, columns ) {
                            // Custom Card Grid for child row details
                            var data = $.map( columns, function ( col, i ) {
                                return col.hidden ?
                                    '<div class="detail-item">' +
                                        '<div class="detail-label">' + col.title + '</div>' +
                                        '<div class="detail-value">' + (col.data ? col.data : '-') + '</div>' +
                                    '</div>' :
                                    '';
                            } ).join( '' );
                            return data ? $('<div class="child-details-grid"/>').append( data ) : false;
                        }
                    }
                },
                columnDefs: [
                    // The class 'none' forces the column to be hidden in table but shown in child row popup
                    { targets: cols_to_hide_in_child, className: 'none' },
                    { targets: cols_priority, responsivePriority: 1 } 
                ],
                initComplete: function() {
                    calculateStats(this.api());
                }
            });

            table.on('draw', function () {
                calculateStats(table);
            });

            function calculateStats(api) {
                // 1. Total Samples (Unique values in Col 0)
                var uniqueSamples = new Set();
                var uniqueElements = new Set();
                var uniqueSubclasses = new Set();

                api.rows({ search: 'applied' }).every(function() {
                    var d = this.data();
                    uniqueSamples.add(d[0]); 
                    
                    if(idx_element > -1) {
                         var val = d[idx_element];
                         if(val && val !== 'NA' && val !== '') uniqueElements.add(val);
                    }
                    if(idx_subclass > -1) {
                         var val = d[idx_subclass];
                         if(val && val !== 'NA' && val !== '') uniqueSubclasses.add(val);
                    }
                });

                $('#stat-samples').text(uniqueSamples.size);
                $('#stat-elements').text(uniqueElements.size);
                $('#stat-subclasses').text(uniqueSubclasses.size);
            }
        });
    </script>
</body>
</html>
EOF

echo "AMRFinderPlus HTML report generated: $OUTPUT_FILE"