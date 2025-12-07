const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
if (args.length < 3) {
    console.error('Usage: node generate_html.js <BASE_DIR> <JSON_DATA> <STATS_JSON>');
    process.exit(1);
}

const [BASE_DIR, JSON_DATA, STATS_JSON] = args;

try {
    const reportData = JSON.parse(fs.readFileSync(JSON_DATA, 'utf8'));
    const stats = JSON.parse(fs.readFileSync(STATS_JSON, 'utf8'));
    
    let versionsText = ""; 
    
    const { htmlContent } = createAdvancedHTML(reportData, stats, versionsText);
    
    const outputFile = path.join(BASE_DIR, 'final_report_advanced.html');
    fs.writeFileSync(outputFile, htmlContent);
    console.log(`HTML report generated: ${outputFile}`);

} catch (error) {
    console.error('Error:', error);
    process.exit(1);
}

function createAdvancedHTML(reportData, stats, versionsText) {
    if (!reportData || reportData.length === 0) {
        const emptyStats = { total_samples: 0, depth_high: 0, platform_value: "N/A" };
        return { htmlContent: generateHtmlTemplate('', '', emptyStats, {}) };
    }

    const headerMap = {
        "Plasmid (PlasmidFinder)": "Plasmids",
        "ARGs (>90% cov, >90% ID, AMRFinderPlus)": "ARGs",
        "Virulence Genes (>90% cov, >90% ID, AMRFinderPlus)": "Virulence Genes",
        "Point_Mutations": "Point Mutations", 
        "Detection (rMLST)": "Detection",
        "Genome Length": "Genome Size",
        "Contig Number": "Contigs",
        "Q30%": "Q30%"
    };

    const dataKeys = Object.keys(reportData[0]);

    const indices = {
        expected: dataKeys.findIndex(k => k.toLowerCase().includes("expected organism") || k.toLowerCase().includes("expected")),
        detected: dataKeys.findIndex(k => k.toLowerCase().includes("detected organism") || k.toLowerCase().includes("detected")),
        genomeLen: dataKeys.findIndex(k => k.toLowerCase().includes("genome length") || k.toLowerCase().includes("genome size")),
        q30: dataKeys.findIndex(k => k.toLowerCase().includes("q30")),
        platform: dataKeys.findIndex(k => k.toLowerCase().includes("platform")),
        
        depth: dataKeys.findIndex(k => k.toLowerCase().includes("depth")),
        detection: dataKeys.findIndex(k => k.toLowerCase().includes("detection")),
        st: dataKeys.findIndex(k => k === "ST"), 
        clonal: dataKeys.findIndex(k => k.toLowerCase().includes("clonal complex")), 
        comments: dataKeys.findIndex(k => k.toLowerCase().includes("comments")), 

        n50: dataKeys.findIndex(k => k === "N50"),
        largest: dataKeys.findIndex(k => k.toLowerCase().includes("largest contig")),
        plasmids: dataKeys.findIndex(k => k.toLowerCase().includes("plasmid")),
        args: dataKeys.findIndex(k => k.toLowerCase().includes("args")),
        points: dataKeys.findIndex(k => k.toLowerCase().includes("point mutations")),
        pheno: dataKeys.findIndex(k => k.toLowerCase().includes("predicted phenotype")),
        virulence: dataKeys.findIndex(k => k.toLowerCase().includes("virulence"))
    };

    const tableHeaders = dataKeys.map(col => {
        const niceName = headerMap[col] || col;
        return `<th>${escapeHtml(niceName)}</th>`;
    }).join('');

    const tableRows = reportData.map(row => {
        const cells = Object.values(row).map(cell => `<td>${escapeHtml(cell)}</td>`).join('');
        return `<tr>${cells}</tr>`;
    }).join('');

    return { 
        htmlContent: generateHtmlTemplate(tableHeaders, tableRows, stats, indices)
    };
}

