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

    private var appState as AppState;

    // Serialized request queue: the device's BLE bridge is unreliable under
    // concurrent web requests (they can crash the app), so only ONE request is
    // ever in flight. Others wait here and are dispatched as each completes.
    private var requestQueue as Lang.Array = [];
    private var requestInFlight as Lang.Boolean = false;
    private var currentResponder as Method?;
    // Timestamp when the current in-flight request was dispatched.
    // If the app is suspended mid-request (e.g. during an activity), the callback
    // may never fire. After REQUEST_TIMEOUT_MS we reset and let the queue drain.
    private var requestStartTime as Lang.Number = 0;
    private static const REQUEST_TIMEOUT_MS as Lang.Number = 5000;

    function initialize(appState as AppState) {
        self.appState = appState;
    }

    //! Set callback for receiving data updates
    function setCallback(callback as Method) as Void {
        self.callback = callback;
    }

    //! Enqueue a web request; it runs when no other request is in flight.
    private function enqueue(url as Lang.String, params as Lang.Dictionary, options as Lang.Dictionary, responder as Method) as Void {
        requestQueue.add({ "url" => url, "params" => params, "options" => options, "responder" => responder });
        dispatchNext();
    }

    //! Dispatch the next queued request if the bridge is free.
    private function dispatchNext() as Void {
        if (requestInFlight) {
            if (System.getTimer() - requestStartTime < REQUEST_TIMEOUT_MS) {
                return;
            }
            requestInFlight = false;
            currentResponder = null;
        }
        if (requestQueue.size() == 0) {
            return;
        }
        var req = requestQueue[0];
        requestQueue = requestQueue.slice(1, null);
        requestInFlight = true;
        requestStartTime = System.getTimer();
        currentResponder = req.get("responder") as Method;
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
            self.method(:onReceivePresetActivationResponse)
        );
    }

    function deactivatePreset() as Void {
        var baseUrl = getNightscoutUrl();
        var token = getNightscoutToken();
        
        if (baseUrl.length() == 0 || token.length() == 0) {
            System.println("Nightscout URL or token not configured");
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
            self.method(:onReceivePresetActivationResponse)
        );
    }

    //! Fetch glucose data from Nightscout: a single request returns both the
    //! current value (most recent entry) and the ~4h history used for the
    //! trend chart, avoiding two concurrent BLE requests.
    function fetchGlucoseData() as Void {
        
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
            self.method(:onReceiveGlucoseData)
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
            method(:onReceiveTempBasalData)
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
            method(:onReceiveActiveOverride)
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

    

    //! Send food entry to Loop via Nightscout notifications API
    function sendFoodEntry(foodData as Lang.Dictionary) as Void {
        var url = getNightscoutUrl() + "/api/v2/notifications/loop?token=" + getNightscoutToken();
        
        System.println("Sending food data: " + foodData.get("notes") + " with " + foodData.get("remoteCarbs") + " carbs, OTP: " + foodData.get("otp"));

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
            self.method(:onReceiveFoodEntryResponse)
        );
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
        if (responseCode == 200 && data != null && callback != null) {
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
        } else {
            System.println("Error activating preset: " + responseCode);
        }
    }
}