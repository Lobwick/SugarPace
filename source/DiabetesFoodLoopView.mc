import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.System;
import Toybox.Application;


class DiabetesFoodLoopView extends WatchUi.View {

    private var updateTimer as Timer.Timer?;
    private var appState as AppState;

    function initialize(appState as AppState) {
        WatchUi.View.initialize();
        self.appState = appState;
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
    }

    // Called when this View is brought to the foreground
    function onShow() as Void {
        // Data fetching is handled by the app orchestrator
        
        // Update every 5 minutes
        updateTimer = new Timer.Timer();
        updateTimer.start(method(:requestDataUpdate), 300000, true);
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Dark theme is always used, to match the app's design
        appState.backgroundColor = Graphics.COLOR_BLACK;
        appState.foregroundColor = Graphics.COLOR_WHITE;
        dc.setColor(appState.backgroundColor, appState.backgroundColor);
        dc.clear();
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        var cardBottom = drawGlucoseCard(dc, width);
        drawFoodGrid(dc, width, height, cardBottom + 16);
    }

    // Called when this View is removed from the screen
    function onHide() as Void {
        if (updateTimer != null) {
            updateTimer.stop();
            updateTimer = null;
        }
    }

    //! Draw the glucose card: current value, freshness, trend badge and the
    //! last ~4h trend chart. Returns the Y coordinate where the card ends.
    private function drawGlucoseCard(dc as Dc, width as Lang.Number) as Lang.Number {
        var margin = 8;
        var cardTop = 8;
        var cardHeight = 260;
        var cardBottom = cardTop + cardHeight;

        var bloodSugar = appState.glucoseData.bloodSugarLevel;
        var default_unit = Application.Properties.getValue("default_unit").toString();
        var bloodSugarText = bloodSugar > 0 ? bloodSugar.toString() : "--";

        var innerX = margin;
        var valueY = cardTop;

        // Big current value + unit (neutral color: only the trend badge carries the zone color)
        dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(innerX, valueY, Graphics.FONT_NUMBER_MEDIUM, bloodSugarText, Graphics.TEXT_JUSTIFY_LEFT);

        var valueWidth = dc.getTextWidthInPixels(bloodSugarText, Graphics.FONT_NUMBER_MEDIUM);
        dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(innerX + valueWidth + 8, valueY + 26, Graphics.FONT_XTINY, default_unit, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(width - margin, valueY + 10, Graphics.FONT_XTINY, "LAST 4H", Graphics.TEXT_JUSTIFY_RIGHT);

        if (bloodSugar > 0) {
            var badgeY = valueY + 46;

            // Freshness: how long ago this reading was fetched
            var freshnessText = appState.glucoseData.getTimeSinceUpdate() + " ago";
            dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(innerX, badgeY, Graphics.FONT_XTINY, freshnessText, Graphics.TEXT_JUSTIFY_LEFT);

            // Trend badge (STABLE / RISING / FALLING), colored by glucose zone
            var trendLabel = appState.glucoseData.getTrendLabel();
            var badgeColor = GlucoseData.getZoneColor(bloodSugar);
            var badgeTextWidth = dc.getTextWidthInPixels(trendLabel, Graphics.FONT_XTINY);
            var badgePaddingX = 8;
            var badgeWidth = badgeTextWidth + badgePaddingX * 2;
            var badgeHeight = 20;
            var arrowWidth = 24;
            var badgeRight = width - margin - arrowWidth;
            var badgeLeft = badgeRight - badgeWidth;

            dc.setColor(badgeColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(badgeLeft, badgeY - 2, badgeWidth, badgeHeight, 6);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(badgeLeft + badgeWidth / 2, badgeY, Graphics.FONT_XTINY, trendLabel, Graphics.TEXT_JUSTIFY_CENTER);

            // Direction arrow to the right of the badge
            dc.setColor(badgeColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width - margin, badgeY, Graphics.FONT_SMALL, appState.glucoseData.getDirectionArrow(), Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Trend chart: occupies the rest of the card space, no tile/border around it
        var chartTop = valueY + 74;
        var chartBottom = cardBottom - 16;
        drawGlucoseChart(dc, innerX, chartTop, width - margin, chartBottom);

        // No data placeholder
        if (bloodSugar == 0) {
            dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, chartTop + 20, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.check_nightscout_config), Graphics.TEXT_JUSTIFY_CENTER);
        }

        return cardBottom;
    }

    //! Draw the last ~4h glucose trend as a bar chart between (x0,y0) and (x1,y1)
    private function drawGlucoseChart(dc as Dc, x0 as Lang.Number, y0 as Lang.Number, x1 as Lang.Number, y1 as Lang.Number) as Void {
        var history = appState.glucoseHistory;
        if (history == null || history.size() == 0) {
            return;
        }

        // Fixed display range so the bar heights are meaningful across readings
        var vMin = 40;
        var vMax = 260;
        var chartHeight = y1 - y0;
        var chartWidth = x1 - x0;

        var barCount = history.size();
        var gap = 3;
        var barWidth = (chartWidth - gap * (barCount - 1)) / barCount;
        if (barWidth < 2) {
            barWidth = 2;
        }

        for (var i = 0; i < barCount; i++) {
            var value = history[i];
            if (!(value instanceof Lang.Number)) {
                continue;
            }
            var clamped = value;
            if (clamped < vMin) { clamped = vMin; }
            if (clamped > vMax) { clamped = vMax; }
            var ratio = (clamped - vMin).toFloat() / (vMax - vMin);
            var barHeight = (ratio * chartHeight).toNumber();
            if (barHeight < 2) {
                barHeight = 2;
            }

            var barX = x0 + i * (barWidth + gap);
            var barY = y1 - barHeight;

            // Neutral gray bars: only the trend badge carries the zone color
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, barWidth, barHeight);
        }

        // Axis labels
        dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, y1 + 4, Graphics.FONT_XTINY, "4h ago", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(x0 + chartWidth / 2, y1 + 4, Graphics.FONT_XTINY, "2h ago", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x1, y1 + 4, Graphics.FONT_XTINY, "Now", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    //! Draw the scrollable 2-column grid of food products (icon + name + carbs)
    private function drawFoodGrid(dc as Dc, width as Lang.Number, height as Lang.Number, startY as Lang.Number) as Void {
        dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);

        if (appState.foodItems.size() == 0) {
            dc.drawText(width / 2, startY + 20, Graphics.FONT_SMALL, WatchUi.loadResource(Rez.Strings.loading_foods), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width / 2, startY + 50, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.check_nightscout_config), Graphics.TEXT_JUSTIFY_CENTER);
            appState.updateFoodGridCoordinates([]);
            return;
        }

        var margin = 12;
        var gap = 10;
        var columns = 2;
        var cellWidth = (width - margin * 2 - gap) / columns;
        var cellHeight = 118;

        var coordinates = [];

        for (var i = 0; i < appState.foodItems.size(); i++) {
            var foodItem = appState.foodItems[i];
            if (!(foodItem instanceof FoodItem)) {
                continue;
            }

            var col = i % columns;
            var row = i / columns;
            var x0 = margin + col * (cellWidth + gap);
            var y0 = startY + row * (cellHeight + gap);

            // Stop drawing once we run past the bottom of the screen; the
            // remaining items are reachable by scrolling in a future iteration.
            if (y0 + cellHeight > height - 4) {
                break;
            }

            dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x0, y0, cellWidth, cellHeight);

            var bitmap = resolveBitmap(foodItem);
            if (bitmap != null) {
                var bx = x0 + (cellWidth - bitmap.getWidth()) / 2;
                var by = y0 + 8;
                dc.drawBitmap(bx, by, bitmap);
            }

            dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 + cellWidth / 2, y0 + cellHeight - 24, Graphics.FONT_XTINY, foodItem.name, Graphics.TEXT_JUSTIFY_CENTER);

            coordinates.add({
                "x0" => x0,
                "y0" => y0,
                "x1" => x0 + cellWidth,
                "y1" => y0 + cellHeight,
                "index" => i
            });
        }

