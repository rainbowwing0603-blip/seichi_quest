import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// The Supabase Edge Runtime provides this global; declare it for standalone Deno type-checking.
declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };
import { createClient } from "npm:@supabase/supabase-js@2";
import * as cheerio from "npm:cheerio@1.1.2";
const KEY = Deno.env.get("ROADSIDESTATION_GPS_RECONCILE_KEY");
const URLS=Array.from({length:10},(_,i)=>`https://www.seaview.jp/rs/${101+i}-111.htm`);
const compact=(v:string)=>v.normalize("NFKC").toLowerCase().replace(/^道の駅/,"").replace(/[\s　・･!！?？「」『』()（）♡★☆･・\.]/g,"").replace(/ステーション/g,"station");
const coord=(h:string):[number,number]|null=>{const m=decodeURIComponent(h).match(/([+-]?\d{2}\.\d+)\s*[,，]\s*([+-]?\d{3}\.\d+)/);if(!m)return null;const lat=Number(m[1]),lon=Number(m[2]);return Number.isFinite(lat)&&Number.isFinite(lon)&&Math.abs(lat)<=90&&Math.abs(lon)<=180?[lat,lon]:null;};
async function run(dryRun:boolean){
 const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
 const master:any[]=[];for(let f=0;;f+=1000){const {data,error}=await sb.from("roadside_station_registry").select("id,official_name,prefecture,municipality,candidate_confidence,metadata").range(f,f+999);if(error)throw error;master.push(...(data??[]));if((data??[]).length<1000)break;}
 if(master.length!==1234)throw new Error(`Expected 1234 registry rows; got ${master.length}`);
 const targets=master.filter(r=>r.candidate_confidence==="unverified");
 const rows:any[]=[];
 for(const url of URLS){const res=await fetch(url,{headers:{"user-agent":"SeichiQuest/1.0 data-maintenance"}});if(!res.ok)continue;const html=new TextDecoder("shift_jis").decode(new Uint8Array(await res.arrayBuffer()));const $=cheerio.load(html);
   $("a").each((i,a)=>{const h=$(a).attr("href")??"";if(!h.includes("mapion.co.jp"))return;const name=$(a).text().trim();const links=$("a").toArray();const k=links.indexOf(a);let c=null;for(let j=k+1;j<Math.min(k+5,links.length);j++){const gh=$(links[j]).attr("href")??"";c=coord(gh);if(c)break;}if(!c)return;const tr=$(a).closest("tr").text().replace(/\s+/g," ").trim();rows.push({name,key:compact(name),lat:c[0],lon:c[1],rowText:tr,url});});
 }
 let matched=0;const ambiguous:any[]=[];const pending:any[]=[];
 for(const t of targets){const tk=compact(t.official_name), muni=compact(t.municipality??"");let hits=rows.filter(r=>r.key===tk);
   if(hits.length!==1&&muni) hits=rows.filter(r=>(r.key.includes(tk)||tk.includes(r.key))&&compact(r.rowText).includes(muni));
   if(hits.length!==1){ambiguous.push({id:t.id,name:t.official_name,prefecture:t.prefecture,municipality:t.municipality,hits:hits.length});continue;}
   const h=hits[0];pending.push({id:t.id,patch:{candidate_latitude:h.lat,candidate_longitude:h.lon,candidate_source:h.url,candidate_checked_at:new Date().toISOString(),candidate_confidence:"candidate",metadata:{...(t.metadata??{}),gps_match_method:"normalized_name_or_municipality"}}});matched++;
 }
 if(!dryRun){for(const item of pending){const {error}=await sb.from("roadside_station_registry").update(item.patch).eq("id",item.id);if(error)throw error;}}
 console.log(JSON.stringify({dry_run:dryRun,targets:targets.length,matched,updated:dryRun?0:matched,remaining:ambiguous.length,ambiguous}));
}
const corsHeaders = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type, x-import-key","Access-Control-Allow-Methods":"POST, OPTIONS"};
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:corsHeaders});
 if(req.method!=="POST")return new Response("method not allowed",{status:405,headers:{...corsHeaders,"Allow":"POST, OPTIONS"}});
 if(!KEY)return Response.json({ok:false,error:"maintenance function is not configured"},{status:503,headers:corsHeaders});
 if(req.headers.get("x-import-key")!==KEY)return new Response("forbidden",{status:403,headers:corsHeaders});
 const payload=await req.json().catch(()=>({}));
 const dryRun=payload?.apply!==true;
 EdgeRuntime.waitUntil(run(dryRun).catch(e=>console.error("[gps-reconcile] background job failed",e)));
 return Response.json({ok:true,started:true,dry_run:dryRun},{headers:corsHeaders});
});