const path=require('node:path');
const fs=require('node:fs');
const {pathToFileURL}=require('node:url');
const mods='C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1111-570-0_26.1111.570.0_x64__3k8sg7r9htsxt/dependencies/node/node_modules';
const {chromium}=require(path.join(mods,'playwright'));
const sharp=require(path.join(mods,'sharp'));
const crypto=require('node:crypto');
async function main(){
 const manifest=JSON.parse(fs.readFileSync(path.join(__dirname,'manifest.json'),'utf8'));
 for(const f of manifest.files){const bytes=fs.readFileSync(path.join(__dirname,f.path));if(crypto.createHash('sha256').update(bytes).digest('hex')!==f.sha256)throw Error(`Hash mismatch ${f.path}`);if(f.path.endsWith('.png')){const m=await sharp(bytes).metadata();if(f.path.includes('mascota_b')&&(!m.hasAlpha||m.width!==1254||m.height!==1254))throw Error(`Wrong mascot ${f.path}`);if(f.path.endsWith('/icono.png')&&(m.width!==1024||m.height!==1024))throw Error('Wrong launcher dimensions');}else{const svg=bytes.toString();if(/<script|<image|<foreignObject|href=|url\(https?:/i.test(svg))throw Error(`External content ${f.path}`);await sharp(bytes).png().toBuffer();}}
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
 try{const page=await browser.newPage({viewport:{width:1280,height:1500},deviceScaleFactor:1});await page.goto(pathToFileURL(path.join(__dirname,'galeria.html')).href);await page.evaluate(()=>Promise.all([...document.images].map(i=>i.decode())));await page.screenshot({path:path.join(__dirname,'vista_previa.png'),fullPage:true});await page.setViewportSize({width:360,height:780});const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);if(overflow)throw Error('Mobile overflow');console.log(`PASS: ${manifest.files.length} asset hashes; PNG dimensions; SVG rendering; all gallery images decoded; no overflow at 360px.`);fs.writeFileSync(path.join(__dirname,'VERIFICACION.txt'),`PASS: ${manifest.files.length} asset hashes; PNG dimensions; SVG rendering; all gallery images decoded; no overflow at 360px.\nFlutter integration and device tests pending with Claude.\n`);}finally{await browser.close();}
}
main().catch(e=>{console.error(e);process.exit(1)});