        appState.updateFoodGridCoordinates(coordinates);
    }

    //! Resolve the bitmap to display: brand-specific first, then category default.
    private function resolveBitmap(foodItem as FoodItem) as BitmapResource? {
        // Try brand-specific drawable by picture id
        if (foodItem.picture != null) {
            try {
                var id = Rez.Drawables[foodItem.picture];
                if (id != null) {
                    return WatchUi.loadResource(id) as BitmapResource;
                }
            } catch (ex) { }
        }

        // Fall back to category default
        var sub = foodItem.subcategory.toUpper();
        var defaultId = null;
        if (sub.equals("GEL")) {
            defaultId = Rez.Drawables.default_gel;
        } else if (sub.equals("JELLIES")) {
            defaultId = Rez.Drawables.default_jellies;
        } else if (sub.equals("BAR")) {
            defaultId = Rez.Drawables.default_bar;
        } else if (sub.equals("DRINKS")) {
            defaultId = Rez.Drawables.default_drinks;
        }

        if (defaultId != null) {
            try {
                return WatchUi.loadResource(defaultId) as BitmapResource;
            } catch (ex) { }
        }

        return null;
    }
    //! Request data update from the app orchestrator
    function requestDataUpdate() as Void {
        // Refresh current glucose value and trend history so the chart stays up to date
        var app = Application.getApp() as DiabetesFoodLoopApp;
        if (app != null) {
            var nightscoutService = app.getNightscoutService();
            if (nightscoutService != null) {
                nightscoutService.fetchGlucoseData();
            }
        }
    }

    // Legacy methods for compatibility during migration
    function getFoodsList() as Lang.Array {
        return appState != null ? getApp().getFoodsList() : [];
    }

    function setSelectedFoodIndex(index as Lang.Number) as Void {
        if (appState != null) {
            appState.setSelectedFoodIndex(index);
        }
    }

    function getSelectedFoodIndex() as Lang.Number {
        return appState != null ? appState.selectedFoodIndex : 0;
    }
}