import Toybox.Communications;
import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Strip leading non-printable-ASCII chars (emojis, symbols) from a string.
//! Loop embeds emoji in preset reason names (e.g. "♦ sport") which don't
//! render on Garmin devices and prevent .equals() comparisons with preset list names.
function stripLeadingEmoji(s as Lang.String) as Lang.String {
    var chars = s.toCharArray();
    var start = 0;
    while (start < chars.size()) {
        var c = chars[start].toNumber();
        // Skip non-printable-ASCII (emoji, symbols) and leading spaces
        if (c != null && c > 32 && c <= 126) {
            break;
        }
        start++;
    }
    if (start == 0) { return s; }
    return s.substring(start, s.length()) as Lang.String;
}

//! Returns true if a fixed-duration Temporary Override is still within its window.
//! Parses created_at (ISO 8601 UTC: "YYYY-MM-DDTHH:MM:SS.sssZ") and checks
//! that now < created_at + duration_minutes.
function isOverrideStillActive(override as Lang.Dictionary) as Lang.Boolean {
    var createdAtRaw = override.get("created_at");
    var durationRaw  = override.get("duration");
    if (createdAtRaw == null || durationRaw == null) { return false; }

    var durationMin = durationRaw instanceof Lang.Float
        ? durationRaw.toNumber()
        : (durationRaw as Lang.Number).toNumber();
    if (durationMin == null || durationMin <= 0) { return false; }

    // Parse "YYYY-MM-DDTHH:MM:SS..." — only the first 19 chars matter
    var s = createdAtRaw.toString();
    if (s.length() < 19) { return false; }
    var year   = s.substring(0, 4).toNumber();
    var month  = s.substring(5, 7).toNumber();
    var day    = s.substring(8, 10).toNumber();
    var hour   = s.substring(11, 13).toNumber();
    var minute = s.substring(14, 16).toNumber();
    var second = s.substring(17, 19).toNumber();
    if (year == null || month == null || day == null ||
        hour == null || minute == null || second == null) { return false; }

    var createdAt = Toybox.Time.Gregorian.moment({
        :year => year, :month => month, :day => day,
        :hour => hour, :minute => minute, :second => second
    });
    var expiresAt = createdAt.add(new Toybox.Time.Duration(durationMin * 60));
    return Toybox.Time.now().lessThan(expiresAt);
}

//! Service responsible for all Nightscout API communications
class NightscoutService {

    private var callback as Method?;
    private var profileToActivate as Lang.String = "";

    // API v3 bearer (JWT) obtained from the Nightscout access token, cached in
    // memory only until shortly before it expires (epoch seconds).
    private var bearerToken as Lang.String = "";
    private var bearerExpiry as Lang.Number = 0;
    private static const BEARER_MARGIN_SEC as Lang.Number = 60;

    private var appState as AppState;

    // Serialized request queue: the device's BLE bridge is unreliable under
    // concurrent web requests (they can crash the app), so only ONE request is
    // ever in flight. Others wait here and are dispatched as each completes.
    private var requestQueue as Lang.Array = [];
    private var requestInFlight as Lang.Boolean = false;
    private var currentResponder as Method?;
    // Timestamp when the current in-flight request was dispatched.
    // If the app is suspended mid-request (e.g. during an activity), the callback
    // may never fire. After REQUEST_TIMEOUT_MS we report a timeout to the
    // request's responder and let the queue drain. The BLE bridge to the phone
    // routinely needs several seconds (Garmin allows far longer), so this is a
    // watchdog for lost callbacks, not a latency budget.
    private var requestStartTime as Lang.Number = 0;
    // Until this System.getTimer() value, an abandoned request may still call
    // back late: its answer would be mistaken for the current one.
    private var abandonedUntilMs as Lang.Number = 0;
    private static const REQUEST_TIMEOUT_MS as Lang.Number = 15000;

    function initialize(appState as AppState) {
        self.appState = appState;
    }

    //! Set callback for receiving data updates
    function setCallback(callback as Method) as Void {
        self.callback = callback;
    }

    //! A request was given up on: its callback may still arrive for a while.
    function noteAbandonedRequest(nowMs as Lang.Number) as Void {
        abandonedUntilMs = nowMs + Constants.ABANDON_GRACE_MS;
    }

