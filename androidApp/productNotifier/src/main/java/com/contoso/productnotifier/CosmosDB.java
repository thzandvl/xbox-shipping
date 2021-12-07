package com.contoso.productnotifier;


import android.util.Base64;
import android.util.Log;

import com.android.volley.AuthFailureError;
import com.android.volley.Request;
import com.android.volley.Response;
import com.android.volley.VolleyError;
import com.android.volley.VolleyLog;
import com.android.volley.toolbox.JsonObjectRequest;
import com.google.gson.Gson;

import org.json.JSONObject;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;


public class CosmosDB {

    final private String ENDPOINT = BuildConfig.cosmosEndpoint;
    final private String KEY = BuildConfig.cosmosKey;

    private String resourceLink;

    /**
     * Retrieve the database
     *
     * @param verb
     * @param resourceType
     * @param resourceLink
     * @param resourceId
     * @return
     */
    public String getData(String verb, String resourceType, String resourceLink, String resourceId) {
        this.resourceLink = resourceLink;

        String date = "";
        String authToken = "";
        try {
            /* get the date in HTTP format */
            date = DateTimeFormatter.ofPattern("EEE, dd MMM yyyy HH:mm:ss z").format(ZonedDateTime.now(ZoneId.of("GMT")));
            Log.i("DATE", date);

            /* generate the authorization token */
            authToken = generateAuthToken(verb, resourceType, resourceId, date, KEY);
            Log.i("AUTHTOKEN", authToken);
        } catch (Exception e) {
            Log.e("ERROR", e.toString());
        }

        String response = httpRequestGET(date, authToken);
        Log.i("GETDATA", response);
        return response;
    }


    /**
     * Add a subscription to the Cosmos DB
     *
     * @param verb
     * @param resourceType
     * @param resourceLink
     * @param resourceId
     * @param subscription
     * @return
     */
    public String addSubscription(String verb, String resourceType, String resourceLink, String resourceId, Subscription subscription) {
        this.resourceLink = resourceLink;

        String date = "";
        String authToken = "";
        try {
            /* get the date in HTTP format */
            date = DateTimeFormatter.ofPattern("EEE, dd MMM yyyy HH:mm:ss z").format(ZonedDateTime.now(ZoneId.of("GMT")));
            Log.i("DATE", date);

            /* generate the authorization token */
            authToken = generateAuthToken(verb, resourceType, resourceId, date, KEY);
            Log.i("AUTHTOKEN", authToken);
        } catch (Exception e) {
            Log.e("ERROR", e.toString());
        }

        /* serialize the subscription object to JSON */
        Gson gson = new Gson();
        String jsonString = gson.toJson(subscription);
        JSONObject jsonBody = new JSONObject();
        try {
            jsonBody = new JSONObject(jsonString);
            Log.i("JSON", jsonBody.toString());
        } catch (Exception e) {
            Log.e("JSON ERROR", e.toString());
        }

        /* build a POST request and return */
        return httpRequestPOST(date, authToken, jsonBody);
    }


    /**
     * Send an HTTP GET request
     *
     * @param date
     * @param authToken
     * @return
     */
    public String httpRequestGET(String date, String authToken) {
        JsonObjectRequest jsonObjReq = new JsonObjectRequest(
                Request.Method.GET,
                ENDPOINT + this.resourceLink,
                null,
                new Response.Listener<JSONObject>() {
                    @Override
                    public void onResponse(JSONObject response) {
                        Log.i("RESPONSE", response.toString());
                    }
                },
                new Response.ErrorListener() {
                    @Override
                    public void onErrorResponse(VolleyError error) {
                        Log.i("RESPONSE ERROR", error.toString());
                        error.printStackTrace();
                    }
                }) {
                    @Override
                    public Map<String, String> getHeaders() throws AuthFailureError
                    {
                        /* add headers to the request */
                        Map<String, String> headers = new HashMap();
                        headers.put("Content-Type", "application/json");
                        headers.put("Authorization", authToken);
                        headers.put("x-ms-version", "2017-02-22");
                        headers.put("x-ms-date", date);
                        return headers;
                    }
                };

        /* add request object to the queue */
        MainActivity.queue.add(jsonObjReq);

        /* return the string representation of the object */
        return jsonObjReq.toString();
    }


    /**
     * Send an HTTP POST request
     *
     * @param date
     * @param authToken
     * @param jsonBody
     * @return
     */
    public String httpRequestPOST(String date, String authToken, JSONObject jsonBody) {
        JsonObjectRequest jsonObjReq = new JsonObjectRequest(
                Request.Method.POST,
                ENDPOINT + this.resourceLink,
                jsonBody,
                new Response.Listener<JSONObject>() {
                    @Override
                    public void onResponse(JSONObject response)
                    {
                        Log.i("RESPONSE", response.toString());
                    }
                },
                new Response.ErrorListener() {
                    @Override
                    public void onErrorResponse(VolleyError error)
                    {
                        Log.e("POST RESPONSE ERROR", error.toString());
                        VolleyLog.e("VOLLEYLOG", error.getMessage());
                    }
                }) {
            @Override
            public Map getHeaders() throws AuthFailureError
            {
                /* add headers to the request */
                HashMap headers = new HashMap();
                headers.put("Content-Type", "application/json");
                headers.put("Authorization", authToken);
                headers.put("x-ms-version", "2017-02-22");
                headers.put("x-ms-date", date);
                try {
                    headers.put("x-ms-documentdb-partitionkey", "[\"" + jsonBody.get("category").toString() + "\"]");
                    Log.i("CATEGORY", jsonBody.get("category").toString());
                } catch (Exception e) {}
                return headers;
            }
        };

        /* add request object to the queue */
        MainActivity.queue.add(jsonObjReq);

        /* return the string representation of the object */
        return jsonObjReq.toString();
    }


    /**
     * Generate an authorization token for the Cosmos DB connection
     *
     * @param verb
     * @param resourceType
     * @param resourceId
     * @param date
     * @param key
     * @return
     */
    public String generateAuthToken(String verb, String resourceType, String resourceId, String date, String key) {
        byte[] Key = Base64.decode(key.getBytes(StandardCharsets.UTF_8), Base64.DEFAULT);

        /* make sure that the parameters are not null */
        verb = (verb != null) ? verb: "";
        resourceType = (resourceType != null) ? resourceType: "";
        resourceId = (resourceId != null) ? resourceId: "";

        /* construct the payload */
        String payLoad = String.format("%s\n%s\n%s\n%s\n%s\n",
                verb.toLowerCase(),
                resourceType.toLowerCase(),
                resourceId,
                date.toLowerCase(),
                ""
        );

        /* create the signature value */
        String signature = "";
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(Key, "HmacSHA256"));
            byte[] hashPayLoad = mac.doFinal(payLoad.getBytes(StandardCharsets.UTF_8));

            signature = Base64.encodeToString(hashPayLoad, Base64.DEFAULT);
            Log.i("SIGNATURE", signature);
        } catch (Exception e) {
            Log.e("ERROR", e.toString());
        }
        signature = signature.replace("\n", "");

        /* default values */
        String masterToken = "master";
        String tokenVersion = "1.0";

        /* encode the string to URI format */
        String authToken = "";
        try {
            authToken = URLEncoder.encode(String.format("type=%s&ver=%s&sig=%s",
                    masterToken,
                    tokenVersion,
                    signature), StandardCharsets.UTF_8.toString());
        } catch (Exception e) {
            Log.e("ERROR", e.toString());
        }

        /* return the authorization token */
        return authToken;
    }

}
