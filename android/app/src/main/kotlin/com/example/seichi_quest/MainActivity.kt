package com.example.seichi_quest

import android.os.Bundle
import android.view.Gravity
import android.widget.FrameLayout
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var adView: AdView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val banner = AdView(this).apply {
            setAdSize(AdSize.BANNER)
            adUnitId = "ca-app-pub-1391846841313915/2597290432"
            loadAd(AdRequest.Builder().build())
        }

        adView = banner

        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            gravity = Gravity.BOTTOM
            bottomMargin = (80 * resources.displayMetrics.density).toInt()
        }

        addContentView(banner, params)
    }

    override fun onDestroy() {
        adView?.destroy()
        adView = null
        super.onDestroy()
    }
}
