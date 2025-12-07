const fs = require('fs');
const path = require('path');

// Ελέγχουμε αν έχουμε 4 ορίσματα πλέον (προστέθηκε το versions file)
const args = process.argv.slice(2);
if (args.length < 3) {
    console.error('Usage: node generate_html.js <BASE_DIR> <JSON_DATA> <STATS_JSON> [VERSIONS_FILE]');
    if (args.length < 3) process.exit(1);
}

const [BASE_DIR, JSON_DATA, STATS_JSON, VERSIONS_FILE] = args;

try {
    const reportData = JSON.parse(fs.readFileSync(JSON_DATA, 'utf8'));
    const stats = JSON.parse(fs.readFileSync(STATS_JSON, 'utf8'));
    
    // Διαβάζουμε το αρχείο Versions αν υπάρχει
    let versionsText = "";
    if (VERSIONS_FILE && fs.existsSync(VERSIONS_FILE)) {
        versionsText = fs.readFileSync(VERSIONS_FILE, 'utf8');
    }
    
    const { htmlContent, expectedIdx, detectedIdx, genomeLenIdx } = createAdvancedHTML(reportData, stats, versionsText);
    
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
        return { htmlContent: generateHtmlTemplate('', '', emptyStats, -1, -1, -1, versionsText), expectedIdx: -1, detectedIdx: -1, genomeLenIdx: -1 };
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

    const expectedIdx = dataKeys.findIndex(k => k.toLowerCase().includes("expected organism") || k.toLowerCase().includes("expected"));
    const detectedIdx = dataKeys.findIndex(k => k.toLowerCase().includes("detected organism") || k.toLowerCase().includes("detected"));
    const genomeLenIdx = dataKeys.findIndex(k => k.toLowerCase().includes("genome length") || k.toLowerCase().includes("genome size"));
    
    // Find Q30 index (matches "Q30%")
    const q30Idx = dataKeys.findIndex(k => k.toLowerCase().includes("q30"));

    const tableHeaders = dataKeys.map(col => {
        const niceName = headerMap[col] || col;
        return `<th>${escapeHtml(niceName)}</th>`;
    }).join('');

    const tableRows = reportData.map(row => {
        const cells = Object.values(row).map(cell => `<td>${escapeHtml(cell)}</td>`).join('');
        return `<tr>${cells}</tr>`;
    }).join('');

    return { 
        htmlContent: generateHtmlTemplate(tableHeaders, tableRows, stats, expectedIdx, detectedIdx, genomeLenIdx, q30Idx, versionsText),
        expectedIdx,
        detectedIdx,
        genomeLenIdx
    };
}

