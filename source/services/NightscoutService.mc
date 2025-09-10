import Toybox.Communications;
import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;

//! Service responsible for all Nightscout API communications
class NightscoutService {

    private var callback as Method?;
    private var profileToActivate as Lang.String = "";

    private var appState as AppState;

    function initialize(appState as AppState) {
        self.appState = appState;
    }

    //! Set callback for receiving data updates
    function setCallback(callback as Method) as Void {
        self.callback = callback;
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
        Communications.makeWebRequest(
            treatmentUrl,
            treatmentData,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                }
            },
            self.method(:onReceivePresetActivationResponse)
        );
    }

    //! Format current timestamp to ISO format for treatments
    private function formatCurrentTimestamp() as Lang.String {
        var now = Time.now();
        var timeInfo = Time.Gregorian.info(now, Time.FORMAT_SHORT);
        
        return Lang.format("$1$-$2$-$3$T$4$:$5$:$6$.000Z", [
            timeInfo.year.format("%04d"),
            timeInfo.month.format("%02d"),
            timeInfo.day.format("%02d"),
            timeInfo.hour.format("%02d"),
            timeInfo.min.format("%02d"),
            timeInfo.sec.format("%02d")
        ]);
    }

    function desactivePreset() as Void {
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
        Communications.makeWebRequest(
            treatmentUrl,
            treatmentData,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                }
            },
            self.method(:onReceivePresetActivationResponse)
        );
    }

    //! Fetch glucose data from Nightscout
    function fetchGlucoseData() as Void {
        
        var url = buildUrl("/api/v1/entries.json?count=1");
        
        Communications.makeWebRequest(
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

    //! Fetch food data from Nightscout
    function fetchFoodData() as Void {

        var url = getNightscoutUrl() + "/api/v1/food.json";
        Communications.makeWebRequest(
            url,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                }
            },
            self.method(:onReceiveFoodData)
        );
    }

    //! Fetch temp basal data and active profile
    function fetchTempBasalData() as Void {
        var baseUrl = getNightscoutUrl();
        var token = getNightscoutToken();



        var profileUrl = baseUrl + "/api/v1/profile.json?token=" + token;
        Communications.makeWebRequest(
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

        // Ensuite récupérer les overrides récents pour déterminer l'actif
        var overrideUrl = baseUrl + "/api/v1/treatments.json?find[eventType]=Temporary%20Override&count=5&token=" + token;
        Communications.makeWebRequest(
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

     function onReceiveTempBasalData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200 && data != null) {
            try {
                if (data instanceof Lang.Array && data.size() > 0) {
                    // Récupérer le premier élément
                    var firstProfile = data[0];
                    if (firstProfile instanceof Lang.Dictionary) {
                        // Récupérer le profil actif
                        if (firstProfile.hasKey("defaultProfile")) {
                            var defaultProfile = firstProfile.get("defaultProfile");
                            if (defaultProfile != null) {
                                appState.activeProfile = defaultProfile.toString();
                            }
                        }
                        
                        // Récupérer les overrides
                        if (firstProfile.hasKey("loopSettings")) {
                            var loopSettings = firstProfile.get("loopSettings");
                            if (loopSettings instanceof Lang.Dictionary && loopSettings.hasKey("overridePresets")) {
                                var overridePresets = loopSettings.get("overridePresets");
                                if (overridePresets instanceof Lang.Array) {
                                    var profiles = [];
                                    for (var i = 0; i < overridePresets.size(); i++) {
                                        var presetData = overridePresets[i];
                                        if (presetData instanceof Lang.Dictionary && presetData.hasKey("name")) {
                                            var presetName = presetData.get("name");
                                            var entry = {
                                                "name" => presetName,
                                                "data" => presetData
                                            };
                                            profiles.add(entry);
                                        }
                                    }
                                    appState.tempBasals = profiles;
                                }
                            }
                        }
                    }
                }
            } catch (e) {
                // En cas d'erreur, utiliser des données de fallback
                appState.tempBasals = [
                    {"name" => "sporterreur"},
                    {"name" => "stoperreur"}
                ];
            }
        } else {
            // Si pas de réponse, utiliser des données de fallback
            appState.tempBasals = [
                {"name" => "sporterreur"},
                {"name" => "stop"}
            ];
        }
        
        // Notify callback with temp basals data
        if (callback != null) {
            callback.invoke("tempBasals", {
                "activeProfile" => appState.activeProfile,
                "profiles" => appState.tempBasals
            });
        }
        
        // Forcer la mise à jour de l'affichage
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
                                }
                            } else if (!override.hasKey("duration") || override.get("duration") == null) {
                                isActive = true;
                            }
                            
                            if (isActive) {
                                if (override.hasKey("reason")) {
                                    var reason = override.get("reason");
                                    if (reason != null) {
                                        var reasonStr = reason.toString();
                                        if (reasonStr.find("sport") != null) {
                                            appState.updateActiveProfile("sport");
                                            foundActiveOverride = true;
                                        } else if (reasonStr.find("stop") != null) {
                                            appState.updateActiveProfile("stop");
                                            //TODO
                                            foundActiveOverride = true;
                                        }
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
        var url = getNightscoutUrl() + "/api/v2/notifications/loop?token=garmin-5709111d29db02b8";
        
        System.println("Sending food data: " + foodData.get("notes") + " with " + foodData.get("remoteCarbs") + " carbs, OTP: " + foodData.get("otp"));
        
        Communications.makeWebRequest(
            url,
            foodData,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                }
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

    //! Handle glucose data response
    function onReceiveGlucoseData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200 && data != null && callback != null) {
            try {
                if (data instanceof Lang.Array && data.size() > 0) {
                    var entry = data[0];
                    if (entry instanceof Lang.Dictionary) {
                        var glucoseData = {
                            "bloodSugar" => entry.hasKey("sgv") ? entry.get("sgv") : 0,
                            "trendRate" => entry.hasKey("trendRate") ? entry.get("trendRate") : 0.0,
                            "direction" => entry.hasKey("direction") ? entry.get("direction") : "Flat"
                        };
                        
                        callback.invoke("glucose", glucoseData);
                    }
                }
            } catch (e) {
                System.println("Error parsing glucose data: " + e.getErrorMessage());
            }
        }
    }

    //! Handle food data response  
    function onReceiveFoodData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200 && data != null && callback != null) {
            try {
                if (data instanceof Lang.Array) {
                    System.println("=== FOODS DATA ===");
                    System.println("Nombre d'aliments: " + data.size());
                    
                    callback.invoke("foods", data);
                }
            } catch (e) {
                System.println("Erreur parsing foods: " + e.getErrorMessage());
            }
        } else {
            System.println("Erreur récupération foods: " + responseCode);
        }
    }

    //! Handle available profiles response (from treatments/overrides)
    function onReceiveAvailableProfiles(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        System.println("Received available profiles response code: " + responseCode);
        if (responseCode == 200 && data != null && callback != null) {
            try {
                var activeProfile = Constants.DEFAULT_OVERRIDE_PROFIL;

                if (data instanceof Lang.Array) {
                    // Find the first active override (without duration or with durationType = "indefinite")
                    for (var i = 0; i < data.size(); i++) {
                        var override = data[i];
                        if (override instanceof Lang.Dictionary) {
                            
                            if (override.hasKey("reason")) {
                                var reason = override.get("reason");
                                if (reason != null) {
                                    var reasonStr = reason.toString();
                                    if (reasonStr.find("sport") != null) {
                                        activeProfile = "sport";
                                        break;
                                    } else if (reasonStr.find("stop") != null) {
                                        activeProfile = "stop";
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
                
                callback.invoke("activeProfile", activeProfile);
                
            } catch (e) {
                callback.invoke("activeProfile", "Erreur");
            }
        }
    }

    //! Handle active profile response (from profile endpoint)
    function onReceiveActiveProfile(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200 && data != null && callback != null) {
            try {
                var activeProfile = Constants.DEFAULT_OVERRIDE_PROFIL;
                
                if (data instanceof Lang.Array) {
                    // Find the first active override (without duration or with durationType = "indefinite")
                    for (var i = 0; i < data.size(); i++) {
                        var override = data[i];
                        if (override instanceof Lang.Dictionary) {
                            var isActive = false;
                            if (override.hasKey("durationType")) {
                                var durationType = override.get("durationType");
                                if (durationType != null && durationType.toString().equals("indefinite")) {
                                    isActive = true;
                                }
                            } else if (!override.hasKey("duration") || override.get("duration") == null) {
                                isActive = true;
                            }
                            
                            if (isActive && override.hasKey("reason")) {
                                var reason = override.get("reason");
                                if (reason != null) {
                                    var reasonStr = reason.toString();
                                    if (reasonStr.find("sport") != null) {
                                        activeProfile = "sport";
                                        break;
                                    } else if (reasonStr.find("stop") != null) {
                                        activeProfile = "stop";
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
                
                callback.invoke("activeProfile", activeProfile);
                
            } catch (e) {
                callback.invoke("activeProfile", "Erreur");
            }
        }
    }

    //! Handle food entry response
    function onReceiveFoodEntryResponse(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
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
    function onReceivePresetActivationResponse(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        System.println("Preset activation response code: " + responseCode);
        if (data != null) {
            System.println("Preset activation response data: " + data.toString());
        }
        
        if (responseCode == 200 || responseCode == 201) {
            System.println("Preset activated successfully!");
            appState.updateActiveProfile( profileToActivate);
            //fetchTempBasalData();
        } else {
            System.println("Error activating preset: " + responseCode);
        }
    }
}