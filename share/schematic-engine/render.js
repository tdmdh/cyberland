import { instance } from '@viz-js/viz';
import fs from 'fs';

const inputFile = process.argv[2];
const outputFile = process.argv[3];
const theme = process.argv[4] || 'cyberpunk';

if (!inputFile || !outputFile) {
    console.error("Usage: bun render.js <input_path> <output_path> [cyberpunk|whitepaper]");
    process.exit(1);
}

let content = "";
if (inputFile === "--stdin") {
    content = fs.readFileSync(0, "utf-8");
} else {
    content = fs.readFileSync(inputFile, "utf-8");
}

function parseAndTranslate(text, mode) {
    const isDark = mode === 'cyberpunk';
    const bg = isDark ? '#1a1b26' : '#ffffff';
    const fg = isDark ? '#c0caf5' : '#1a1b26';
    const nodeBg = isDark ? '#24283b' : '#f5f7fc';
    const nodeBorder = isDark ? '#00f0ff' : '#2b5cd9';
    const lineCol = isDark ? '#7aa2f7' : '#4a5568';
    const accentCol = isDark ? '#ff007f' : '#d92b68';
    const clusterBg = isDark ? '#16161e' : '#f8f9fa';

    // If pure DOT
    if (/^\s*(di)?graph\s+/i.test(text.trim()) && text.includes('{')) {
        // Inject theme colors if not explicitly set
        if (!text.includes('bgcolor=')) {
            text = text.replace(/\{\s*/, `{\n  bgcolor="${bg}";\n  node [fontcolor="${fg}"];\n  edge [fontcolor="${fg}"];\n`);
        }
        return text;
    }

    // Sequence diagram handling
    if (/^\s*sequenceDiagram/i.test(text.trim())) {
        return translateSequence(text, { bg, fg, nodeBg, nodeBorder, lineCol, accentCol });
    }

    // State diagram handling
    if (/^\s*stateDiagram/i.test(text.trim())) {
        return translateState(text, { bg, fg, nodeBg, nodeBorder, lineCol, accentCol });
    }

    // Flowchart handling
    return translateFlowchart(text, { bg, fg, nodeBg, nodeBorder, lineCol, accentCol, clusterBg });
}

function translateSequence(text, c) {
    let dot = `digraph Sequence {
  bgcolor="${c.bg}";
  rankdir=LR;
  node [shape=box, style="filled,rounded", fillcolor="${c.nodeBg}", color="${c.nodeBorder}", penwidth=1.5, fontname="Sans-Serif", fontcolor="${c.fg}", fontsize=11];
  edge [color="${c.lineCol}", penwidth=1.5, fontname="Sans-Serif", fontcolor="${c.fg}", fontsize=9, arrowsize=0.8];
`;
    const lines = text.split('\n');
    const participants = new Set();
    const interactions = [];

    for (let raw of lines) {
        let line = raw.trim();
        if (!line || line.startsWith('sequenceDiagram') || line.startsWith('%%')) continue;

        let m = line.match(/^([a-zA-Z0-9_\-]+)\s*(?:->>|-->>|->|-->)\s*([a-zA-Z0-9_\-]+)\s*:\s*(.*)$/);
        if (m) {
            participants.add(m[1]);
            participants.add(m[2]);
            interactions.push({ from: m[1], to: m[2], label: m[3] });
        } else {
            let pMatch = line.match(/^participant\s+([a-zA-Z0-9_\-]+)(?:\s+as\s+(.*))?$/i);
            if (pMatch) {
                participants.add(pMatch[1]);
            }
        }
    }

    for (let p of participants) {
        dot += `  ${p} [label="${p}"];\n`;
    }
    for (let act of interactions) {
        dot += `  ${act.from} -> ${act.to} [label="${act.label.replace(/"/g, '\\"')}"];\n`;
    }
    dot += '}\n';
    return dot;
}

function translateState(text, c) {
    let dot = `digraph StateMachine {
  bgcolor="${c.bg}";
  rankdir=TB;
  node [shape=box, style="filled,rounded", fillcolor="${c.nodeBg}", color="${c.nodeBorder}", penwidth=1.5, fontname="Sans-Serif", fontcolor="${c.fg}", fontsize=11];
  edge [color="${c.lineCol}", penwidth=1.5, fontname="Sans-Serif", fontcolor="${c.fg}", fontsize=9, arrowsize=0.8];
  START [shape=circle, width=0.25, height=0.25, fillcolor="${c.accentCol}", color="${c.accentCol}", label=""];
  END [shape=doublecircle, width=0.25, height=0.25, fillcolor="${c.accentCol}", color="${c.accentCol}", label=""];
`;
    const lines = text.split('\n');
    for (let raw of lines) {
        let line = raw.trim();
        if (!line || line.startsWith('stateDiagram') || line.startsWith('%%')) continue;
        line = line.replace(/\[\*\]\s*-->/g, 'START ->');
        line = line.replace(/-->\s*\[\*\]/g, '-> END');
        let m = line.match(/^([a-zA-Z0-9_\-]+)\s*(?:-->|->)\s*([a-zA-Z0-9_\-]+)(?:\s*:\s*(.*))?$/);
        if (m) {
            let from = m[1];
            let to = m[2];
            let lbl = m[3] ? ` [label="${m[3].replace(/"/g, '\\"')}"]` : '';
            dot += `  ${from} -> ${to}${lbl};\n`;
        }
    }
    dot += '}\n';
    return dot;
}

function translateFlowchart(text, c) {
    let rankdir = 'TB';
    if (/flowchart\s+LR|graph\s+LR/i.test(text)) rankdir = 'LR';
    else if (/flowchart\s+RL|graph\s+RL/i.test(text)) rankdir = 'RL';
    else if (/flowchart\s+BT|graph\s+BT/i.test(text)) rankdir = 'BT';

    let dot = `digraph Flowchart {
  bgcolor="${c.bg}";
  rankdir="${rankdir}";
  pad="0.3";
  nodesep="0.45";
  ranksep="0.55";
  node [shape=box, style="filled,rounded", fillcolor="${c.nodeBg}", color="${c.nodeBorder}", penwidth=1.5, fontname="Sans-Serif", fontcolor="${c.fg}", fontsize=11, margin="0.18,0.08"];
  edge [color="${c.lineCol}", penwidth=1.5, fontname="Sans-Serif", fontcolor="${c.fg}", fontsize=9, arrowsize=0.8];
`;

    const lines = text.split('\n');
    const nodes = new Map();
    const edges = [];
    let currentCluster = null;
    const clusters = [];
    let clusterCounter = 0;

    for (let raw of lines) {
        let line = raw.trim();
        if (!line || /^(flowchart|graph)\s+/i.test(line) || line.startsWith('%%')) continue;

        if (/^subgraph\s+/i.test(line)) {
            let m = line.match(/^subgraph\s+(?:\"([^\"]+)\"|([^\s\[]+))(?:\s*\[([^\]]+)\])?/i);
            let name = m ? (m[3] || m[1] || m[2]) : `Cluster_${clusterCounter}`;
            let id = `cluster_${clusterCounter++}`;
            currentCluster = { id, name, nodes: [] };
            clusters.push(currentCluster);
            continue;
        }

        if (line === 'end') {
            currentCluster = null;
            continue;
        }

        // Parse node shapes:
        // A[(DB)], A([Oval]), A{Decision}, A[[Subroutine]], A[Box]
        function registerNode(str) {
            let m = str.match(/^([a-zA-Z0-9_\-]+)\s*(?:\[\(([^\)]+)\)\]|\(\[([^\]]+)\]\)|\{([^}]+)\}|\[\[([^\]]+)\]\]|\[([^\]]+)\]|\(([^\)]+)\))?$/);
            if (!m) return str;
            let id = m[1];
            let label = m[2] || m[3] || m[4] || m[5] || m[6] || m[7] || id;
            let shape = 'box';
            if (m[2]) shape = 'cylinder';
            else if (m[3]) shape = 'oval';
            else if (m[4]) shape = 'diamond';
            else if (m[5]) shape = 'box3d';
            else if (m[7]) shape = 'ellipse';

            if (!nodes.has(id)) {
                nodes.set(id, { id, label, shape });
                if (currentCluster) currentCluster.nodes.push(id);
            }
            return id;
        }

        // Look for edges like A --> B or A -->|label| B
        let edgeMatch = line.match(/^(.+?)\s*(?:-->|---|==>|-\.->)\s*(?:\|([^|]+)\|\s*)?(.+)$/);
        if (edgeMatch) {
            let left = edgeMatch[1].trim();
            let label = edgeMatch[2] ? edgeMatch[2].trim() : '';
            let right = edgeMatch[3].trim();

            let fromId = registerNode(left);
            let toId = registerNode(right);
            edges.push({ from: fromId, to: toId, label });
        } else {
            registerNode(line);
        }
    }

    // Output clusters
    for (let cl of clusters) {
        dot += `  subgraph ${cl.id} {\n`;
        dot += `    label="${cl.name.replace(/"/g, '\\"')}";\n`;
        dot += `    color="${c.accentCol}";\n`;
        dot += `    style="dashed";\n`;
        dot += `    fontcolor="${c.accentCol}";\n`;
        dot += `    fontsize=10;\n`;
        for (let n of cl.nodes) {
            dot += `    ${n};\n`;
        }
        dot += `  }\n`;
    }

    // Output nodes
    for (let [id, node] of nodes) {
        let extra = '';
        if (node.shape === 'diamond') extra = `, color="${c.accentCol}"`;
        dot += `  ${id} [shape=${node.shape}, label="${node.label.replace(/"/g, '\\"')}"${extra}];\n`;
    }

    // Output edges
    for (let e of edges) {
        let lbl = e.label ? ` [label="${e.label.replace(/"/g, '\\"')}"]` : '';
        dot += `  ${e.from} -> ${e.to}${lbl};\n`;
    }

    dot += '}\n';
    return dot;
}

async function run() {
    try {
        const dot = parseAndTranslate(content, theme);
        const viz = await instance();
        const svg = viz.renderString(dot, { format: 'svg' });
        const tmpFile = outputFile + '.tmp.' + process.pid;
        fs.writeFileSync(tmpFile, svg);
        fs.renameSync(tmpFile, outputFile);
        process.exit(0);
    } catch (err) {
        console.error("RenderError:", err.message || err);
        process.exit(1);
    }
}

run();
