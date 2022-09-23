package com.cometchat.flutter_chat_ui_kit

import android.app.Activity
import android.content.Context
import android.content.IntentSender
import android.location.*
import android.location.LocationListener
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.*
import com.google.android.gms.tasks.Task
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONException
import java.util.*
import com.google.android.gms.location.LocationRequest


class LocationService : AppCompatActivity() {
    private var locationManager: LocationManager? = null
    private lateinit var mContext: Context
    private lateinit var activity: Activity
    private var fusedLocationProviderClient: FusedLocationProviderClient? = null
    private var locationListener: LocationListener? = null
    private var location: Location? = null
    private val locationRequestCheckCode = 111

    fun getCurrentLocation(context: Context, _activity: Activity, result: MethodChannel.Result){
        mContext=context
        activity = _activity

        locationManager = mContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager

        val gpsprovider = locationManager!!.isProviderEnabled(LocationManager.GPS_PROVIDER)
        initLocation()
        if (!gpsprovider) {
            onGpsDialog()
        } else {
            getLatitudeLongitude(result)
        }
    }

    private fun onGpsDialog() {

        val locationRequest: LocationRequest = LocationRequest.create()
        locationRequest.priority = LocationRequest.PRIORITY_HIGH_ACCURACY
        val builder: LocationSettingsRequest.Builder =  LocationSettingsRequest.Builder()
                .addLocationRequest(locationRequest)

        builder.setAlwaysShow(true)

        val task: Task<LocationSettingsResponse> = LocationServices.getSettingsClient(activity).checkLocationSettings(builder.build())


        task.addOnCompleteListener { task ->
            try {
                task.getResult(ApiException::class.java)
            } catch (exception: ApiException) {
                when (exception.statusCode) {
                    LocationSettingsStatusCodes.RESOLUTION_REQUIRED ->
                        try {
                            val resolvable: ResolvableApiException = exception as ResolvableApiException
                            resolvable.startResolutionForResult(
                                    activity,
                                    locationRequestCheckCode)
                        } catch (e: IntentSender.SendIntentException) {
                        } catch (e: ClassCastException) {
                        }
                    LocationSettingsStatusCodes.SETTINGS_CHANGE_UNAVAILABLE -> {
                    }
                }
            }
        }
    }

    private fun getLatitudeLongitude(result: MethodChannel.Result){

        fusedLocationProviderClient?.lastLocation?.addOnSuccessListener { location_ ->
            when {
                location_!=null -> {
                    try {
                        val lon = location_.longitude
                        val lat = location_.latitude
                        result.success(mapOf("status" to true, "latitude" to lat, "longitude" to lon))
                    } catch (e: JSONException) {
                        e.printStackTrace()
                        result.success(mapOf("status" to false, "message" to "Unable to find location."))
                    }
                }
                location!=null -> {
                    try {
                        val lon: Double = location!!.longitude
                        val lat: Double = location!!.latitude
                        result.success(mapOf("status" to true, "latitude" to lat, "longitude" to lon))
                    } catch (e: JSONException) {
                        e.printStackTrace()
                        Log.d("location", "Unable to find location.")
                        result.success(mapOf("status" to false, "message" to "Unable to find location."))
                    }
                }
                else -> {
                    result.success(mapOf("status" to false, "message" to "Unable to find location."))
                }
            }
        }
    }

    private fun initLocation() {
        fusedLocationProviderClient = LocationServices.getFusedLocationProviderClient(mContext)
        locationListener = LocationListener { l -> location = l }
        locationManager = mContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager?
    }


    fun getAddressFromLatitudeLongitude(call: MethodCall,result: MethodChannel.Result,context: Context) {
        val latitude: Double = call.argument("latitude") ?: 0.0
        val longitude: Double = call.argument("longitude") ?: 0.0

        val geocoder = Geocoder(context, Locale.getDefault())
        val addresses: List<Address?>  = geocoder.getFromLocation(latitude, longitude, 1)


        if(addresses.isNotEmpty()){
            result.success(getAddressMap(addresses[0]))
        }else{
            result.error("NO DATA", "Address not found", "Address List came empty")
        }
    }

    private fun getAddressMap(address: Address?): HashMap<String, Any?>? {
        if (address==null) return null

        return hashMapOf(
                "addressLine" to address.getAddressLine(0),
                "adminArea" to address.adminArea,
                "city" to address.locality,
                "state" to address.adminArea,
                "country" to address.countryName,
                "postalCode" to address.postalCode,
                "knownName" to address.featureName
        )

    }
}