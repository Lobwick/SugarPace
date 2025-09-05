import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;
import Toybox.Timer;
import Toybox.Time;
import Toybox.System;
import Toybox.Application;

class DiabetesFoodManagementView extends WatchUi.View {

    private var bloodSugarLevel as Lang.Number = 120;
    private var monkeyBitmap as BitmapResource?;
    private var updateTimer as Timer.Timer?;
    private var isLoading as Lang.Boolean = false;
    private var trendRate as Lang.Float = 0.0;
    private var direction as Lang.String = "Flat";
    private var lastUpdateTime as Time.Moment?;
    private var tempBasals as Lang.Array = [];
    private var activeProfile as Lang.String = "";

    function initialize() {
        View.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        // Load the monkey bitmap
        monkeyBitmap = WatchUi.loadResource(Rez.Drawables.monkey);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        fetchGlucoseData();
        // Update every 5 minutes
        updateTimer = new Timer.Timer();
        updateTimer.start(method(:fetchGlucoseData), 300000, true);
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Display blood sugar level in large text at top
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var bloodSugarText = bloodSugarLevel + " mg/dL";
        var font = Graphics.FONT_NUMBER_THAI_HOT;
        var textHeight = dc.getFontHeight(font);
        dc.drawText(width/2, 20, font, bloodSugarText, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Display trend information below glucose value
        var trendY = 20 + textHeight + 10;
        var smallFont = Graphics.FONT_XTINY;
        
        // Trend rate on the left
        var trendText = trendRate >= 0 ? "+" + trendRate.format("%.1f") + " mg/dL" : trendRate.format("%.1f") + " mg/dL";
        dc.drawText(width/4, trendY, smallFont, trendText, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Direction arrow in the middle
        var arrowText = getDirectionArrow(direction);
        dc.drawText(width/2, trendY, Graphics.FONT_SMALL, arrowText, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Time since last update on the right
        var timeText = getTimeSinceUpdate();
        dc.drawText(3 * width/4, trendY, smallFont, timeText, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Display monkey images in two columns with separator lines
        if (monkeyBitmap != null) {
            var imageWidth = monkeyBitmap.getWidth();
            var imageHeight = monkeyBitmap.getHeight();
            var startY = trendY + 30;
            var columnWidth = width / 2;
            var spacing = 20;
            var imagesPerColumn = (height - startY) / (imageHeight + spacing);
            
            var topMostHorizontalLine = height - 10;
            var drawnImages = 0;
            
            // Left column - start from bottom
            var leftX = columnWidth / 2 - imageWidth / 2;
            for (var i = 0; i < imagesPerColumn; i++) {
                var y = height - 10 - (i + 1) * (imageHeight + spacing);
                if (y >= startY) {
                    // Draw bitmap at original size
                    dc.drawBitmap(leftX, y, monkeyBitmap);
                    drawnImages++;
                }
            }
            
            // Right column - start from bottom
            var rightX = width - columnWidth / 2 - imageWidth / 2;
            for (var j = 0; j < imagesPerColumn; j++) {
                var y = height - 10 - (j + 1) * (imageHeight + spacing);
                if (y >= startY) {
                    // Draw bitmap at original size
                    dc.drawBitmap(rightX, y, monkeyBitmap);
                }
            }
            
            // Draw horizontal separator lines between rows - full width
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            for (var k = 0; k < drawnImages - 1; k++) {
                var imageBottomY = height - 10 - (k + 1) * (imageHeight + spacing);
                var nextImageTopY = height - 10 - (k + 2) * (imageHeight + spacing) + imageHeight;
                var lineY = (imageBottomY + nextImageTopY) / 2;
                
                if (lineY >= startY) {
                    dc.drawLine(0, lineY, width, lineY);
                    topMostHorizontalLine = lineY;
                }
            }
            
            // Draw line above top row of images
            if (drawnImages > 0) {
                var topImageY = height - 10 - drawnImages * (imageHeight + spacing);
                var lineAboveTop = topImageY - spacing / 2;
                if (lineAboveTop >= startY) {
                    dc.drawLine(0, lineAboveTop, width, lineAboveTop);
                    topMostHorizontalLine = lineAboveTop;
                }
            }
            
            // Draw vertical separator line between columns - from top horizontal line to bottom
            dc.drawLine(width / 2, topMostHorizontalLine, width / 2, height);
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        if (updateTimer != null) {
            updateTimer.stop();
            updateTimer = null;
        }
    }

    function fetchGlucoseData() as Void {
        if (isLoading) {
            return;
        }
        
        isLoading = true;
        
        // Get configuration from app properties
        var nightscoutUrl = Application.Properties.getValue("nightscout_url");
        var nightscoutToken = Application.Properties.getValue("nightscout_token");
        
        if (nightscoutUrl == null) {
            nightscoutUrl = "https://glucosefelix.fly.dev";
        }
        if (nightscoutToken == null) {
            nightscoutToken = "6NhkwPyxqR6Jpsur";
        }
        
        var url = nightscoutUrl + "/api/v1/entries.json?count=1&token=" + nightscoutToken;
        
        Communications.makeWebRequest(
            url,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                }
            },
            method(:onReceiveGlucoseData)
        );
    }

    function onReceiveGlucoseData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        isLoading = false;
        
        if (responseCode == 200 && data != null) {
            try {
                if (data instanceof Lang.Array && data.size() > 0) {
                    var entry = data[0];
                    if (entry instanceof Lang.Dictionary) {
                        if (entry.hasKey("sgv")) {
                            var newValue = entry.get("sgv");
                            if (newValue != null && newValue instanceof Lang.Number) {
                                bloodSugarLevel = newValue;
                            }
                        }
                        
                        if (entry.hasKey("trendRate")) {
                            var rate = entry.get("trendRate");
                            if (rate != null && rate instanceof Lang.Float) {
                                trendRate = rate;
                            }
                        }
                        
                        if (entry.hasKey("direction")) {
                            var dir = entry.get("direction");
                            if (dir != null && dir instanceof Lang.String) {
                                direction = dir;
                            }
                        }
                        
                        lastUpdateTime = Time.now();
                        WatchUi.requestUpdate();
                    }
                }
            } catch (e) {
                // Handle parsing errors silently
            }
        }
    }

    function getDirectionArrow(dir as Lang.String) as Lang.String {
        if (dir.equals("DoubleUp")) {
            return "↑↑";
        } else if (dir.equals("SingleUp")) {
            return "↑";
        } else if (dir.equals("FortyFiveUp")) {
            return "↗";
        } else if (dir.equals("Flat")) {
            return "→";
        } else if (dir.equals("FortyFiveDown")) {
            return "↘";
        } else if (dir.equals("SingleDown")) {
            return "↓";
        } else if (dir.equals("DoubleDown")) {
            return "↓↓";
        }
        return "→";
    }

    function getTimeSinceUpdate() as Lang.String {
        if (lastUpdateTime == null) {
            return "---";
        }
        
        var now = Time.now();
        var duration = now.subtract(lastUpdateTime);
        var seconds = duration.value();
        
        if (seconds < 60) {
            return seconds + "s";
        } else {
            var minutes = seconds / 60;
            return minutes + "m";
        }
    }

    function fetchTempBasalData() as Void {
        var nightscoutUrl = Application.Properties.getValue("nightscout_url");
        var nightscoutToken = Application.Properties.getValue("nightscout_token");
        
        if (nightscoutUrl == null) {
            nightscoutUrl = "https://glucosefelix.fly.dev";
        }
        if (nightscoutToken == null) {
            nightscoutToken = "6NhkwPyxqR6Jpsur";
        }
        
        // D'abord récupérer les profils et presets
        var profileUrl = nightscoutUrl + "/api/v1/profile.json?token=" + nightscoutToken;
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
        var overrideUrl = nightscoutUrl + "/api/v1/treatments.json?find[eventType]=Temporary%20Override&count=5&token=" + nightscoutToken;
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
                                activeProfile = defaultProfile.toString();
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
                                    tempBasals = profiles;
                                }
                            }
                        }
                    }
                }
            } catch (e) {
                // En cas d'erreur, utiliser des données de fallback
                tempBasals = [
                    {"name" => "sporterreur"},
                    {"name" => "stoperreur"}
                ];
            }
        } else {
            // Si pas de réponse, utiliser des données de fallback
            tempBasals = [
                {"name" => "sporterreur"},
                {"name" => "stop"}
            ];
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
                                            activeProfile = "sport";
                                            foundActiveOverride = true;
                                        } else if (reasonStr.find("stop") != null) {
                                            activeProfile = "stop";
                                            foundActiveOverride = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if (!foundActiveOverride) {
                        activeProfile = "Default";
                    }
                } else {
                    activeProfile = "Default";
                }
            } catch (e) {
                activeProfile = "Erreur";
            }
        } else {
            activeProfile = "Default";
        }
        
        // Forcer la mise à jour de l'affichage
        WatchUi.requestUpdate();
    }

    function getTempBasals() as Lang.Array {
        return tempBasals;
    }

    function getActiveProfile() as Lang.String {
        return activeProfile;
    }

}
