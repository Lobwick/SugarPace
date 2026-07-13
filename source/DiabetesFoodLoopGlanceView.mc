import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Application;

(:glance)
function getDiabetesFoodLoopGlanceView() as [WatchUi.GlanceView] {
    return [new DiabetesFoodLoopGlanceView()];
}

(:glance)
class DiabetesFoodLoopGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        var justification = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Show the last known glucose (cached by the main app), fall back to a
        // prompt if we've never fetched one yet.
        var text = "Ouvrir";
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