// build-ui.js — Generate www/index.html with embedded Lisp-produced snapshots.
// The web UI is a PURE VIEW: it does not emulate; it renders state sent
// (or pre-computed) by the Common Lisp side.

const fs=require("fs");
const path=require("path");

const ROOT="/home/turtle/scm-controlled/common-lisp/secd-emulator";
const SNAP=path.join(ROOT,"snapshots.json");
const TEMPLATE=path.join(ROOT,"www","index.html.tmpl");
const OUT=path.join(ROOT,"www","index.html");

if(!fs.existsSync(SNAP)){ console.error("missing",SNAP); process.exit(1); }
if(!fs.existsSync(TEMPLATE)){ console.error("missing",TEMPLATE); process.exit(1); }

const snap=fs.readFileSync(SNAP,"utf8");
let tmpl=fs.readFileSync(TEMPLATE,"utf8");

// Inject: window.SECD_SNAPSHOTS = <json>;
// Use a safe replacement: base64 the JSON so we never collide with the
// template's </script> or HTML specials. The decoder below unpacks it.
// (We could just inline; base64 is a tiny safety belt.)

const b64=Buffer.from(snap,"utf8").toString("base64");
const inject=`window.SECD_SNAPSHOTS = JSON.parse(atob("${b64}"));\n`;
// Replace exactly one marker
if(!tmpl.includes("__SECD_SNAPSHOTS__")){ console.error("template missing marker __SECD_SNAPSHOTS__"); process.exit(1); }
tmpl=tmpl.replace("__SECD_SNAPSHOTS__", inject);
fs.writeFileSync(OUT,tmpl);
console.log("wrote",OUT,tmpl.length,"bytes (snap",snap.length,"bytes, b64",b64.length,")");
