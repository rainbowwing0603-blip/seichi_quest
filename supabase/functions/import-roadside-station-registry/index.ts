import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import * as cheerio from "npm:cheerio@1.1.2";
import * as XLSX from "npm:xlsx@0.18.5";

const IMPORT_KEY = Deno.env.get("ROADSIDESTATION_IMPORT_KEY_V2");
const MLIT_XLS = "https://www.mlit.go.jp/road/Michi-no-Eki/file/list.xls";
const MLIT_PAGE = "https://www.mlit.go.jp/road/Michi-no-Eki/list.html";
const REGION_URLS = Array.from({length:10},(_,i)=>`https://www.seaview.jp/rs/${101+i}-111.htm`);

const prefRe = /^(北海道|東京都|京都府|大阪府|.{2,3}県)$/;
function norm(s: unknown): string {
  return String(s ?? "").replace(/^道の駅\s*/,"").replace(/[\s　]+/g," ").trim();
}
function prefFromAddress(s:string):string|null {
  const m=s.match(/^(北海道|東京都|京都府|大阪府|.{2,3}県)/); return m?.[1]??null;
}
function coord(href:string):[number,number]|null {
  const m=decodeURIComponent(href).match(/([+-]?\d{2}\.\d+)\s*[,，]\s*([+-]?\d{3}\.\d+)/);
  return m?[Number(m[1]),Number(m[2])]:null;
}

Deno.serve(async(req:Request)=>{ try {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405, headers: { "Allow": "POST" } });
  }
  if (!IMPORT_KEY) {
    console.error("[registry-import] required secret ROADSIDESTATION_IMPORT_KEY is not configured");
    return Response.json({ ok: false, error: "maintenance function is not configured" }, { status: 503 });
  }
  if (req.headers.get("x-import-key") !== IMPORT_KEY) {
    return new Response("forbidden", { status: 403 });
  }
  const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // 1) Authoritative registry from MLIT XLS.
  const xr=await fetch(MLIT_XLS,{headers:{"user-agent":"SeichiQuest/1.0 data-maintenance"}});
  if(!xr.ok) return Response.json({ok:false,stage:"mlit_fetch",status:xr.status},{status:502});
  const wb=XLSX.read(await xr.arrayBuffer(),{type:"array"});
  const official:any[]=[];
  for(const sn of wb.SheetNames){
    const grid:any[][]=XLSX.utils.sheet_to_json(wb.Sheets[sn],{header:1,defval:"",raw:false});
    let header=-1, pcol=-1,ncol=-1,rcol=-1,dcol=-1,lcol=-1,ucol=-1;
    for(let i=0;i<Math.min(grid.length,30);i++){
      const row=grid[i].map(norm);
      if(row.includes("県名")&&row.some(x=>x.replace(/\s/g,"")==="駅名")){
        header=i;pcol=row.indexOf("県名");ncol=row.findIndex(x=>x.replace(/\s/g,"")==="駅名");
        rcol=row.indexOf("登録回");dcol=row.indexOf("登録年月");lcol=row.indexOf("所在地");
        ucol=row.findIndex(x=>x.includes("ホームページ"));
        break;
      }
    }
    if(header<0) continue;
    for(let i=header+1;i<grid.length;i++){
      const row=grid[i]; const prefecture=norm(row[pcol]); const name=norm(row[ncol]);
      if(!prefRe.test(prefecture)||!name) continue;
      official.push({
        official_name:name,prefecture,
        municipality:lcol>=0?norm(row[lcol]):null,
        registration_round:rcol>=0?Number((norm(row[rcol]).match(/\d+/)||[])[0]||null):null,
        official_source_url:ucol>=0&&/^https?:/.test(norm(row[ucol]))?norm(row[ucol]):MLIT_PAGE,
        source_checked_at:new Date().toISOString(),
        status:"registered",
        metadata:{
          source:"MLIT official XLS",registry_source:MLIT_PAGE,
          registration_text:rcol>=0?norm(row[rcol]):null,
          registration_date_text:dcol>=0?norm(row[dcol]):null
        }
      });
    }
  }
  const om=new Map<string,any>(); for(const r of official) om.set(r.prefecture+"\0"+r.official_name,r);
  let master=[...om.values()];
  if(master.length===1231){
    for(const x of [
      {prefecture:"神奈川県",official_name:"やどりきテラス 清流の里",municipality:"足柄上郡松田町"},
      {prefecture:"兵庫県",official_name:"こんだ温泉ぬくもりの郷",municipality:"丹波篠山市"},
      {prefecture:"熊本県",official_name:"くらたけ天草戦国ミュージアム",municipality:"天草市"},
    ]){
      const k=x.prefecture+"\0"+x.official_name;
      if(!om.has(k)) om.set(k,{...x,registration_round:65,official_source_url:"https://www.mlit.go.jp/report/press/road01_hh_002138.html",source_checked_at:new Date().toISOString(),status:"opening_pending",metadata:{source:"MLIT 65th registration press release",registration_date_text:"2026-09-04"}});
    }
    master=[...om.values()];
  }
  if(master.length!==1234) return Response.json({ok:false,stage:"mlit_parse",parsed:master.length,sheets:wb.SheetNames},{status:409});

  // The database RPC stages, validates, upserts and removes stale rows in one transaction.
  // Existing place links and GPS-enrichment fields are preserved for matching stations.
  const {data:replacementResult,error:replacementError}=await sb.rpc(
    "replace_roadside_station_registry",
    {p_rows:master},
  );
  if(replacementError)throw replacementError;
  if(!replacementResult?.ok || replacementResult.total!==1234){
    throw new Error("Atomic registry replacement returned an unexpected result");
  }

  // Re-link already verified Gunma places.
  const {data:gp,error:gpe}=await sb.from("places").select("id,name,prefecture,city,location_verified_at").eq("category","roadside_station").eq("prefecture","群馬県"); if(gpe)throw gpe;
  let linked=0;
  for(const p of gp??[]){
    const name=norm(p.name);
    const {data:m}=await sb.from("roadside_station_registry").select("id,metadata").eq("prefecture","群馬県").eq("official_name",name).maybeSingle();
    if(!m)continue;
    const {error}=await sb.from("roadside_station_registry").update({place_id:p.id,status:"open",source_checked_at:p.location_verified_at,metadata:{...(m.metadata??{}),verified_existing_place:true}}).eq("id",m.id);
    if(error)throw error; linked++;
  }
  const {count}=await sb.from("roadside_station_registry").select("*",{count:"exact",head:true});
  return Response.json({ok:true,official:master.length,total:count,gunma_linked:linked});
} catch (e) {
  // Keep stack traces and source details in server logs only.
  console.error("[registry-import] failed", e);
  return Response.json({ ok: false, error: "registry import failed" }, { status: 500 });
}});