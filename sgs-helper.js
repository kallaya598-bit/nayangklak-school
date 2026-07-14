/* =====================================================================
   SGS Helper — เติมคะแนนจากระบบดูแลนักเรียน นายางกลักพิทยาคม ลงหน้า SGS
   โหลดผ่าน bookmarklet บนหน้ากรอกคะแนนของ SGS
   กติกาความปลอดภัย:
   - จับคู่นักเรียนด้วย "เลขประจำตัว" เท่านั้น ไม่ใช้ลำดับแถว
   - เติมเฉพาะช่องที่ว่างใน SGS ไม่ทับค่าที่มีอยู่ (ยกเว้นติ๊กเปิด "โหมดแก้ไข
     คะแนน" เอง — ปิดเป็นค่าเริ่มต้นเสมอทุกครั้งที่เปิดหน้าใหม่ ไม่จำค่าไว้)
   - ไม่กดปุ่มบันทึกของ SGS ให้เอง (ถ้ามี) — แต่บางหน้า SGS เป็น auto-save
     ทุกครั้งที่ onchange จึงต้องยืนยัน (confirm) ก่อนเติมเสมอ
   หมายเหตุจากหน้า SGS จริง (Edit-TblTranscripts1-Table.aspx):
   - ช่องคะแนนแต่ละคอลัมน์ (S1..S9 / กลางภาค / Remark) ถูก disabled ไว้ก่อน
     ต้องติ๊ก checkbox บนหัวคอลัมน์ก่อนถึงจะพิมพ์ได้ (ฟังก์ชัน check(v,n)
     ใน SGS toggle disabled ตาม name suffix เช่น 'S1','Midterm','Remark')
     → สคริปต์นี้จะกด checkbox นั้นให้อัตโนมัติก่อนเติมค่าในคอลัมน์นั้น
   - onchange ของแต่ละช่องเรียก PageMethods.SaveMe(...) บันทึกขึ้นฐานข้อมูล
     ทันที ไม่มีปุ่ม Save แยกให้กด (auto-save) — ต้องระวังเป็นพิเศษ
   - ช่อง "ก่อนกลางภาค" (ScoreMid) เป็นผลรวมที่คำนวณอัตโนมัติ ไม่มี onchange
     เลย ห้ามพยายามเติมช่องนี้ตรงๆ
   ===================================================================== */