    //! True while an irreversible request must not be sent (late-callback doubt).
    function isSendBlockedByDoubt(nowMs as Lang.Number) as Lang.Boolean {
        return nowMs < abandonedUntilMs;
    }

    //! Enqueue a web request; it runs when no other request is in flight.
    //! `urgent` requests (user actions like sending carbs) jump ahead of the
    //! queued background fetches.
    private function enqueue(url as Lang.String, params as Lang.Dictionary, options as Lang.Dictionary, responder as Method, urgent as Lang.Boolean) as Void {
        enqueueRequest({ "url" => url, "params" => params, "options" => options, "responder" => responder }, urgent);
    }

    //! Same, for an already built request (the bolus request carries a "bolus" mark).
    private function enqueueRequest(req as Lang.Dictionary, urgent as Lang.Boolean) as Void {
        if (urgent) {
            var reordered = [req];
            reordered.addAll(requestQueue);
            requestQueue = reordered;
        } else {
            requestQueue.add(req);
        }
        dispatchNext();
    }

    //! Dispatch the next queued request if the bridge is free.
    private function dispatchNext() as Void {
        if (requestInFlight) {
            if (System.getTimer() - requestStartTime < REQUEST_TIMEOUT_MS) {
                return;
            }
            // Lost callback: tell the responder so the UI/state doesn't wait forever.
            var stale = currentResponder;
            noteAbandonedRequest(System.getTimer());
            requestInFlight = false;
            currentResponder = null;
            if (stale != null) {
                stale.invoke(Constants.REQUEST_TIMEOUT_CODE, null);
            }
        }
        // The responder above may itself have queued + dispatched a request.
        if (requestQueue.size() == 0 || requestInFlight) {
            return;
        }
        var req = requestQueue[0];
        requestQueue = requestQueue.slice(1, null);
        // A bolus that waited too long in the queue is dropped HERE, at dispatch
        // time (not by a screen timer): it can never be delivered after the rider
        // was told it did not go. The responder reports "nothing sent".
        if (req.hasKey("bolus") && isBolusQueueExpired(req.get("queuedAt") as Lang.Number, System.getTimer())) {
            var dropped = req.get("responder") as Method;
            dropped.invoke(Constants.QUEUE_BUSY_CODE, null);
            dispatchNext();
            return;
        }
        requestInFlight = true;
        requestStartTime = System.getTimer();
        currentResponder = req.get("responder") as Method;
        if (req.hasKey("bolus")) {
            appState.bolusDispatchedMs = requestStartTime;
        }
        Communications.makeWebRequest(
            req.get("url"),
            req.get("params"),
            req.get("options"),
            self.method(:onRequestComplete)
        );
    }

    //! Single completion hook: forwards to the request's own responder, then
    //! frees the bridge and dispatches the next queued request.
    function onRequestComplete(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        // Late answer to a request already given up on (watchdog): ignore it.
        if (!requestInFlight) {
            return;
        }
        var responder = currentResponder;
        requestInFlight = false;
        currentResponder = null;
        if (responder != null) {
            responder.invoke(responseCode, data);
        }
        dispatchNext();
    }


