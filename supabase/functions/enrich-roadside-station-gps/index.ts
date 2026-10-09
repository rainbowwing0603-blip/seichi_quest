import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import * as cheerio from "npm:cheerio@1.1.2";
const KEY = Deno.env.get("ROADSIDESTATION_GPS_ENRICH_KEY");
const URLS=Array.from({length:10},(_,i)=>`https://www.seaview.jp/rs/${101+i}-111.htm`);
const norm=(v:string)=>v.replace(/^道の駅[\s　]*/,"").replace(/[\s　]+/g," ").trim();
const coord=(h:string):[number,number]|null=>{const m=decodeURIComponent(h).match(/([+-]?\d{2}\.\d+)\s*[,，]\s*([+-]?\d{3}\.\d+)/);if(!m)return null;const lat=Number(m[1]),lon=Number(m[2]);return Number.isFinite(lat)&&Number.isFinite(lon)&&Math.abs(lat)<=90&&Math.abs(lon)<=180?[lat,lon]:null;};
async function run(){try{

 const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
 const master:any[]=[];
 for(let from=0;;from+=1000){const {data,error}=await sb.from("roadside_station_registry").select("id,official_name,prefecture").range(from,from+999);if(error)throw error;master.push(...(data??[]));if((data??[]).length<1000)break;}
 if(master.length!==1234)throw new Error(`Expected 1234 registry rows; got ${master.length}`);
 const index=new Map(master.map(r=>[r.prefecture+"\0"+norm(r.official_name),r.id]));
 const updates=new Map<string,any>(); const ambiguous=new Set<string>();
 for(const url of URLS){
   const res=await fetch(url,{headers:{"user-agent":"SeichiQuest/1.0 data-maintenance"}});if(!res.ok)continue;
   const html=new TextDecoder("shift_jis").decode(new Uint8Array(await res.arrayBuffer()));const $=cheerio.load(html);const links=$("a").toArray();
   for(let k=0;k<links.length;k++){
     const a=links[k],h=$(a).attr("href")??"";if(!h.includes("mapion.co.jp"))continue;
     const n=norm($(a).text());if(!n)continue;
     let g:any=null;
     for(let j=k+1;j<Math.min(k+4,links.length);j++){const gh=$(links[j]).attr("href")??"";if((gh.includes("google.co.jp")||gh.includes("google.com"))&&coord(gh)){g=links[j];break;}}
     if(!g)continue;const c=coord($(g).attr("href")??"");if(!c)continue;
     const hits=[...index.keys()].filter(key=>key.endsWith("\0"+n));if(hits.length!==1)continue;
     const id=index.get(hits[0]);if(!id||ambiguous.has(id))continue;
     const previous=updates.get(id);
     if(previous&&(previous.candidate_latitude!==c[0]||previous.candidate_longitude!==c[1])){updates.delete(id);ambiguous.add(id);continue;}
     updates.set(id,{id,candidate_latitude:c[0],candidate_longitude:c[1],candidate_source:url,candidate_checked_at:new Date().toISOString(),candidate_confidence:"candidate"});
   }
 }
 for(const u of updates.values()){const {error}=await sb.from("roadside_station_registry").update(u).eq("id",u.id);if(error)throw error;}
 console.log(JSON.stringify({ok:true,master:master.length,matched:updates.size,ambiguous:ambiguous.size,unmatched:master.length-updates.size-ambiguous.size}));
}catch(e){console.error("[gps-enrich] job failed",e);throw e;}}
const corsHeaders = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type, x-import-key","Access-Control-Allow-Methods":"POST, OPTIONS"};
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:corsHeaders});
 if(req.method!=="POST")return new Response("method not allowed",{status:405,headers:{...corsHeaders,"Allow":"POST, OPTIONS"}});
 if(!KEY)return Response.json({ok:false,error:"maintenance function is not configured"},{status:503,headers:corsHeaders});
 if(req.headers.get("x-import-key")!==KEY)return new Response("forbidden",{status:403,headers:corsHeaders});
 EdgeRuntime.waitUntil(run().catch(e=>console.error("[gps-enrich] background job failed",e)));
 return Response.json({ok:true,started:true},{headers:corsHeaders});
});