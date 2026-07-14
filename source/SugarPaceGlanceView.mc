import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Application;
import Toybox.System;

(:glance)
function getSugarPaceGlanceView() as [WatchUi.GlanceView] {
    return [new SugarPaceGlanceView()];
}

(:glance)
class SugarPaceGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        // No theme declared and no background drawn: the glance sits on the
        // stock Garmin card, which follows the display mode (light by day,
        // dark by night). Only the text color adapts: black on the day
        // background, white on the night one. Fallback is white because CIQ
        // glance backgrounds are dark on most devices.
        var night = true;
        var settings = System.getDeviceSettings();
        if (settings has :isNightModeEnabled) {
            night = settings.isNightModeEnabled;
        }
        dc.setColor(night ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);

        var justification = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Show the last known glucose (cached by the main app), fall back to a
        // prompt if we've never fetched one yet.
        var text = WatchUi.loadResource(Rez.Strings.open);
        var data = Application.Storage.getValue("last_glucose_data");
        var default_unit = Application.Properties.getValue("default_unit").toString();

        if (data instanceof Lang.Dictionary && data.hasKey("bloodSugar")) {
            var sgv = data.get("bloodSugar");
            if (sgv != null && sgv instanceof Lang.Number && sgv > 0) {
                text = sgv.toString() + " " + default_unit;
            }
        }
        dc.drawText(width / 2, height / 2, Graphics.FONT_MEDIUM, text, justification);
    }
}