    //! Activate a specific override preset
    function activatePreset(presetName as Lang.String) as Void {
        var baseUrl = getNightscoutUrl();
        var token = getNightscoutToken();
        
        if (baseUrl.length() == 0 || token.length() == 0) {
            System.println("Nightscout URL or token not configured");
            appState.setProfileError(Constants.NOT_CONFIGURED_CODE);
            return;
        }
        
        System.println("Activating preset: " + presetName);

        // Create treatment entry for Loop override
        var treatmentData = {
            "eventType" => "Temporary Override",
            "reason" => presetName,
            "reasonDisplay" => presetName
        };
        profileToActivate = presetName;
        var treatmentUrl = baseUrl + "/api/v2/notifications/loop?token=" + token;
        enqueue(
            treatmentUrl,
            treatmentData,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
            },
            self.method(:onReceivePresetActivationResponse),
            true
        );
    }

    function deactivatePreset() as Void {
        var baseUrl = getNightscoutUrl();
        var token = getNightscoutToken();
        
        if (baseUrl.length() == 0 || token.length() == 0) {
            System.println("Nightscout URL or token not configured");
            appState.setProfileError(Constants.NOT_CONFIGURED_CODE);
            return;
        }
        

        // Create treatment entry for Loop override
        var treatmentData = {
            "eventType" => "Temporary Override Cancel",
            "reasonDisplay" => "Temporary Override Cancel"
        };
        profileToActivate = Constants.DEFAULT_OVERRIDE_PROFIL;

        var treatmentUrl = baseUrl + "/api/v2/notifications/loop?token=" + token;
        enqueue(
            treatmentUrl,
            treatmentData,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
            },
            self.method(:onReceivePresetActivationResponse),
            true
        );
    }

    //! Fetch glucose data from Nightscout: a single request returns both the
    //! current value (most recent entry) and the ~4h history used for the
    //! trend chart, avoiding two concurrent BLE requests.
    function fetchGlucoseData() as Void {
        appState.lastFetchAttemptMs = System.getTimer();
        var url = buildUrl("/api/v1/entries.json?count=48");

        enqueue(
            url,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                }
            },
            self.method(:onReceiveGlucoseData),
            false
        );
    }

    //! Fetch temp basal data and active profile
    function fetchTempBasalData() as Void {
        var baseUrl = getNightscoutUrl();
        var token = getNightscoutToken();



        // Two requests: the profile list (available presets) and the recent
        // overrides (which one is active). Both go through the serialized queue,
        // so they never hit the BLE bridge concurrently.
        var profileUrl = baseUrl + "/api/v1/profile.json?token=" + token;
        enqueue(
            profileUrl,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                }
            },
            method(:onReceiveTempBasalData),
            false
        );

        var overrideUrl = baseUrl + "/api/v1/treatments.json?find[eventType]=Temporary%20Override&count=5&token=" + token;
        enqueue(
            overrideUrl,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                }
            },
            method(:onReceiveActiveOverride),
            false
        );
    }

    //! Parse the profile list into the available override presets. Note: this
    //! response does NOT set the active profile — that is owned solely by
    //! onReceiveActiveOverride, so the two concurrent responses can't race.
     function onReceiveTempBasalData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        var presets = [];
        if (responseCode == 200 && data != null) {
            try {
                if (data instanceof Lang.Array && data.size() > 0) {
                    var firstProfile = data[0];
                    if (firstProfile instanceof Lang.Dictionary && firstProfile.hasKey("loopSettings")) {
                        var loopSettings = firstProfile.get("loopSettings");
                        if (loopSettings instanceof Lang.Dictionary && loopSettings.hasKey("overridePresets")) {
                            var overridePresets = loopSettings.get("overridePresets");
                            if (overridePresets instanceof Lang.Array) {
                                for (var i = 0; i < overridePresets.size(); i++) {
                                    var presetData = overridePresets[i];
                                    if (presetData instanceof Lang.Dictionary && presetData.hasKey("name")) {
                                        presets.add({
                                            "name" => presetData.get("name"),
                                            "data" => presetData
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (e) {
                presets = [];
            }
        }

        appState.overridePresets = presets;
        if (callback != null) {
            callback.invoke("overridePresets", presets);
        }
        WatchUi.requestUpdate();
    }

     function onReceiveActiveOverride(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200 && data != null) {
            try {
                if (data instanceof Lang.Array) {
                    // Chercher le premier override SANS duration (donc encore actif)
                    var foundActiveOverride = false;
                    
                    for (var i = 0; i < data.size() && !foundActiveOverride; i++) {
                        var override = data[i];
                        if (override instanceof Lang.Dictionary) {
                            // Si l'override a durationType = "indefinite", il est actif
                            // Si il a une duration numérique, cela veut dire qu'il a expiré
                            var isActive = false;
                            if (override.hasKey("durationType")) {
                                var durationType = override.get("durationType");
                                if (durationType != null && durationType.toString().equals("indefinite")) {
                                    isActive = true;
                                } else {
                                    // Fixed-duration override: active if created_at + duration > now
                                    isActive = isOverrideStillActive(override);
                                }
                            } else if (!override.hasKey("duration") || override.get("duration") == null) {
                                isActive = true;
                            } else {
                                isActive = isOverrideStillActive(override);
                            }
                            
                            if (isActive) {
                                if (override.hasKey("reason")) {
                                    var reason = override.get("reason");
                                    if (reason != null) {
                                        var reasonStr = stripLeadingEmoji(reason.toString());
                                        appState.updateActiveProfile(reasonStr);
                                         foundActiveOverride = true;
                                    }
                                }
                            }
                        }
                    }
                    
                    if (!foundActiveOverride) {
                        appState.updateActiveProfile(Constants.DEFAULT_OVERRIDE_PROFIL);
                    }
                } else {
                        appState.updateActiveProfile(Constants.DEFAULT_OVERRIDE_PROFIL);
                }
            } catch (e) {
                        appState.updateActiveProfile(Constants.DEFAULT_OVERRIDE_PROFIL);
            }
        } else {
            appState.updateActiveProfile(Constants.DEFAULT_OVERRIDE_PROFIL);
        }
        
        // Notify callback with active profile data
        if (callback != null) {
            callback.invoke("activeProfile", appState.activeProfile);
        }
        
        // Forcer la mise à jour de l'affichage
        WatchUi.requestUpdate();
    }

    

    //! Fetch Loop's recommended bolus (read-only, informational).
    //! Step 1: exchange the access token for a bearer (API v3 needs one) via
    //! /api/v2/authorization/request/<token>; step 2: read the latest
    //! devicestatus via /api/v3/devicestatus. The bearer is cached until it
    //! is about to expire, so most calls only do step 2.
    function fetchRecommendedBolus() as Void {
        if (getNightscoutUrl().length() == 0 || getNightscoutToken().length() == 0) {
            appState.setRecommendedBolusError(Constants.NOT_CONFIGURED_CODE);
            return;
        }
        if (hasValidBearer()) {
            requestDeviceStatus();
            return;
        }
        enqueue(
            getNightscoutUrl() + "/api/v2/authorization/request/" + getNightscoutToken(),
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                }
            },
            self.method(:onReceiveAuthToken),
            false
        );
    }

    private function hasValidBearer() as Lang.Boolean {
        if (bearerToken.length() == 0) {
            return false;
        }
        return Toybox.Time.now().value() < bearerExpiry - BEARER_MARGIN_SEC;
    }

    //! Step 2: latest devicestatus, newest first, only the "loop" object.
    private function requestDeviceStatus() as Void {
        enqueue(
            getNightscoutUrl() + "/api/v3/devicestatus?limit=1&sort%24desc=created_at&fields=loop",
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
                    "Authorization" => "Bearer " + bearerToken
                }
            },
            self.method(:onReceiveRecommendedBolus),
            true
        );
    }

    //! Authorization response: { "token": "<jwt>", "exp": <epoch s>, ... }.
    //! On success, chains straight into the devicestatus request.
    function onReceiveAuthToken(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        bearerToken = "";
        bearerExpiry = 0;
        if (responseCode != 200 || data == null || !(data instanceof Lang.Dictionary)) {
            appState.setRecommendedBolusError(responseCode);
            return;
        }
        var token = data.get("token");
        if (!(token instanceof Lang.String) || token.length() == 0) {
            appState.setRecommendedBolusError(responseCode);
            return;
        }
        bearerToken = token;
        var exp = data.get("exp");
        if (exp instanceof Lang.Number) {
            bearerExpiry = exp;
        } else {
            // No expiry given: don't cache across calls
            bearerExpiry = 0;
        }
        requestDeviceStatus();
    }

    //! devicestatus v3 response: { "status": 200, "result": [ { "loop": { "recommendedBolus": 1.65, "timestamp": "..." } } ] }
    function onReceiveRecommendedBolus(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 401 || responseCode == 403) {
            // Bearer rejected or expired: forget it so the next call re-authenticates
            bearerToken = "";
            bearerExpiry = 0;
        }
        if (responseCode != 200 || data == null || !(data instanceof Lang.Dictionary)) {
            appState.setRecommendedBolusError(responseCode);
            return;
        }
        try {
            var result = data.get("result");
            if (!(result instanceof Lang.Array) || result.size() == 0) {
                appState.setRecommendedBolusError(responseCode);
                return;
            }
            var entry = result[0];
            if (!(entry instanceof Lang.Dictionary)) {
                appState.setRecommendedBolusError(responseCode);
                return;
            }
            var loopData = entry.get("loop");
            if (!(loopData instanceof Lang.Dictionary)) {
                appState.setRecommendedBolusError(responseCode);
                return;
            }
            var bolus = loopData.get("recommendedBolus");
            var units = 0.0;
            if (bolus instanceof Lang.Float) {
                units = bolus;
            } else if (bolus instanceof Lang.Number) {
                units = bolus.toFloat();
            } else {
                // No recommendation published in this status
                appState.setRecommendedBolusError(responseCode);
                return;
            }
            var stamp = loopData.get("timestamp");
            var isoTime = stamp instanceof Lang.String ? stamp : "";
            appState.updateRecommendedBolus(units, isoTime);
        } catch (e) {
            appState.setRecommendedBolusError(responseCode);
        }
    }

    //! Send a remote bolus entry to Loop (REAL INSULIN). Never retried here, and
    //! never called from tests. Nothing is sent when settings are incomplete.
    function sendBolusEntry(bolusData as Lang.Dictionary) as Void {
        // A late answer from an abandoned request could be taken for this one's
        // answer and report "sent" wrongly: refuse, nothing is sent.
        if (isSendBlockedByDoubt(System.getTimer())) {
            onReceiveBolusEntryResponse(Constants.QUEUE_BUSY_CODE, null);
            return;
        }
        if (getNightscoutUrl().length() == 0 || getNightscoutToken().length() == 0 || !hasOtpSecret()) {
            onReceiveBolusEntryResponse(Constants.NOT_CONFIGURED_CODE, null);
            return;
        }
        System.println("Sending remote bolus entry");
        enqueueRequest({
            "url" => getNightscoutUrl() + "/api/v2/notifications/loop?token=" + getNightscoutToken(),
            "params" => bolusData,
            "options" => {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
            },
            "responder" => self.method(:onReceiveBolusEntryResponse),
            "bolus" => true,
            "queuedAt" => System.getTimer()
        }, true);
    }

    //! True when a queued bolus has waited longer than allowed.
    function isBolusQueueExpired(queuedAtMs as Lang.Number, nowMs as Lang.Number) as Lang.Boolean {
        return nowMs - queuedAtMs >= Constants.BOLUS_QUEUE_WAIT_MS;
    }

    //! Remove a bolus request that is still waiting in the queue (not dispatched).
    //! Returns true if one was removed: it can then never be delivered.
    function cancelQueuedBolus() as Lang.Boolean {
        var kept = [];
        var removed = false;
        for (var i = 0; i < requestQueue.size(); i++) {
            var req = requestQueue[i];
            if (req instanceof Lang.Dictionary && req.hasKey("bolus")) {
                removed = true;
            } else {
                kept.add(req);
            }
        }
        requestQueue = kept;
        return removed;
    }

    function onReceiveBolusEntryResponse(responseCode as Lang.Number, data as Lang.String?) as Void {
        System.println("Bolus entry response code: " + responseCode);
        if (callback != null) {
            callback.invoke("bolusEntrySent", {
                "success" => responseCode == 200,
                "responseCode" => responseCode
            });
        }
    }

    //! Send food entry to Loop via Nightscout notifications API
    function sendFoodEntry(foodData as Lang.Dictionary) as Void {
        // Nothing to send to: report it on the tile instead of a doomed request
        if (getNightscoutUrl().length() == 0 || getNightscoutToken().length() == 0 || !hasOtpSecret()) {
            onReceiveFoodEntryResponse(Constants.NOT_CONFIGURED_CODE, null);
            return;
        }
        var url = getNightscoutUrl() + "/api/v2/notifications/loop?token=" + getNightscoutToken();
        
        System.println("Sending food data: " + foodData.get("notes") + " with " + foodData.get("remoteCarbs") + " carbs");

        enqueue(
            url,
            foodData,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
            },
            self.method(:onReceiveFoodEntryResponse),
            true
        );
    }

    private function hasOtpSecret() as Lang.Boolean {
        var secret = Application.Properties.getValue("otp_secret");
        return secret != null && secret.toString().length() > 0;
    }

    //! Build URL with base Nightscout URL and token
    private function buildUrl(endpoint as Lang.String) as Lang.String {
        var baseUrl = getNightscoutUrl();
        var token = getNightscoutToken();
        
        return baseUrl + endpoint + "&token=" + token;
    }

    //! Get Nightscout URL from properties
    private function getNightscoutUrl() as Lang.String {
        var url = Application.Properties.getValue("nightscout_url");
        return url != null ? url.toString() : "";
    }

    //! Get Nightscout token from properties
    private function getNightscoutToken() as Lang.String {
        var token = Application.Properties.getValue("nightscout_token");
        return token != null ? token.toString() : "";
    }

    //! Handle glucose data response: extracts the current value from the most
    //! recent entry AND builds the ~4h trend history from the same response
    //! (a single request, to avoid overloading the BLE request queue).
    function onReceiveGlucoseData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        System.println("onReceiveGlucoseData responseCode=" + responseCode);
        if (responseCode != 200 || data == null) {
            // Surface the failure (stale indicator + faster retry by the view);
            // the last good value stays on screen and simply ages.
            appState.glucoseFetchFailed = true;
            if (callback != null) {
                callback.invoke("glucoseError", responseCode);
            }
            WatchUi.requestUpdate();
            return;
        }
        if (callback != null) {
            try {
                if (data instanceof Lang.Array && data.size() > 0) {
                    System.println("onReceiveGlucoseData entries received: " + data.size());
                    var entry = data[0];
                    if (entry instanceof Lang.Dictionary) {
                        var glucoseData = {
                            "bloodSugar" => entry.hasKey("sgv") ? entry.get("sgv") : 0,
                            "trendRate" => entry.hasKey("trendRate") ? entry.get("trendRate") : 0.0,
                            "direction" => entry.hasKey("direction") ? entry.get("direction") : "Flat"
                        };
                        // CGM reading time (Nightscout "date" is epoch ms) so the
                        // displayed age is the data's age, not the download's.
                        var readingMs = entry.hasKey("date") ? entry.get("date") : null;
                        if (readingMs instanceof Lang.Number || readingMs instanceof Lang.Long) {
                            glucoseData.put("readingTime", (readingMs / 1000).toNumber());
                        }
                        appState.glucoseFetchFailed = false;
                        
                        callback.invoke("glucose", glucoseData);
                    }

                    var values = [];
                    // Nightscout returns entries newest-first; reverse to chronological order
                    for (var i = data.size() - 1; i >= 0; i--) {
                        var historyEntry = data[i];
                        if (historyEntry instanceof Lang.Dictionary && historyEntry.hasKey("sgv")) {
                            var sgv = historyEntry.get("sgv");
                            if (sgv instanceof Lang.Number) {
                                values.add(sgv);
                            }
                        }
                    }
                    System.println("onReceiveGlucoseData history values built: " + values.size());
                    callback.invoke("glucoseHistory", values);
                } else {
                    System.println("onReceiveGlucoseData data is not a non-empty Array: " + data);
                }
            } catch (e) {
                System.println("Error parsing glucose data: " + e.getErrorMessage());
            }
        }
    }

    //! Handle food entry response
    function onReceiveFoodEntryResponse(responseCode as Lang.Number, data as Lang.String?) as Void {
        System.println("Food entry response code: " + responseCode);
        if (data != null) {
            System.println("Food entry response data: " + data.toString());
        }
        
        if (responseCode == 200) {
            System.println("Food data sent successfully!");
        } else {
            System.println("Error sending food data: " + responseCode);
        }
        
        if (callback != null) {
            callback.invoke("foodEntrySent", {
                "success" => responseCode == 200,
                "responseCode" => responseCode
            });
        }
    }

    //! Handle preset activation response
    function onReceivePresetActivationResponse(responseCode as Lang.Number, data as Lang.String?) as Void {
        System.println("Preset activation response code: " + responseCode);
        if (data != null) {
            System.println("Preset activation response data: " + data.toString());
        }
        
        if (responseCode == 200 || responseCode == 201) {
            System.println("Preset activated successfully!");
            // Optimistic update: show selected preset immediately without refetching.
            // Immediate refetch causes a race — Loop may process the command after we query,
            // returning no active override and overwriting the correct preset name with "Default".
            appState.updateActiveProfile(profileToActivate);
            appState.setProfileError(0);
        } else {
            System.println("Error activating preset: " + responseCode);
            appState.setProfileError(responseCode);
        }
    }
}