function generateHtmlTemplate(tableHeaders, tableRows, stats, expectedIdx, detectedIdx, genomeLenIdx, q30Idx, versionsText) {
    
    // --- Generate Versions List HTML ---
    let versionsHtml = '';
    if (versionsText) {
        const lines = versionsText.split('\n').filter(line => line.trim() !== '' && !line.includes('Software & Database Versions'));
        versionsHtml = lines.map(line => {
            const parts = line.split(':');
            if (parts.length > 1) {
                const toolName = parts.shift().trim();
                const versionInfo = parts.join(':').trim();
                return `<li><strong>${escapeHtml(toolName)}:</strong> ${escapeHtml(versionInfo)}</li>`;
            } else {
                return `<li>${escapeHtml(line)}</li>`;
            }
        }).join('');
    } else if (stats.versions && Object.keys(stats.versions).length > 0) {
        // Fallback αν χρησιμοποιούμε το stats object (παλιά μέθοδος)
        for (const [tool, ver] of Object.entries(stats.versions)) {
            const toolName = tool.charAt(0).toUpperCase() + tool.slice(1);
            versionsHtml += `<li><strong>${escapeHtml(toolName)}:</strong> ${escapeHtml(ver)}</li>`;
        }
    }

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
            --primary-color: #2c3e50;
            --secondary-color: #3498db;
            --success-color: #27ae60;
            --warning-color: #e67e22; 
            --danger-color: #c0392b; 
            --light-bg: #f8f9fa;
            --text-color: #333;
            --border-color: #dee2e6;
        }
        body { font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; background-color: var(--light-bg); color: var(--text-color); margin: 0; padding: 20px; }
        .container { max-width: 100%; margin: 0 auto; background: white; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); padding: 20px; }
        
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 2px solid var(--secondary-color); }
        
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .stat-card { background: linear-gradient(135deg, var(--primary-color), var(--secondary-color)); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; margin: 10px 0; }
        .stat-label { font-size: 0.9em; opacity: 0.9; }
        
        .dataTables_wrapper { margin-top: 20px; }
        table.dataTable { width: 100% !important; margin: 0 auto !important; font-size: 0.9em; }
        table.dataTable tbody td, table.dataTable thead th { padding: 6px 8px !important; text-align: right !important; vertical-align: middle; }

        .dt-filter-select { padding: 2px 4px; margin-top: 4px; border: 1px solid #ccc; border-radius: 3px; font-size: 0.85em; width: 100%; max-width: 150px; height: 26px; background-color: #fff; display: block; margin-left: auto; }
        div.dataTables_filter { margin-bottom: 10px; }
        div.dataTables_filter input { border: 1px solid var(--border-color); border-radius: 4px; padding: 5px; margin-left: 5px; }
        
        table.dataTable.dtr-inline.collapsed > tbody > tr > td.dtr-control:before { background-color: var(--secondary-color); }
        
        .status-ok { background-color: #e6fffa !important; font-weight: bold; }
        .status-warning { background-color: #fff8e1 !important; font-weight: bold; }
        .status-critical { background-color: #ffe6e6 !important; font-weight: bold; }
        .text-red-alert { color: var(--danger-color) !important; font-weight: bold; }

        table.dataTable tbody tr.failed-sample-row { background-color: #ffe6e6 !important; }

        .circular-badge { display: inline-block; padding: 2px 6px; border-radius: 10px; font-size: 0.8em; font-weight: bold; }
        .circular-yes { background-color: var(--success-color); color: white; }
        .circular-no { background-color: #95a5a6; color: white; }
        
        /* Child Row Styles */
        table.dataTable > tbody > tr.child > td.child { padding: 20px !important; background-color: #fcfcfc; }
        .child-details-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 15px; width: 100%; text-align: left; }
        .detail-item { background: white; border: 1px solid #eee; border-radius: 6px; padding: 10px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
        .detail-label { font-size: 0.75em; text-transform: uppercase; color: #7f8c8d; margin-bottom: 4px; font-weight: bold; letter-spacing: 0.5px; }
        .detail-value { font-size: 0.95em; color: #2c3e50; word-wrap: break-word; }
        
        td.arg-list, td.point-mut-list { max-width: 200px; white-space: normal; font-size: 0.85em; line-height: 1.2; }

        .footer-legend { margin-top: 30px; padding: 15px; background-color: #f1f8ff; border-left: 5px solid var(--secondary-color); border-radius: 4px; font-size: 0.9em; text-align: left; }
        .footer-legend h4 { margin-top: 0; margin-bottom: 10px; color: var(--primary-color); }
        .footer-legend ul { margin: 0; padding-left: 20px; }
        .footer-legend li { margin-bottom: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-dna"></i> NGS Pipeline Report</h1>
            <div class="header-info">Generated: <span id="generation-date"></span></div>
        </div>
        <div class="stats-grid">
            <div class="stat-card"><div class="stat-label">TOTAL SAMPLES</div><div class="stat-value" id="total-samples">${stats.total_samples}</div></div>
            <div class="stat-card"><div class="stat-label">DEPTH >30x</div><div class="stat-value" id="depth-high">${stats.depth_high}</div></div>
            <div class="stat-card"><div class="stat-label">PLATFORM</div><div class="stat-value" id="platform-value">${stats.platform_value}</div></div>
            <div class="stat-card"><div class="stat-label">MEAN Q30</div><div class="stat-value" id="mean-q30">0.00%</div></div>
        </div>
        
        <table id="report-table" class="display">
            <thead><tr>${tableHeaders}</tr></thead>
            <tbody>${tableRows}</tbody>
        </table>

        <div class="footer-legend">
            <h4><i class="fas fa-code-branch"></i> Software & Database Versions</h4>
            <ul>${versionsHtml}</ul>

            <h4><i class="fas fa-info-circle"></i> Pipeline Tools & Parameters</h4>
            <ul>
                <li><strong>Plasmids:</strong> Identified using <em>PlasmidFinder</em>.</li>
                <li><strong>ARGs, Virulence Genes & Point Mutations:</strong> Identified using <em>AMRFinderPlus</em> (Filters: >90% Coverage, >90% Identity).</li>
                <li><strong>Detection / Identification:</strong> Species identification based on <em>rMLST</em> (Ribosomal Multilocus Sequence Typing).</li>
                ${q30Idx !== -1 ? '<li><strong>Q30%:</strong> Percentage of bases with Quality Score > 30 (filtered reads).</li>' : ''}
                <li><strong>Genome Size:</strong> Total length of assembled contigs.</li>
            </ul>
        </div>
    </div>

    <script>
        $(document).ready(function() {
            $("#generation-date").text(new Date().toLocaleString());
            
            // UPDATED COLUMNS CONFIGURATION
            // 7: N50 (Hidden)
            // 11: Largest Contig (Hidden) -> ADDED
            // 16-21: Typing results (Hidden)
            // 22: Comments (Hidden) -> ADDED
            // Note: Column 10 (GC Content) removed from here, so it stays visible.
            
            const columns_hidden_details = [7, 11, 16, 17, 18, 19, 20, 21, 22]; 
            const columns_removed = [15]; 
            const low_priority_columns = [17, 18]; 

            const EXP_IDX = ${expectedIdx};
            const DET_IDX = ${detectedIdx};
            const GENOME_LEN_IDX = ${genomeLenIdx}; 
            const Q30_IDX = ${q30Idx}; 

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
                                        '<div class="detail-value">' + col.data + '</div>' +
                                    '</div>' :
                                    '';
                            } ).join( '' );
        
                            return data ?
                                $('<div class="child-details-grid"/>').append( data ) :
                                false;
                        }
                    }
                },
                
                createdRow: function(row, data, dataIndex) {
                    if (GENOME_LEN_IDX === -1) return;
                    const genomeLengthVal = (data[GENOME_LEN_IDX] || "").toString().trim().toLowerCase();
                    if (genomeLengthVal === "" || genomeLengthVal === "0" || genomeLengthVal === "n/a") {
                        $(row).addClass('failed-sample-row');
                        $('td', row).eq(0).addClass('status-critical');
                    }
                },
                
                columnDefs: [
                    { targets: columns_removed, visible: false, searchable: false },
                    { targets: columns_hidden_details, className: 'none' }, 
                    
                    {
                        targets: [DET_IDX], 
                        createdCell: function(td, cellData, rowData, row, col) {
                            if (EXP_IDX === -1 || DET_IDX === -1) return;
                            const expected = (rowData[EXP_IDX] || "").toString().toLowerCase().trim();
                            const detected = (cellData || "").toString().toLowerCase().trim();
                            if (detected !== "" && !detected.includes(expected)) {
                                $(td).addClass('text-red-alert');
                            }
                        }
                    },
                    
                    { responsivePriority: 1, targets: 0 }, 
                    { responsivePriority: 2, targets: 1 }, 
                    { responsivePriority: 3, targets: 8 }, 
                    { responsivePriority: 4, targets: 13 }, 
                    { responsivePriority: 5, targets: 6 }, 
                    { responsivePriority: 1000, targets: low_priority_columns },

                    { targets: [4], type: "num" },
                    
                    {
                        targets: 6, // Genome Length
                        render: function(data, type) {
                            if (type === 'display') {
                                const val = parseFloat(data);
                                if (!isNaN(val) && val > 0) return (val / 1000000).toFixed(2) + " Mbps";
                                return data; 
                            } return data;
                        }
                    },
                    {
                        targets: 5,
                        render: function(data, type) {
                            if (type === 'display') {
                                const count = parseInt(data) || 0;
                                return '<span class="circular-badge circular-' + (count > 0 ? "yes" : "no") + '">' + count + '</span>';
                            } return data;
                        }
                    },
                    {
                        targets: 8,
                        createdCell: function(td, cellData) {
                            const match = (cellData || "").toString().match(/(\\d+)/);
                            const val = match ? parseInt(match[0]) : 0;
                            if (val >= 30) $(td).addClass('status-ok');
                            else if (val >= 20) $(td).addClass('status-warning');
                            else $(td).addClass('status-critical');
                        }
                    },
                    {
                        targets: Q30_IDX,
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
                        targets: 9,
                        render: function(data, type) {
                            if (type === 'display') {
                                let txt = (data || "").toString();
                                if (txt && !txt.includes('%')) { txt = txt + '%'; }
                                return txt;
                            } return data;
                        }
                    },
                    {
                        targets: 13, 
                        createdCell: function(td, cellData) {
                            const txt = (cellData || "").toString().replace('%', '');
                            const val = parseFloat(txt);
                            if (!isNaN(val) && val < 95) {
                                $(td).addClass("text-red-alert");
                            }
                        }
                    },
                    { targets: [17], className: "arg-list" },
                    { targets: [18], className: "point-mut-list" },
                    { targets: "_all", searchable: true }
                ],
                initComplete: function() {
                    const filterCols = [12, 14]; 
                    this.api().columns(filterCols).every(function() {
                        const column = this;
                        const header = $(column.header());
                        const select = $('<select class="dt-filter-select"><option value=""></option></select>')
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
                
                const depthHigh = filteredData.filter(row => { 
                    const match = (row[8] || "").match(/(\\d+)/); 
                    return match && parseInt(match[0]) > 30; 
                }).length;
                $("#depth-high").text(depthHigh);
                
                const platforms = [...new Set(filteredData.map(row => row[3]).filter(Boolean))];
                $("#platform-value").text(platforms.length > 1 ? "Mixed" : (platforms[0] || "N/A"));
                
                if (Q30_IDX !== -1) {
                    let totalQ30 = 0;
                    let countQ30 = 0;
                    filteredData.forEach(row => {
                        let val = row[Q30_IDX];
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