function generateHtmlTemplate(tableHeaders, tableRows, stats, idx) {
    
    let versionsHtml = '';
    if (stats.versions && Object.keys(stats.versions).length > 0) {
        versionsHtml += '<h4><i class="fas fa-code-branch"></i> Software & Database Versions</h4><ul class="version-list">';
        const sortedTools = Object.keys(stats.versions).sort();
        for (const tool of sortedTools) {
            const ver = stats.versions[tool];
            const toolName = tool.charAt(0).toUpperCase() + tool.slice(1);
            versionsHtml += `<li><span class="v-tool">${escapeHtml(toolName)}:</span> <span class="v-num">${escapeHtml(ver)}</span></li>`;
        }
        versionsHtml += '</ul><br>'; 
    }

    const indicesJSON = JSON.stringify(idx);

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NGS Pipeline Report</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/datatables/1.10.21/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/responsive/2.2.9/js/dataTables.responsive.min.js"></script>
    <script src="https://cdn.datatables.net/rowgroup/1.1.2/js/dataTables.rowGroup.min.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/datatables/1.10.21/css/jquery.dataTables.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/responsive/2.2.9/css/responsive.dataTables.min.css">
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
            box-shadow: 0 2px 15px rgba(0,0,0,0.05); /* Softer shadow */
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
        .header h1 { margin: 0; color: var(--primary-color); font-weight: 600; letter-spacing: -0.5px; }
        .header-info { color: var(--text-muted); font-weight: 500; }

        /* STATS CARDS - SWEETER BLUE */
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { 
            /* Returning to the "sweeter" blue gradient */
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color)); 
            color: white; 
            padding: 25px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 4px 6px rgba(0,0,0,0.1); /* Lighter shadow */
            border: none; /* Removed the dark border */
        }
        .stat-value { font-size: 2.0em; font-weight: 700; margin: 10px 0; } /* Reduced font size */
        .stat-label { font-size: 0.85em; text-transform: uppercase; letter-spacing: 1px; opacity: 0.9; font-weight: 600; }
        
        .stat-card.warning { 
            background: linear-gradient(135deg, #f39c12, #d35400); 
            box-shadow: 0 4px 6px rgba(211, 84, 0, 0.2);
        }

        /* DATATABLES STYLING */
        .dataTables_wrapper { margin-top: 20px; }
        table.dataTable { width: 100% !important; margin: 0 auto !important; font-size: 0.85em; border-collapse: collapse !important; }
        
        /* HEADER: Center Aligned VERTICALLY & HORIZONTALLY */
        table.dataTable thead th { 
            background-color: var(--header-bg) !important; 
            color: var(--header-text) !important; 
            padding: 12px 10px !important; 
            text-align: center !important;  
            font-weight: 700;
            border-bottom: 2px solid var(--header-border) !important;
            vertical-align: middle !important; /* Centered Vertically */
        }

        /* BODY: Right Aligned */
        table.dataTable tbody td { 
            padding: 10px 10px !important; 
            text-align: right !important; 
            border-bottom: 1px solid #eee !important; 
            color: #2c3e50;
        }
        table.dataTable tbody tr:hover { background-color: #f8f9fa !important; }
        
        /* FILTERS - BLOCK DISPLAY */
        .dt-filter-select { 
            padding: 2px; 
            margin-top: 5px; 
            border: 1px solid #bdc3c7; 
            border-radius: 3px; 
            font-size: 0.9em; 
            width: 100%;        
            display: block;     
            background-color: #fff; 
            color: #2c3e50;
        }

        /* Search Box */
        div.dataTables_filter input { 
            border: 1px solid #bdc3c7; 
            border-radius: 4px; 
            padding: 2px 8px; 
            margin-left: 12px; 
            height: 26px; 
            font-size: 0.9em;
            width: 200px;
        }

        /* Status Badges */
        .status-ok { background-color: #d4edda !important; color: #155724; padding: 4px 8px; border-radius: 4px; font-weight: 700; border: 1px solid #c3e6cb; }
        .status-warning { background-color: #fff3cd !important; color: #856404; padding: 4px 8px; border-radius: 4px; font-weight: 700; border: 1px solid #ffeeba; }
        .status-critical { background-color: #f8d7da !important; color: #721c24; padding: 4px 8px; border-radius: 4px; font-weight: 700; border: 1px solid #f5c6cb; }
        .text-red-alert { color: #c0392b !important; font-weight: 800; }

        table.dataTable tbody tr.failed-sample-row { background-color: #fff5f5 !important; }

        /* Child Row */
        table.dataTable > tbody > tr.child > td.child { padding: 25px !important; background-color: #f8f9fa !important; border-top: 3px solid var(--secondary-color); text-align: left !important; }
        .child-details-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; width: 100%; text-align: left; }
        .detail-item { background: white; border: 1px solid #e1e4e8; border-radius: 6px; padding: 15px; box-shadow: 0 2px 5px rgba(0,0,0,0.03); }
        .detail-label { font-size: 0.8em; text-transform: uppercase; color: #7f8c8d; margin-bottom: 6px; font-weight: 700; letter-spacing: 0.5px; border-bottom: 1px solid #eee; padding-bottom: 4px; display: block; }
        .detail-value { font-size: 1em; color: var(--text-main); word-wrap: break-word; line-height: 1.4; font-weight: 500; margin-top: 5px; }

        td.arg-list, td.point-mut-list { max-width: 220px; white-space: normal; font-size: 0.9em; line-height: 1.3; }

        /* Footer */
        .footer-legend { margin-top: 40px; padding: 20px; background-color: #f8f9fa; border-left: 5px solid var(--primary-color); border-radius: 6px; font-size: 0.95em; text-align: left; color: var(--text-main); }
        .footer-legend h4 { margin-top: 0; margin-bottom: 12px; color: var(--primary-color); font-weight: 700; }

        .version-list { list-style: none; padding: 0 !important; display: flex; flex-wrap: wrap; gap: 15px; }
        .version-list li { background: white; padding: 6px 12px; border-radius: 4px; border: 1px solid #bdc3c7; font-size: 0.9em; font-weight: 500; }
        .v-tool { font-weight: 700; color: var(--primary-color); }

        /* Plus icon */
        table.dataTable.dtr-inline.collapsed > tbody > tr > td.dtr-control:before {
            background-color: var(--secondary-color);
            border: none;
            box-shadow: none;
            color: white;
            font-weight: bold;
            line-height: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-dna"></i> NGS Pipeline Report</h1>
            <div class="header-info">Generated: <span id="generation-date"></span></div>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">TOTAL SAMPLES</div>
                <div class="stat-value" id="total-samples">${stats.total_samples}</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">DEPTH >30x</div>
                <div class="stat-value" id="depth-high">${stats.depth_high}</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">PLATFORM</div>
                <div class="stat-value" id="platform-value">${stats.platform_value}</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">MEAN Q30</div>
                <div class="stat-value" id="mean-q30">0.00%</div>
            </div>
            <div class="stat-card warning">
                <div class="stat-label">QC WARNINGS</div>
                <div class="stat-value" id="qc-warnings">0</div>
            </div>
        </div>
        
        <table id="report-table" class="display hover stripe order-column">
            <thead><tr>${tableHeaders}</tr></thead>
            <tbody>${tableRows}</tbody>
        </table>

        <div class="footer-legend">
            ${versionsHtml}

            <h4><i class="fas fa-info-circle"></i> Pipeline Tools & Parameters</h4>
            <ul>
                <li><strong>QC Status:</strong> Automatic check for Low Depth (<30x), Low Identity (<95%), or Unexpected Organism.</li>
                <li><strong>Plasmids:</strong> Identified using <em>PlasmidFinder</em>.</li>
                <li><strong>ARGs, Virulence & Mutations:</strong> <em>AMRFinderPlus</em> (Filters: >90% Coverage, >90% Identity).</li>
                <li><strong>Identification:</strong> Species identification based on <em>rMLST</em>.</li>
                ${idx.q30 !== -1 ? '<li><strong>Q30%:</strong> Percentage of bases with Quality Score > 30 (filtered reads).</li>' : ''}
                <li><strong>Genome Size:</strong> Total length of assembled contigs.</li>
            </ul>
        </div>
    </div>

    <script>
        $(document).ready(function() {
            $("#generation-date").text(new Date().toLocaleString());
            
            const IDX = ${indicesJSON};

            const columns_removed = [];
            if (IDX.platform !== -1) columns_removed.push(IDX.platform);
            if (IDX.clonal !== -1) columns_removed.push(IDX.clonal); 

            const columns_hidden_details = [];
            if (IDX.n50 !== -1) columns_hidden_details.push(IDX.n50);
            if (IDX.largest !== -1) columns_hidden_details.push(IDX.largest);
            if (IDX.plasmids !== -1) columns_hidden_details.push(IDX.plasmids);
            if (IDX.args !== -1) columns_hidden_details.push(IDX.args);
            if (IDX.points !== -1) columns_hidden_details.push(IDX.points);
            if (IDX.pheno !== -1) columns_hidden_details.push(IDX.pheno);
            if (IDX.virulence !== -1) columns_hidden_details.push(IDX.virulence);
            
            if (IDX.comments !== -1) columns_hidden_details.push(IDX.comments);

            const table = $("#report-table").DataTable({
                pageLength: 25,
                lengthMenu: [10, 25, 50, 100],
                order: [[0, "asc"]],
                searching: true, 
                dom: 'lfrtip', 
                autoWidth: false, 
                
                responsive: {
                    details: {
                        renderer: function ( api, rowIdx, columns ) {
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
                
                createdRow: function(row, data, dataIndex) {
                    if (IDX.genomeLen !== -1) {
                        const val = (data[IDX.genomeLen] || "").toString().trim().toLowerCase();
                        if (val === "" || val === "0" || val === "n/a") {
                            $(row).addClass('failed-sample-row');
                        }
                    }
                },
                
                columnDefs: [
                    { targets: columns_removed, visible: false, searchable: true },
                    { targets: columns_hidden_details, className: 'none' },
                    
                    {
                        targets: [IDX.detected], 
                        createdCell: function(td, cellData, rowData, row, col) {
                            if (IDX.expected === -1 || IDX.detected === -1) return;
                            const expected = (rowData[IDX.expected] || "").toString().toLowerCase().trim();
                            const detected = (cellData || "").toString().toLowerCase().trim();
                            if (detected !== "" && !detected.includes(expected)) {
                                $(td).addClass('text-red-alert');
                                $(td).html('<i class="fas fa-times-circle"></i> ' + cellData);
                            }
                        }
                    },
                    
                    { responsivePriority: 1, targets: 0 }, 
                    { responsivePriority: 2, targets: 1 }, 
                    { responsivePriority: 5, targets: 6 }, 
                    { targets: [4], type: "num" }, 
                    
                    {
                        targets: IDX.genomeLen, 
                        render: function(data, type) {
                            if (type === 'display') {
                                const val = parseFloat(data);
                                if (!isNaN(val) && val > 0) return (val / 1000000).toFixed(2) + " Mb";
                                return data; 
                            } return data;
                        }
                    },
                    {
                        targets: IDX.depth, 
                        createdCell: function(td, cellData) {
                            const match = (cellData || "").toString().match(/(\\d+)/);
                            const val = match ? parseInt(match[0]) : 0;
                            if (val >= 30) $(td).addClass('status-ok');
                            else if (val >= 20) $(td).addClass('status-warning');
                            else $(td).addClass('status-critical');
                        }
                    },
                    {
                        targets: IDX.q30,
                        render: function(data, type) {
                            if (type === 'display' && data) {
                                let txt = data.toString();
                                if (!txt.includes('%')) txt += '%';
                                return txt;
                            }
                            return data;
                        }
                    },
                    {
                        targets: IDX.detection, 
                        createdCell: function(td, cellData) {
                            const txt = (cellData || "").toString().replace('%', '');
                            const val = parseFloat(txt);
                            if (!isNaN(val) && val < 95) {
                                $(td).addClass("text-red-alert");
                            }
                        }
                    },
                    { targets: [IDX.args], className: "arg-list" },
                    { targets: [IDX.points], className: "point-mut-list" },
                    { targets: "_all", searchable: true }
                ],
                initComplete: function() {
                    const filterCols = [];
                    if (IDX.detected !== -1) filterCols.push(IDX.detected);
                    if (IDX.st !== -1) filterCols.push(IDX.st);

                    this.api().columns(filterCols).every(function() {
                        const column = this;
                        const header = $(column.header());
                        const select = $('<select class="dt-filter-select"><option value="">All</option></select>')
                            .appendTo(header)
                            .on("change", function() {
                                const val = $.fn.dataTable.util.escapeRegex($(this).val());
                                column.search(val ? "^" + val + "$" : "", true, false).draw();
                                updateStats();
                            });
                        column.data().unique().sort().each(function(d) {
                            if (d) { select.append('<option value="' + d + '">' + d + '</option>'); }
                        });
                        $('select', header).on('click', function(e) { e.stopPropagation(); });
                    });
                }
            });
            
            function updateStats() {
                const filteredData = table.rows({ search: "applied" }).data().toArray();
                $("#total-samples").text(filteredData.length);
                
                let depthCount = 0;
                let qcWarnings = 0;
                
                filteredData.forEach(row => {
                    let isBad = false;
                    
                    if (IDX.depth !== -1) {
                        const dMatch = (row[IDX.depth] || "").toString().match(/(\\d+)/);
                        if (dMatch) {
                            if (parseInt(dMatch[0]) > 30) depthCount++;
                            if (parseInt(dMatch[0]) < 30) isBad = true;
                        }
                    }
                    
                    if (IDX.detection !== -1) {
                        const detVal = parseFloat((row[IDX.detection] || "").toString().replace('%',''));
                        if (!isNaN(detVal) && detVal < 95) isBad = true;
                    }

                    if (IDX.expected !== -1 && IDX.detected !== -1) {
                        const expected = (row[IDX.expected] || "").toString().toLowerCase().trim();
                        const detected = (row[IDX.detected] || "").toString().toLowerCase().trim();
                        if (detected !== "" && !detected.includes(expected)) isBad = true;
                    }
                    
                    if (isBad) qcWarnings++;
                });
                
                $("#depth-high").text(depthCount);
                $("#qc-warnings").text(qcWarnings);
                
                if (IDX.platform !== -1) {
                    const platforms = [...new Set(filteredData.map(row => row[IDX.platform]).filter(Boolean))];
                    $("#platform-value").text(platforms.length > 1 ? "Mixed" : (platforms[0] || "N/A"));
                }
                
                if (IDX.q30 !== -1) {
                    let totalQ30 = 0;
                    let countQ30 = 0;
                    filteredData.forEach(row => {
                        let val = row[IDX.q30];
                        if (val) {
                            val = parseFloat(val.toString().replace('%', ''));
                            if (!isNaN(val)) {
                                totalQ30 += val;
                                countQ30++;
                            }
                        }
                    });
                    if (countQ30 > 0) {
                        let avg = totalQ30 / countQ30;
                        $("#mean-q30").text(avg.toFixed(2) + "%");
                    } else {
                        $("#mean-q30").text("N/A");
                    }
                }
            }
            updateStats();
        });
    </script>
</body>
</html>`;
}

function escapeHtml(text) { 
    if (text == null) return ''; 
    return text.toString()
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;'); 
}