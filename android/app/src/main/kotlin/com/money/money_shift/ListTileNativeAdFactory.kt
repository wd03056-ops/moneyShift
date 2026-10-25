package com.money.money_shift

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

/** AppCard 톤의 리스트형 네이티브 광고 팩토리 */
class ListTileNativeAdFactory(
    private val layoutInflater: LayoutInflater,
) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = layoutInflater.inflate(
            R.layout.native_ad_list_tile,
            null,
        ) as NativeAdView

        adView.mediaView = adView.findViewById(R.id.ad_media)
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        adView.bodyView = adView.findViewById(R.id.ad_body)
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        adView.iconView = adView.findViewById(R.id.ad_app_icon)
        adView.priceView = adView.findViewById(R.id.ad_price)
        adView.starRatingView = adView.findViewById(R.id.ad_stars)
        adView.storeView = adView.findViewById(R.id.ad_store)
        adView.advertiserView = adView.findViewById(R.id.ad_advertiser)

        (adView.headlineView as TextView).text = nativeAd.headline

        val mediaView = adView.mediaView as MediaView
        val mediaContent = nativeAd.mediaContent
        if (mediaContent != null) {
            mediaView.mediaContent = mediaContent
            mediaView.visibility = View.VISIBLE
        } else {
            mediaView.visibility = View.GONE
        }

        val bodyView = adView.bodyView as TextView
        if (nativeAd.body.isNullOrEmpty()) {
            bodyView.visibility = View.GONE
        } else {
            bodyView.visibility = View.VISIBLE
            bodyView.text = nativeAd.body
        }

        val cta = adView.callToActionView as Button
        if (nativeAd.callToAction.isNullOrEmpty()) {
            cta.visibility = View.INVISIBLE
        } else {
            cta.visibility = View.VISIBLE
            cta.text = nativeAd.callToAction
        }

        val iconView = adView.iconView as ImageView
        val icon = nativeAd.icon
        if (icon == null) {
            iconView.visibility = View.GONE
        } else {
            iconView.setImageDrawable(icon.drawable)
            iconView.visibility = View.VISIBLE
        }

        val priceView = adView.priceView as TextView
        if (nativeAd.price.isNullOrEmpty()) {
            priceView.visibility = View.GONE
        } else {
            priceView.visibility = View.VISIBLE
            priceView.text = nativeAd.price
        }

        val storeView = adView.storeView as TextView
        if (nativeAd.store.isNullOrEmpty()) {
            storeView.visibility = View.GONE
        } else {
            storeView.visibility = View.VISIBLE
            storeView.text = nativeAd.store
        }

        val stars = adView.starRatingView as RatingBar
        val rating = nativeAd.starRating
        if (rating == null) {
            stars.visibility = View.GONE
        } else {
            stars.rating = rating.toFloat()
            stars.visibility = View.VISIBLE
        }

        val advertiserView = adView.advertiserView as TextView
        if (nativeAd.advertiser.isNullOrEmpty()) {
            advertiserView.visibility = View.GONE
        } else {
            advertiserView.visibility = View.VISIBLE
            advertiserView.text = nativeAd.advertiser
        }

        adView.setNativeAd(nativeAd)
        return adView
    }
}
