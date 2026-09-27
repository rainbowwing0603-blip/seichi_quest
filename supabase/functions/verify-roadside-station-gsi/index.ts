import "jsr:@supabase/functions-js/edge-runtime.d.ts";
Deno.serve(()=>new Response(JSON.stringify({ok:true,status:"secured"}),{headers:{"content-type":"application/json"}}));