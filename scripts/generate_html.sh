#!/bin/bash

# Initialize variables
FILE_LIST=()
mkdir -p Results/AMRFinderPlus
OUTPUT_FILE=""

# --- Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --files)
            # Collect all subsequent arguments until the next flag or end of arguments
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
            # Unknown parameter
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
done

if [ ${#FILE_LIST[@]} -eq 0 ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Must provide --files and --output."
    exit 1
fi

# We don't need a timestamp or folder path creation if Nextflow manages output
# The OUTPUT_FILE is the path to the file to be created in the process workdir

excluded_columns=("Protein identifier" "Strand" "Sequence name" "Target length" "Reference sequence length" "HMM id" "HMM description" "HMM accession" "Protein id")

# --- HTML Generation Start ---

cat <<EOF > "$OUTPUT_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AMR Finder + | Results</title>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>
  <style>
    body { background-color:#1b1f24; color:#e0e0e0; font-family:'Courier New',monospace; margin:20px;}
    h1 { text-align:center; font-size:2em; color:#8ab4f8; border-bottom:2px solid #8ab4f8; padding-bottom:10px; margin-bottom:30px;}
    #controls { display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;}
    #left-controls { display:flex; align-items:center;}
    #left-controls select,#left-controls button { padding:10px; margin-right:10px; background-color:#3a3f44; color:#e0e0e0; border:1px solid #8ab4f8; border-radius:5px;}
    #left-controls button { background-color:#8ab4f8; color:#1b1f24; border:none;}
    #left-controls button:hover { background-color:#709ace;}
    #right-controls { display:flex; align-items:center;}
    #right-controls select { padding:10px; margin-left:10px; background-color:#3a3f44; color:#e0e0e0; border:1px solid #8ab4f8; border-radius:5px;}
    .table-container { overflow-x:auto; width:100%; }
    #table_results { table-layout:fixed; width:100%; }
    #table_results th,#table_results td {
      max-width:200px;
      white-space:normal;
      word-break:break-word;
      overflow-wrap:anywhere;
      border:1px solid #3a3f44;
      padding:10px;
      text-align:left;
    }
    th { background-color:#30363d; color:#8ab4f8; font-size:1em;}
    tr:nth-child(even) { background-color:#24292f;}
    tr:nth-child(odd) { background-color:#1f2328;}
    tr:hover { background-color:#3a3f44;}
    @media screen and (max-width:600px){
      table,thead,tbody,th,td,tr{display:block;}
      th,td{width:100%;box-sizing:border-box;}
      tr{margin-bottom:10px;}
    }
  </style>
</head>
<body>
  <h1>AMR Finder + | Results</h1>
  <div id="controls">
    <div id="left-controls">
      <select id="select_format">
        <option value="CSV">CSV</option>
        <option value="Excel">Excel</option>
        <option value="TSV">TSV</option>
      </select>
      <button onclick="downloadTable()">Download</button>
    </div>
    <div id="right-controls">
      <select id="select_sample" onchange="filterTable()">
        <option value="All samples">All samples</option>
EOF

for file in "${FILE_LIST[@]}"; do
  # Use only the filename as the sample ID, removing path and extension
  filename=$(basename "$file")
  sample_id="${filename%.*}"
  echo "        <option value=\"$sample_id\">$sample_id</option>" >> "$OUTPUT_FILE"
done

cat <<'EOF' >> "$OUTPUT_FILE"
      </select>
      <select id="select_method" onchange="filterTable()">
        <option value="select method">select method</option>
        <option value="Allele">Allele</option>
        <option value="Blast">Blast</option>
        <option value="Exact">Exact</option>
        <option value="Partial">Partial</option>
        <option value="Point">Point</option>
      </select>
      <select id="select_scope" onchange="filterTable()">
        <option value="select scope">select scope</option>
        <option value="core">core</option>
        <option value="plus">plus</option>
      </select>
    </div>
  </div>
  <div class="table-container">
  <table id="table_results">
    <thead>
EOF

# --- Header Row Generation (using the first file in the list) ---

first_file="${FILE_LIST[0]}"
declare -a exclude_indices=()
if [ -f "$first_file" ]; then
  header=$(head -n 1 "$first_file")
  IFS=$'\t' read -r -a columns <<< "$header"
  echo "      <tr><th>Sample</th>" >> "$OUTPUT_FILE"
  for i in "${!columns[@]}"; do
    if [[ ! " ${excluded_columns[@]} " =~ " ${columns[$i]} " ]]; then
      echo "<th>${columns[$i]}</th>" >> "$OUTPUT_FILE"
    else
      exclude_indices+=("$i")
    fi
  done
  echo "</tr>" >> "$OUTPUT_FILE"
fi

echo "    </thead>" >> "$OUTPUT_FILE"
echo "    <tbody>" >> "$OUTPUT_FILE"

# --- Data Row Generation (iterating through the list of files) ---

for file in "${FILE_LIST[@]}"; do
  filename=$(basename "$file")
  sample_id="${filename%.*}"
  
  tail -n +2 "$file" | while IFS=$'\t' read -r -a columns; do
    row="<tr><td>$sample_id</td>"
    for i in "${!columns[@]}"; do
      if [[ ! " ${exclude_indices[@]} " =~ " $i " ]]; then
        # Escape any double quotes in the cell content to prevent breaking the HTML attribute
        content="${columns[$i]//\"/&quot;}"
        row="$row<td>$content</td>"
      fi
    done
    row="$row</tr>"
    echo "      $row" >> "$OUTPUT_FILE"
  done
done

cat <<'EOF' >> "$OUTPUT_FILE"
    </tbody>
  </table>
  </div>
  <script>
    let methodColumnIndex=-1, scopeColumnIndex=-1;
    function setColumnIndices(){
      const table=document.getElementById("table_results");
      if(!table)return;
      const headers=table.getElementsByTagName("th");
      methodColumnIndex=-1; scopeColumnIndex=-1;
      for(let i=0;i<headers.length;i++){
        const label=headers[i].innerText.trim();
        if(label==="Method")methodColumnIndex=i;
        if(label==="Scope")scopeColumnIndex=i;
      }
      const scopeSel=document.getElementById("select_scope");
      if(scopeSel){scopeSel.disabled=(scopeColumnIndex===-1);}
    }
    function filterTable(){
      if(methodColumnIndex===-1||scopeColumnIndex===-1)setColumnIndices();
      const sampleSel=document.getElementById("select_sample").value;
      const methodSel=document.getElementById("select_method").value.toLowerCase();
      const scopeSel=document.getElementById("select_scope").value.toLowerCase();
      const rows=document.getElementById("table_results").getElementsByTagName("tr");
      for(let i=1;i<rows.length;i++){
        const tds=rows[i].getElementsByTagName("td"); if(!tds.length)continue;
        const sample=tds[0].innerHTML;
        const method=methodColumnIndex===-1?"":tds[methodColumnIndex].innerHTML.toLowerCase();
        const scope=scopeColumnIndex===-1?"":tds[scopeColumnIndex].innerHTML.toLowerCase();
        const sMatch=(sampleSel==="All samples"||sample===sampleSel);
        const mMatch=(methodSel==="select method"||method.includes(methodSel));
        const scMatch=(scopeSel==="select scope"||scope.includes(scopeSel));
        rows[i].style.display=(sMatch&&mMatch&&scMatch)?"":"none";
      }
    }
    function getFilteredFileName(){
      const s=document.getElementById("select_sample").value.toLowerCase().replace(/\s+/g,"_");
      const m=document.getElementById("select_method").value.toLowerCase().replace(/\s+/g,"_");
      const sc=document.getElementById("select_scope").value.toLowerCase().replace(/\s+/g,"_");
      return "filtered_table-"+s+"-"+m+"-"+sc;
    }
    function downloadTable(){
      const format=document.getElementById("select_format").value;
      const rows=document.getElementById("table_results").getElementsByTagName("tr");
      const content=[]; const headers=Array.from(rows[0].getElementsByTagName("th")).map(th=>th.innerText); content.push(headers);
      for(let i=1;i<rows.length;i++){
        if(rows[i].style.display!=="none"){
          content.push(Array.from(rows[i].getElementsByTagName("td")).map(td=>td.innerText));
        }
      }
      const filename=getFilteredFileName();
      if(format==="CSV"){
        const csv=content.map(r=>r.join(",")).join("\n");
        const blob=new Blob([csv],{type:"text/csv;charset=utf-8;"}); const a=document.createElement("a");
        a.href=URL.createObjectURL(blob); a.download=filename+".csv"; a.click();
      }else if(format==="Excel"){
        const wb=XLSX.utils.book_new(); const ws=XLSX.utils.aoa_to_sheet(content);
        XLSX.utils.book_append_sheet(wb,ws,"Results"); XLSX.writeFile(wb,filename+".xlsx");
      }else if(format==="TSV"){
        const tsv=content.map(r=>r.join("\t")).join("\n");
        const blob=new Blob([tsv],{type:"text/tab-separated-values;charset=utf-8;"}); const a=document.createElement("a");
        a.href=URL.createObjectURL(blob); a.download=filename+".tsv"; a.click();
      }
    }
    window.onload=setColumnIndices;
  </script>
</body>
</html>
EOF

echo "HTML file '$OUTPUT_FILE' has been generated successfully."