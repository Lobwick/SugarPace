import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

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
        
        // Simple "Open" text centered in the glance
        dc.drawText(width / 2, height / 2, Graphics.FONT_MEDIUM, "Open", justification);
    }
}