(function(){
'use strict';
if(window.__SGS_HELPER__){window.__SGS_HELPER__.show();return;}

var VERSION='1.0.0';
var PURPLE='#4527a0',PURPLE_L='#ede7f6',GREEN='#2e7d32',RED='#c62828',AMBER='#e65100';
var H={pkg:null,scan:null,map:{},panel:null,round:false,partial:true,overwrite:false};
window.__SGS_HELPER__=H;

/* ---------- utils ---------- */
function el(tag,style,html){var e=document.createElement(tag);if(style)e.style.cssText=style;if(html!==undefined)e.innerHTML=html;return e;}
function txt(s){return (s==null?'':String(s)).replace(/[ \s]+/g,' ').trim();}
function esc(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
function fmtNum(v){
  if(v==null||v==='')return '';
  var n=parseFloat(v);if(isNaN(n))return '';
  if(H.round)n=Math.round(n);
  n=Math.round(n*100)/100;
  return String(n);
}
function copyText(t,ok){
  function fb(){var ta=document.createElement('textarea');ta.value=t;ta.style.cssText='position:fixed;opacity:0;';document.body.appendChild(ta);ta.select();try{document.execCommand('copy');flash(ok);}catch(e){flash('คัดลอกไม่สำเร็จ',true);}document.body.removeChild(ta);}
  if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(t).then(function(){flash(ok);},fb);else fb();
}
function flash(msg,isErr){
  var f=el('div','position:fixed;top:14px;left:50%;transform:translateX(-50%);z-index:2147483647;background:'+(isErr?RED:GREEN)+';color:#fff;padding:9px 18px;border-radius:8px;font:700 14px/1.4 Sarabun,Tahoma,sans-serif;box-shadow:0 4px 16px rgba(0,0,0,.3);',esc(msg));
  document.body.appendChild(f);setTimeout(function(){f.remove();},2600);
}

/* ---------- เอกสารทั้งหมด (รวม iframe same-origin — SGS บางหน้าใช้ frame) ---------- */
function allDocs(){
  var docs=[document];
  var frames=document.querySelectorAll('iframe,frame');
  for(var i=0;i<frames.length;i++){
    try{if(frames[i].contentDocument)docs.push(frames[i].contentDocument);}catch(e){}
  }
  return docs;
}

/* ---------- สแกนหน้า: หาตารางที่มีเลขประจำตัวนักเรียน + คอลัมน์ input ---------- */
// หมายเหตุ: SGS จริงตั้งค่าช่องคะแนนเป็น disabled ไว้ก่อน (ต้องติ๊ก checkbox
// หัวคอลัมน์ก่อนถึงจะพิมพ์ได้) จึง "ไม่" ตัด disabled ออกตอนสแกนโครงตาราง —
// แต่จะเช็คแยกว่าช่องไหน "กรอกได้จริง" ด้วย isFillable() ตอนสร้าง cols[]
function editableInputs(row){
  var list=[];
  var cand=row.querySelectorAll('input[type="text"],input[type="number"],input:not([type])');
  for(var i=0;i<cand.length;i++){
    var inp=cand[i];
    if(inp.type==='hidden'||inp.readOnly)continue;
    if(inp.offsetParent===null&&inp.style.display!=='')continue; // ซ่อนอยู่
    list.push(inp);
  }
  return list;
}
// ช่องที่ "กรอกได้จริง" ต้องมี onchange (ช่องคำนวณอัตโนมัติ เช่น ก่อนกลางภาค จะไม่มี)
function isFillable(inp){return !!(inp.getAttribute('onchange')||'').trim();}
// suffix ของชื่อฟิลด์ (ตัวท้ายหลัง $ สุดท้าย) ใช้จับคู่กับ checkbox ปลดล็อกคอลัมน์
function colSuffix(inp){
  var name=inp.name||'';
  var idx=name.lastIndexOf('$');
  return idx>=0?name.slice(idx+1):name;
}
// กด checkbox หัวคอลัมน์เพื่อปลดล็อก (ถ้ายังไม่ได้ติ๊ก) ก่อนเติมค่าในคอลัมน์นั้น
function ensureColumnEnabled(inp){
  if(!inp.disabled)return;
  var suffix=colSuffix(inp);
  if(!suffix)return;
  var cbs=document.querySelectorAll('input[type="checkbox"]');
  for(var i=0;i<cbs.length;i++){
    var oc=cbs[i].getAttribute('onclick')||'';
    if(oc.indexOf("'"+suffix+"'")>=0){
      if(!cbs[i].checked)cbs[i].click();
      return;
    }
  }
}
// กางหัวตารางเป็น grid โดยคิด colspan/rowspan (หัวตาราง SGS ซ้อนหลายชั้น)
function headerGrid(table){
  var grid=[],rows=table.rows;
  for(var r=0;r<rows.length;r++){
    if(editableInputs(rows[r]).length)break; // ถึงแถวข้อมูลแล้ว หยุด
    grid[r]=grid[r]||[];
    var c=0;
    for(var i=0;i<rows[r].cells.length;i++){
      var cell=rows[r].cells[i];
      while(grid[r][c]!==undefined)c++;
      var t=txt(cell.textContent);
      var rs=cell.rowSpan||1,cs=cell.colSpan||1;
      for(var dr=0;dr<rs;dr++){
        grid[r+dr]=grid[r+dr]||[];
        for(var dc=0;dc<cs;dc++)grid[r+dr][c+dc]=t;
      }
      c+=cs;
    }
  }
  return grid;
}
function headerFor(grid,cellIndex,j){
  var texts=[];
  for(var r=0;r<grid.length;r++){
    var t=grid[r]?grid[r][cellIndex]:undefined;
    if(t&&texts.indexOf(t)<0)texts.push(t);
  }
  return texts.length?texts.join(' / '):('ช่องที่ '+(j+1));
}
function scanPage(){
  var codeSet={};
  H.pkg.students.forEach(function(s){if(s.code){codeSet[s.code]=s;codeSet[s.code.replace(/^0+/,'')]=s;}});
  var best=null;
  allDocs().forEach(function(doc){
    var tables=doc.querySelectorAll('table');
    for(var t=0;t<tables.length;t++){
      var table=tables[t],rows=[],rlist=table.rows;
      for(var r=0;r<rlist.length;r++){
        var tr=rlist[r],code=null,name='';
        for(var c=0;c<tr.cells.length;c++){
          var cellText=txt(tr.cells[c].textContent);
          var m=cellText.match(/^\d{3,10}$/);
          if(m&&(codeSet[cellText]||codeSet[cellText.replace(/^0+/,'')])){code=cellText;continue;}
          if(code&&!name&&/[ก-๙]{2,}/.test(cellText))name=cellText; // ชื่อไทยถัดจากเลข
        }
        if(!code)continue;
        var inputs=editableInputs(tr);
        if(!inputs.length)continue;
        rows.push({tr:tr,code:code,stu:codeSet[code]||codeSet[code.replace(/^0+/,'')],name:name,inputs:inputs});
      }
      if(!rows.length)continue;
      // จำนวนคอลัมน์ = โหมด (ค่าที่พบบ่อยสุด) ของจำนวน input ต่อแถว
      var freq={};rows.forEach(function(rw){freq[rw.inputs.length]=(freq[rw.inputs.length]||0)+1;});
      var nCols=+Object.keys(freq).sort(function(a,b){return freq[b]-freq[a];})[0];
      rows=rows.filter(function(rw){return rw.inputs.length===nCols;});
      if(!rows.length)continue;
      var cols=[],grid=headerGrid(table);
      for(var j=0;j<nCols;j++){
        var td=rows[0].inputs[j].closest('td,th');
        var ci=td?td.cellIndex:j;
        cols.push({index:j,header:headerFor(grid,ci,j),name:rows[0].inputs[j].name||'',fillable:isFillable(rows[0].inputs[j])});
      }
      var cand={table:table,rows:rows,cols:cols};
      if(!best||rows.length>best.rows.length)best=cand;
    }
  });
  return best;
}

/* ---------- โหมดวิเคราะห์หน้า (ส่งโครงหน้าให้ผู้พัฒนา) ---------- */
function analyzePage(){
  var out={helper:VERSION,url:location.href,title:document.title,frames:allDocs().length-1,tables:[]};
  allDocs().forEach(function(doc){
    var tables=doc.querySelectorAll('table');
    for(var t=0;t<tables.length;t++){
      var table=tables[t];
      var inputs=table.querySelectorAll('input[type="text"],input[type="number"],input:not([type])');
      if(table.rows.length<2&&!inputs.length)continue;
      var headers=[];
      for(var r=0;r<Math.min(table.rows.length,3);r++){
        var hrow=[];for(var c=0;c<table.rows[r].cells.length;c++)hrow.push(txt(table.rows[r].cells[c].textContent).slice(0,40));
        headers.push(hrow);
      }
      var sampleRow='';
      for(var r2=0;r2<table.rows.length;r2++){
        if(editableInputs(table.rows[r2]).length){sampleRow=table.rows[r2].outerHTML.slice(0,2000);break;}
      }
      out.tables.push({rows:table.rows.length,inputs:inputs.length,headers:headers,sampleRow:sampleRow});
    }
  });
  copyText(JSON.stringify(out),'คัดลอกผลวิเคราะห์หน้าแล้ว — ส่งข้อความนี้ให้ผู้พัฒนาได้เลย');
}

/* ---------- mapping: จำค่าไว้ใน localStorage ---------- */
/* ---------- ขนาด/ตำแหน่งพาเนล: จำไว้ใน localStorage (ลากขยายมุม/ปุ่มขยายเต็มจอ) ---------- */
var SIZE_KEY='sgshelper:size';
function loadSize(){try{return JSON.parse(localStorage.getItem(SIZE_KEY)||'null');}catch(e){return null;}}
function saveSize(){
  try{
    var p=H.panel;if(!p)return;
    localStorage.setItem(SIZE_KEY,JSON.stringify({w:p.style.width,h:p.style.height,maximized:!!H.maximized,prevW:H.prevRect&&H.prevRect.w,prevH:H.prevRect&&H.prevRect.h}));
  }catch(e){}
}
function toggleMaximize(){
  var p=H.panel,btn=p.querySelector('#sgshMax');
  if(!H.maximized){
    H.prevRect={w:p.style.width,h:p.style.height};
    p.style.width='96vw';p.style.height='94vh';
    H.maximized=true;btn.textContent='🗗';btn.title='ย่อกลับ';
  }else{
    var r=H.prevRect||{};
    p.style.width=r.w||'400px';p.style.height=r.h||'';
    H.maximized=false;btn.textContent='⛶';btn.title='ขยายเต็มจอ';
  }
  saveSize();
}
function mapKey(){
  var sig=H.scan.cols.map(function(c){return c.header;}).join('|');
  return 'sgsmap:'+(H.pkg.subject.code||'')+':'+H.scan.cols.length+':'+sig.length;
}
function loadMap(){try{var s=localStorage.getItem(mapKey());return s?JSON.parse(s):null;}catch(e){return null;}}
function saveMap(){try{localStorage.setItem(mapKey(),JSON.stringify(H.map));}catch(e){}}
function guessSlot(header){
  var h=header.replace(/\s/g,'');
  var slots=H.pkg.slots;
  // จับคู่ชื่อตรงก่อน
  for(var i=0;i<slots.length;i++){var n=slots[i].name.replace(/\s/g,'');if(n&&(h===n||h.indexOf(n)>=0||n.indexOf(h)>=0))return slots[i].id;}
  // จับคู่ตามคำสำคัญของช่วง
  function byPhase(ph){var vs=slots.filter(function(s){return s.phase===ph;});var v=vs.filter(function(s){return s.virtual;})[0];return (v||vs[0]||{}).id;}
  if(/กลางภาค/.test(h)&&!/ก่อน|หลัง/.test(h))return byPhase('midterm');
  if(/ปลายภาค/.test(h))return byPhase('final');
  if(/ก่อนกลางภาค|ก่อนสอบ/.test(h))return byPhase('before_mid');
  if(/หลังกลางภาค|หลังสอบ/.test(h))return byPhase('after_mid');
  return '';
}
// รองรับ "กำหนดเอง (รวมหลายช่อง)" — H.map[col] เก็บเป็น {combo:[id,id,...]} แทนที่จะเป็น string id เดียว
function isCombo(v){return !!(v&&typeof v==='object'&&Array.isArray(v.combo));}
function baseSlots(){return H.pkg.slots.filter(function(s){return !s.virtual;});}
// รวมคะแนนจากหลายช่องของนักเรียนคนหนึ่ง
// partial=false (ค่าปกติ): ต้องมีคะแนนครบทุกช่องที่เลือกมารวม ไม่งั้นถือว่ายังไม่มีคะแนน (กันรวมผิด)
// partial=true: รวมเท่าที่มีคะแนนอยู่ (ข้ามช่องที่ยังว่าง) — ผลลัพธ์จะติดธง complete:false ให้รู้ว่ายังไม่ครบ
function comboSum(stu,ids,partial){
  var sum=0,any=false,complete=true;
  for(var i=0;i<ids.length;i++){
    var v=stu.scores[ids[i]];
    if(v===undefined||v===null||v===''){complete=false;continue;}
    sum+=parseFloat(v)||0;any=true;
  }
  if(!any)return null; // ไม่มีคะแนนเลยสักช่อง
  if(!complete&&!partial)return null; // ไม่ครบ และไม่ได้เปิดโหมด "รวมเท่าที่มี"
  return {value:sum,complete:complete};
}

/* ---------- คำนวณแผนการเติม ---------- */
function buildPlan(){
  var plan={fills:[],overwrites:[],conflicts:[],already:[],missingInSgs:[],extraInSgs:0};
  var seen={};
  H.scan.rows.forEach(function(rw){
    if(!rw.stu){plan.extraInSgs++;return;}
    seen[rw.stu.code]=true;
    H.scan.cols.forEach(function(col){
      var mapped=H.map[col.index];if(!mapped)return;
      var ours,isPartial=false;
      if(isCombo(mapped)){
        if(!mapped.combo.length)return;
        var cs=comboSum(rw.stu,mapped.combo,H.partial);
        ours=cs?cs.value:null;
        isPartial=!!(cs&&!cs.complete);
      }else{
        ours=rw.stu.scores[mapped];
      }
      var oursTxt=fmtNum(ours);
      if(oursTxt==='')return; // เราไม่มีคะแนน — ข้าม
      var inp=rw.inputs[col.index];
      var cur=txt(inp.value);
      if(cur===''){plan.fills.push({row:rw,col:col,inp:inp,val:oursTxt,partial:isPartial});}
      else if(parseFloat(cur)===parseFloat(oursTxt)){plan.already.push({row:rw,col:col});}
      else if(H.overwrite){plan.overwrites.push({row:rw,col:col,inp:inp,val:oursTxt,cur:cur,partial:isPartial});}
      else{plan.conflicts.push({row:rw,col:col,cur:cur,val:oursTxt});}
    });
  });
  H.pkg.students.forEach(function(s){
    if(s.code&&!seen[s.code]&&!seen[s.code.replace(/^0+/,'')])plan.missingInSgs.push(s);
  });
  return plan;
}
function doFill(items,color){
  var n=0,enabledCols={};
  items.forEach(function(f){
    if(f.inp.disabled){
      var key=colSuffix(f.inp);
      if(!enabledCols[key]){ensureColumnEnabled(f.inp);enabledCols[key]=true;}
    }
    f.inp.value=f.val;
    // แจ้ง framework ของหน้า (ASP.NET/React ฯลฯ) ว่าค่าเปลี่ยน — บางหน้า SGS
    // ผูก onchange ไว้บันทึกทันที (auto-save) จึงเท่ากับ "บันทึกจริง" ทันทีที่ทำ
    try{
      f.inp.dispatchEvent(new Event('input',{bubbles:true}));
      f.inp.dispatchEvent(new Event('change',{bubbles:true}));
    }catch(e){}
    f.inp.style.background=color||'#c8e6c9';
    n++;
  });
  return n;
}

/* ---------- UI panel ---------- */
var S='font-family:Sarabun,Tahoma,sans-serif;';
function btn(label,style){return '<button style="'+S+'cursor:pointer;border-radius:8px;padding:7px 14px;font-weight:700;font-size:13.5px;border:1px solid '+PURPLE+';background:'+PURPLE+';color:#fff;'+(style||'')+'">'+label+'</button>';}
function btnO(label,style){return '<button style="'+S+'cursor:pointer;border-radius:8px;padding:6px 12px;font-weight:700;font-size:13px;border:1px solid #b39ddb;background:#fff;color:'+PURPLE+';'+(style||'')+'">'+label+'</button>';}

function buildPanel(){
  var p=el('div','position:fixed;top:10px;right:10px;width:400px;min-width:340px;min-height:260px;max-width:96vw;max-height:96vh;display:flex;flex-direction:column;resize:both;overflow:auto;z-index:2147483646;background:#fff;border:2px solid '+PURPLE+';border-radius:14px;box-shadow:0 10px 40px rgba(0,0,0,.35);'+S+'font-size:14px;color:#263238;');
  p.id='sgsHelperPanel';
  p.innerHTML=
    '<div style="flex-shrink:0;background:'+PURPLE+';color:#fff;padding:10px 14px;font-weight:800;font-size:15px;display:flex;justify-content:space-between;align-items:center;">'+
      '<span>🚀 SGS Helper <small style="font-weight:400;opacity:.8;">v'+VERSION+'</small></span>'+
      '<span style="display:flex;align-items:center;gap:10px;">'+
        '<span id="sgshMax" title="ขยายเต็มจอ" style="cursor:pointer;font-size:16px;padding:0 2px;">⛶</span>'+
        '<span id="sgshClose" style="cursor:pointer;font-size:18px;padding:0 4px;">✕</span>'+
      '</span></div>'+
    '<div id="sgshBody" style="padding:12px 14px;flex:1;min-height:0;display:flex;flex-direction:column;overflow-y:auto;">'+
      '<div id="sgshStepsTop" style="flex-shrink:0;max-height:260px;overflow-y:auto;">'+
      '<div id="sgshStep1">'+
        '<div style="font-weight:800;color:'+PURPLE+';margin-bottom:6px;">1️⃣ วางข้อมูลคะแนน</div>'+
        '<div style="font-size:12.5px;color:#607d8b;margin-bottom:6px;">กดปุ่ม "คัดลอกข้อมูล SGS" ในระบบดูแลนักเรียนก่อน แล้วกดวางที่นี่</div>'+
        '<div style="display:flex;gap:6px;margin-bottom:6px;">'+btnO('📥 วางจากคลิปบอร์ด','flex:1;')+ '</div>'+
        '<textarea id="sgshPaste" placeholder="หรือกด Ctrl+V วางข้อมูลในช่องนี้..." style="'+S+'width:100%;box-sizing:border-box;height:56px;border:1.5px dashed #b39ddb;border-radius:8px;padding:6px;font-size:12px;"></textarea>'+
        '<div id="sgshPkgInfo" style="margin-top:6px;font-size:13px;"></div>'+
      '</div>'+
      '<div id="sgshStep2" style="display:none;margin-top:10px;">'+
        '<div style="font-weight:800;color:'+PURPLE+';margin-bottom:6px;">2️⃣ สแกนหน้า SGS</div>'+
        '<div id="sgshScanBtnWrap">'+btn('🔍 สแกนหานักเรียน + ช่องกรอก','width:100%;')+'</div>'+
        '<div id="sgshScanInfo" style="margin-top:6px;font-size:13px;"></div>'+
      '</div>'+
      '<div id="sgshStep3" style="display:none;margin-top:10px;">'+
        '<div style="font-weight:800;color:'+PURPLE+';margin-bottom:6px;">3️⃣ จับคู่ช่องคะแนน</div>'+
        '<div style="font-size:12.5px;color:#607d8b;margin-bottom:6px;">ซ้าย = ช่องใน SGS · ขวา = ช่องจากระบบเรา (เลือก "ไม่เติม" เพื่อข้าม)</div>'+
        '<div id="sgshMapRows"></div>'+
        '<label style="display:flex;align-items:center;gap:6px;margin-top:8px;font-size:13px;"><input type="checkbox" id="sgshRound"> ปัดคะแนนเป็นจำนวนเต็ม</label>'+
        '<label style="display:flex;align-items:center;gap:6px;margin-top:6px;font-size:13px;"><input type="checkbox" id="sgshPartial" checked> ช่อง "กำหนดเอง (รวมหลายช่อง)" ถ้ายังไม่ครบ ให้เติมเท่าที่มีคะแนน</label>'+
        '<label style="display:flex;align-items:center;gap:6px;margin-top:8px;padding:6px 8px;background:#fff3e0;border:1px solid #ffcc80;border-radius:8px;font-size:13px;color:'+AMBER+';font-weight:700;"><input type="checkbox" id="sgshOverwrite"> ⚠️ โหมดแก้ไขคะแนน (ทับค่าเดิมที่มีอยู่แล้วได้)</label>'+
        '<div style="margin-top:8px;">'+btn('👁️ พรีวิวการเติม','width:100%;background:#00695c;border-color:#00695c;')+'</div>'+
      '</div>'+
      '</div>'+
      '<div id="sgshStep4" style="display:none;flex-direction:column;flex:1;min-height:120px;margin-top:10px;">'+
        '<div style="flex-shrink:0;font-weight:800;color:'+PURPLE+';margin-bottom:6px;">4️⃣ ตรวจสอบ + เติมคะแนน</div>'+
        '<div id="sgshPlanInfo" style="flex:1;min-height:0;display:flex;flex-direction:column;font-size:13px;"></div>'+
        '<div id="sgshFillWrap" style="flex-shrink:0;margin-top:8px;"></div>'+
      '</div>'+
      '<div style="flex-shrink:0;margin-top:14px;border-top:1px solid #e0e0e0;padding-top:8px;display:flex;justify-content:space-between;align-items:center;">'+
        '<span style="font-size:11.5px;color:#90a4ae;">ไม่กดปุ่มบันทึกของ SGS ให้ — แต่บางหน้า SGS auto-save ทันทีที่กรอก</span>'+
        btnO('🧪 วิเคราะห์หน้า','font-size:11.5px;padding:4px 8px;')+
      '</div>'+
    '</div>';
  document.body.appendChild(p);
  H.panel=p;
  // จำขนาด/สถานะขยายเต็มจอไว้ครั้งก่อน (ถ้ามี)
  var sz=loadSize();
  if(sz){
    if(sz.prevW)H.prevRect={w:sz.prevW,h:sz.prevH};
    if(sz.maximized){
      p.style.width='96vw';p.style.height='94vh';
      H.maximized=true;
      if(!H.prevRect)H.prevRect={w:sz.w,h:sz.h};
    }else{
      if(sz.w)p.style.width=sz.w;
      if(sz.h)p.style.height=sz.h;
    }
  }
  p.querySelector('#sgshMax').textContent=H.maximized?'🗗':'⛶';
  p.querySelector('#sgshMax').onclick=toggleMaximize;
  // ลากมุมขวาล่างขยายเอง (resize:both ของ CSS) — จำขนาดที่ลากไว้ด้วย
  // ใช้ทั้ง ResizeObserver (เผื่อเบราว์เซอร์ทริกเกอร์เร็ว) และ mouseup ที่ตัวพาเนล
  // (จับตอนปล่อยเมาส์หลังลากขอบ กันไว้อีกชั้นเผื่อ ResizeObserver มาช้า)
  if(window.ResizeObserver){
    var ro=new ResizeObserver(function(){saveSize();});
    ro.observe(p);
  }
  p.addEventListener('mouseup',function(){saveSize();});
  p.querySelector('#sgshClose').onclick=function(){p.style.display='none';};
  // ปุ่มวางจากคลิปบอร์ด
  p.querySelector('#sgshStep1 button').onclick=function(){
    if(navigator.clipboard&&navigator.clipboard.readText){
      navigator.clipboard.readText().then(function(t){p.querySelector('#sgshPaste').value=t;tryParse();},function(){flash('อ่านคลิปบอร์ดไม่ได้ — กด Ctrl+V วางในช่องล่างแทน',true);});
    }else flash('เบราว์เซอร์นี้ไม่รองรับ — กด Ctrl+V วางในช่องล่างแทน',true);
  };
  p.querySelector('#sgshPaste').addEventListener('input',tryParse);
  p.querySelector('#sgshStep2 button').onclick=runScan;
  p.querySelector('#sgshStep3 button:last-of-type').onclick=showPlan;
  p.querySelector('#sgshRound').onchange=function(){H.round=this.checked;};
  p.querySelector('#sgshPartial').onchange=function(){H.partial=this.checked;};
  p.querySelector('#sgshOverwrite').onchange=function(){H.overwrite=this.checked;H.panel.querySelector('#sgshStep4').style.display='none';};
  // ปุ่มวิเคราะห์หน้า = ปุ่มสุดท้ายใน panel (ตอน build ยังไม่มีปุ่มเติมของ step4)
  var allB=p.querySelectorAll('button');allB[allB.length-1].onclick=analyzePage;
}

function tryParse(){
  var t=txt(H.panel.querySelector('#sgshPaste').value);
  if(!t)return;
  var info=H.panel.querySelector('#sgshPkgInfo');
  try{
    if(t.indexOf('SGSPKG1:')===0)t=t.slice(8);
    var pkg=JSON.parse(t);
    if(!pkg.students||!pkg.slots)throw new Error('ไม่ใช่ข้อมูลจากระบบดูแลนักเรียน');
    H.pkg=pkg;
    info.innerHTML='<div style="background:#e8f5e9;border:1px solid #a5d6a7;border-radius:8px;padding:7px 10px;color:'+GREEN+';font-weight:700;">✅ '+esc(pkg.subject.code+' '+pkg.subject.name)+' · '+esc(pkg.room)+'<br><span style="font-weight:400;">นักเรียน '+pkg.students.length+' คน · ช่องคะแนน '+pkg.slots.filter(function(s){return !s.virtual;}).length+' ช่อง</span></div>';
    H.panel.querySelector('#sgshStep2').style.display='';
  }catch(e){
    info.innerHTML='<div style="color:'+RED+';font-weight:700;">❌ อ่านข้อมูลไม่ได้: '+esc(e.message)+'</div>';
  }
}

function runScan(){
  var info=H.panel.querySelector('#sgshScanInfo');
  H.scan=scanPage();
  if(!H.scan){
    info.innerHTML='<div style="color:'+RED+';font-weight:700;">❌ ไม่พบตารางที่มีเลขประจำตัวนักเรียนตรงกับข้อมูล</div>'+
      '<div style="font-size:12.5px;color:#607d8b;margin-top:4px;">เช็คว่า: เปิดหน้า "กรอกคะแนน" ของวิชา/ห้องที่ถูกต้อง และนักเรียนแสดงครบในหน้าเดียว<br>ถ้าใช่แล้วยังไม่เจอ — กดปุ่ม "🧪 วิเคราะห์หน้า" ด้านล่าง แล้วส่งข้อความที่ได้ให้ผู้พัฒนา</div>';
    return;
  }
  var matched=H.scan.rows.filter(function(r){return r.stu;}).length;
  info.innerHTML='<div style="background:#e8f5e9;border:1px solid #a5d6a7;border-radius:8px;padding:7px 10px;">✅ เจอนักเรียน <b>'+matched+'</b>/'+H.pkg.students.length+' คน · ช่องกรอกได้ <b>'+H.scan.cols.length+'</b> คอลัมน์</div>';
  // mapping rows
  var saved=loadMap();H.map={};
  var PHASE_TH={before_mid:'ก่อนกลางภาค',midterm:'กลางภาค',after_mid:'หลังกลางภาค',final:'ปลายภาค',other:'อื่นๆ',total:'รวม'};
  var COMBO='__combo__';
  var opts='<option value="">— ไม่เติม —</option>'+H.pkg.slots.map(function(s){var ph=PHASE_TH[s.phase]||'';return '<option value="'+esc(s.id)+'">'+esc(s.name)+' (เต็ม '+s.max+')'+(s.virtual?' ◆':(ph?' · '+ph:''))+'</option>';}).join('')+'<option value="'+COMBO+'">🧩 กำหนดเอง (รวมหลายช่อง)…</option>';
  var base=baseSlots();
  var mr=H.panel.querySelector('#sgshMapRows');mr.innerHTML='';
  H.scan.cols.forEach(function(col){
    var row=el('div','display:flex;gap:6px;align-items:center;margin-bottom:5px;');
    if(!col.fillable){
      // ช่องคำนวณอัตโนมัติ (ไม่มี onchange เช่น ก่อนกลางภาค) — ข้ามเสมอ กรอกไม่ได้จริง
      row.innerHTML='<div style="flex:1;font-size:12.5px;background:#f5f5f5;border-radius:6px;padding:5px 8px;color:#90a4ae;" title="'+esc(col.name)+'">'+esc(col.header)+'</div>'+
        '<div style="color:#90a4ae;">→</div>'+
        '<div style="flex:1.2;font-size:12px;color:#90a4ae;">🔒 คำนวณอัตโนมัติ (ข้ามเสมอ)</div>';
      mr.appendChild(row);
      return;
    }
    var pre=(saved&&saved[col.index]!==undefined)?saved[col.index]:guessSlot(col.header);
    // ตรวจว่า slot ที่จำไว้ยังมีอยู่ (เฉพาะกรณีเป็น string id เดี่ยว — combo ไม่ต้องเช็ค)
    if(!isCombo(pre)&&pre&&!H.pkg.slots.some(function(s){return s.id===pre;}))pre='';
    if(isCombo(pre)||pre)H.map[col.index]=pre;
    row.innerHTML='<div style="flex:1;font-size:12.5px;background:'+PURPLE_L+';border-radius:6px;padding:5px 8px;color:#311b92;" title="'+esc(col.name)+'">'+esc(col.header)+'</div>'+
      '<div style="color:#90a4ae;">→</div>'+
      '<select data-col="'+col.index+'" style="'+S+'flex:1.2;font-size:12.5px;border:1px solid #b39ddb;border-radius:6px;padding:5px;">'+opts+'</select>';
    mr.appendChild(row);
    // กล่องเลือกช่องจากระบบเราที่จะ "รวม" เข้าด้วยกัน (แสดงเฉพาะตอนเลือก "กำหนดเอง")
    var comboWrap=el('div','margin:2px 0 8px 0;padding:6px 8px;background:#f3e5f5;border-radius:6px;display:'+(isCombo(pre)?'':'none')+';');
    comboWrap.innerHTML='<div style="font-size:11px;color:#6a1b9a;margin-bottom:4px;">ติ๊กช่องจากระบบเราที่จะ "รวม" ลงช่อง SGS นี้:</div>'+
      base.map(function(s){var checked=isCombo(pre)&&pre.combo.indexOf(s.id)>=0;return '<label style="display:inline-flex;align-items:center;gap:4px;margin:2px 8px 2px 0;font-size:12px;"><input type="checkbox" data-combo-id="'+esc(s.id)+'"'+(checked?' checked':'')+'> '+esc(s.name)+' ('+s.max+')</label>';}).join('');
    mr.appendChild(comboWrap);
    var sel=row.querySelector('select');sel.value=isCombo(pre)?COMBO:(pre||'');
    sel.onchange=function(){
      if(this.value===COMBO){
        var existing=isCombo(H.map[this.dataset.col])?H.map[this.dataset.col].combo:[];
        H.map[this.dataset.col]={combo:existing};
        comboWrap.style.display='';
      }else{
        if(this.value)H.map[this.dataset.col]=this.value;else delete H.map[this.dataset.col];
        comboWrap.style.display='none';
      }
      saveMap();
      H.panel.querySelector('#sgshStep4').style.display='none';
    };
    var colIdx=col.index;
    comboWrap.querySelectorAll('input[data-combo-id]').forEach(function(cb){
      cb.onchange=function(){
        var cur=isCombo(H.map[colIdx])?H.map[colIdx].combo.slice():[];
        var id=this.dataset.comboId;
        if(this.checked){if(cur.indexOf(id)<0)cur.push(id);}
        else{cur=cur.filter(function(x){return x!==id;});}
        H.map[colIdx]={combo:cur};
        saveMap();
        H.panel.querySelector('#sgshStep4').style.display='none';
      };
    });
  });
  saveMap();
  H.panel.querySelector('#sgshStep3').style.display='';
  H.panel.querySelector('#sgshStep4').style.display='none';
}

function showPlan(){
  if(!Object.keys(H.map).length){flash('ยังไม่ได้จับคู่ช่องคะแนนเลย',true);return;}
  var plan=buildPlan();
  var info=H.panel.querySelector('#sgshPlanInfo');
  var partialCount=plan.fills.filter(function(f){return f.partial;}).length;
  var html='<div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:8px;">'+
    '<span style="background:#e8f5e9;color:'+GREEN+';border-radius:6px;padding:3px 8px;font-weight:700;font-size:12.5px;">จะเติม '+plan.fills.length+'</span>'+
    (plan.overwrites.length?'<span style="background:#ffe0b2;color:#e65100;border-radius:6px;padding:3px 8px;font-weight:700;font-size:12.5px;">🔁 จะทับของเดิม '+plan.overwrites.length+'</span>':'')+
    '<span style="background:#eceff1;color:#607d8b;border-radius:6px;padding:3px 8px;font-weight:700;font-size:12.5px;">ตรงอยู่แล้ว '+plan.already.length+'</span>'+
    (plan.conflicts.length?'<span style="background:#fff3e0;color:'+AMBER+';border-radius:6px;padding:3px 8px;font-weight:700;font-size:12.5px;">ค่าขัดแย้ง '+plan.conflicts.length+' (ข้าม)</span>':'')+
    (plan.missingInSgs.length?'<span style="background:#ffebee;color:'+RED+';border-radius:6px;padding:3px 8px;font-weight:700;font-size:12.5px;">ไม่เจอใน SGS '+plan.missingInSgs.length+' คน</span>':'')+
    (partialCount?'<span style="background:#fff3e0;color:'+AMBER+';border-radius:6px;padding:3px 8px;font-weight:700;font-size:12.5px;">🧩 รวมไม่ครบ '+partialCount+' ช่อง</span>':'')+
    '</div>';
  if(plan.conflicts.length){
    html+='<div style="font-size:12px;color:'+AMBER+';margin-bottom:6px;"><b>⚠️ ค่าขัดแย้ง (SGS มีค่าอยู่แล้ว ไม่ทับให้ — แก้เองถ้าต้องการ หรือติ๊ก "โหมดแก้ไขคะแนน" ด้านบนแล้วกดพรีวิวใหม่):</b><br>'+
      plan.conflicts.slice(0,15).map(function(c){return esc(c.row.stu.name)+' · '+esc(c.col.header)+': SGS='+esc(c.cur)+' เรา='+esc(c.val);}).join('<br>')+
      (plan.conflicts.length>15?'<br>…และอีก '+(plan.conflicts.length-15)+' รายการ':'')+'</div>';
  }
  if(plan.missingInSgs.length){
    html+='<div style="font-size:12px;color:'+RED+';margin-bottom:6px;"><b>❌ อยู่ในข้อมูลเรา แต่หาไม่เจอในหน้า SGS:</b><br>'+
      plan.missingInSgs.map(function(s){return esc(s.code+' '+s.name);}).join('<br>')+'</div>';
  }
  var rows=plan.fills.map(function(f){return {f:f,ow:false};}).concat(plan.overwrites.map(function(f){return {f:f,ow:true};}));
  if(rows.length){
    html+='<div style="flex:1;min-height:60px;overflow:auto;border:1px solid #e0e0e0;border-radius:8px;"><table style="width:100%;border-collapse:collapse;font-size:12px;">'+
      '<tr><th style="padding:3px 6px;background:'+PURPLE_L+';position:sticky;top:0;">นักเรียน</th><th style="padding:3px 6px;background:'+PURPLE_L+';position:sticky;top:0;">ช่อง SGS</th><th style="padding:3px 6px;background:'+PURPLE_L+';position:sticky;top:0;">คะแนน</th></tr>'+
      rows.map(function(r){var f=r.f;
        var valCell=r.ow?('<span style="text-decoration:line-through;color:#90a4ae;">'+esc(f.cur)+'</span> → <b>'+esc(f.val)+'</b>'):esc(f.val);
        return '<tr><td style="padding:2px 6px;border-top:1px solid #eee;">'+esc(f.row.stu.name)+(f.partial?' <span title="รวมจากช่องที่มีคะแนนเท่านั้น ยังไม่ครบทุกช่อง" style="color:'+AMBER+';font-weight:700;">🧩ไม่ครบ</span>':'')+(r.ow?' <span style="color:#e65100;font-weight:700;">🔁ทับ</span>':'')+'</td><td style="padding:2px 6px;border-top:1px solid #eee;">'+esc(f.col.header)+'</td><td style="padding:2px 6px;border-top:1px solid #eee;text-align:center;font-weight:700;color:'+(r.ow?'#e65100':(f.partial?AMBER:GREEN))+';">'+valCell+'</td></tr>';}).join('')+
      '</table></div>';
  }
  info.innerHTML=html;
  var fw=H.panel.querySelector('#sgshFillWrap');
  var total=plan.fills.length+plan.overwrites.length;
  var label=plan.overwrites.length?('✍️ เติมคะแนน '+total+' ช่อง (ทับของเดิม '+plan.overwrites.length+' ช่อง)'):('✍️ เติมคะแนน '+plan.fills.length+' ช่อง (เฉพาะช่องว่าง)');
  fw.innerHTML=total?btn(label,'width:100%;background:'+(plan.overwrites.length?'#e65100':GREEN)+';border-color:'+(plan.overwrites.length?'#e65100':GREEN)+';'):'<div style="color:#607d8b;font-size:13px;">ไม่มีช่องว่างที่ต้องเติม</div>';
  if(total){
    fw.querySelector('button').onclick=function(){
      var msg='ยืนยันเติมคะแนน '+total+' ช่อง?';
      if(plan.overwrites.length)msg+='\n\n⚠️ รวมถึง '+plan.overwrites.length+' ช่องที่ "ทับค่าเดิม" ที่มีอยู่แล้วใน SGS — ตรวจคอลัมน์คะแนนในตารางด้านบน (เดิม → ใหม่) ให้ถี่ถ้วนก่อน';
      msg+='\n\nบางหน้าของ SGS บันทึกลงฐานข้อมูลทันทีที่กรอกแต่ละช่อง (auto-save) โดยไม่มีปุ่ม Undo — กรุณาตรวจพรีวิวด้านบนให้ถี่ถ้วนก่อนกดตกลง';
      if(!confirm(msg))return;
      var n=doFill(plan.fills,'#c8e6c9');
      if(plan.overwrites.length)n+=doFill(plan.overwrites,'#ffe0b2');
      this.disabled=true;this.style.opacity='.6';this.textContent='✅ เติมแล้ว '+n+' ช่อง';
      flash('เติมคะแนนแล้ว '+n+' ช่อง — ถ้าหน้านี้มีปุ่มบันทึกแยก ให้ตรวจแล้วกดบันทึกเองด้วย');
    };
  }
  H.panel.querySelector('#sgshStep4').style.display='flex';
  H.panel.querySelector('#sgshStep4').scrollIntoView({block:'nearest'});
}

H.show=function(){if(H.panel){H.panel.style.display='';}else buildPanel();};
buildPanel();
})();
