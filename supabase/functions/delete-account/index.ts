import "@supabase/functions-js/edge-runtime.d.ts";
import { createSupabaseContext } from "@supabase/server";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return Response.json(body, {
    status,
    headers: corsHeaders,
  });
}

export default {
  fetch: async (req: Request) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    const { data: ctx, error: authError } =
      await createSupabaseContext(req, {
        auth: "user",
      });

    if (authError) {
      console.error("[DELETE_ACCOUNT] authentication failed:", {
        message: authError.message,
        code: authError.code,
        status: authError.status,
      });

      return jsonResponse(
        {
          ok: false,
          error: "ユーザー認証に失敗しました。",
          auth_message: authError.message,
          auth_code: authError.code,
        },
        authError.status ?? 401,
      );
    }

    const userId = ctx.userClaims?.id;

    if (!userId) {
      console.error(
        "[DELETE_ACCOUNT] authenticated but user id is unavailable",
      );

      return jsonResponse(
        {
          ok: false,
          error: "認証ユーザーを確認できませんでした。",
        },
        401,
      );
    }

    console.log(`[DELETE_ACCOUNT] authenticated user: ${userId}`);

    try {
      const { error } =
        await ctx.supabaseAdmin.auth.admin.deleteUser(userId);

      if (error) {
        console.error("[DELETE_ACCOUNT] deleteUser failed:", {
          message: error.message,
          status: error.status,
          code: error.code,
        });

        return jsonResponse(
          {
            ok: false,
            error: "アカウントの削除に失敗しました。",
            delete_message: error.message,
          },
          500,
        );
      }

      console.log(`[DELETE_ACCOUNT] deleted user: ${userId}`);

      return jsonResponse({ ok: true });
    } catch (error) {
      console.error("[DELETE_ACCOUNT] unexpected error:", error);

      return jsonResponse(
        {
          ok: false,
          error: "アカウントの削除に失敗しました。",
        },
        500,
      );
    }
  },
};