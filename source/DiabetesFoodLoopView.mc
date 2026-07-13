import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.System;
import Toybox.Application;


class DiabetesFoodLoopView extends WatchUi.View {

    // CGM readings arrive roughly every 5 minutes; used to map a time window
    // (minutes) to a number of history points to show.
    private const MIN_PER_POINT = 5;

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
        // Glucose is fetched by the app orchestrator at start; also load the
        // active Nightscout profile so its chip shows on this view immediately.
        var app = Application.getApp() as DiabetesFoodLoopApp;
        if (app != null) {
            var nightscoutService = app.getNightscoutService();
            if (nightscoutService != null) {
                nightscoutService.fetchTempBasalData();
            }
        }

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
        var cardTop = 6;
        var cardHeight = 224;
        var cardBottom = cardTop + cardHeight;

        var bloodSugar = appState.glucoseData.bloodSugarLevel;
        var default_unit = Application.Properties.getValue("default_unit").toString();
        var bloodSugarText = bloodSugar > 0 ? bloodSugar.toString() : "--";

        var innerX = margin;
        var valueY = cardTop;

        // Big current value, colored by glucose zone so the number itself
        // signals the state at a glance.
        var numberHeight = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
        var unitHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        var zoneColor = bloodSugar > 0 ? GlucoseData.getZoneColor(bloodSugar) : appState.foregroundColor;
        dc.setColor(zoneColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(innerX, valueY, Graphics.FONT_NUMBER_MEDIUM, bloodSugarText, Graphics.TEXT_JUSTIFY_LEFT);

        // Unit sits to the right of the number, aligned near its baseline
        var valueWidth = dc.getTextWidthInPixels(bloodSugarText, Graphics.FONT_NUMBER_MEDIUM);
        var unitX = innerX + valueWidth + 8;
        dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(unitX, valueY + numberHeight - unitHeight - 6, Graphics.FONT_XTINY, default_unit, Graphics.TEXT_JUSTIFY_LEFT);

        // Direction arrow right after the unit, in the zone color
        var unitWidth = dc.getTextWidthInPixels(default_unit, Graphics.FONT_XTINY);
        var leftContentRight = unitX + unitWidth;
        if (bloodSugar > 0) {
            var arrowHeight = dc.getFontHeight(Graphics.FONT_SMALL);
            var arrowX = unitX + unitWidth + 8;
            dc.setColor(zoneColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(arrowX, valueY + (numberHeight - arrowHeight) / 2, Graphics.FONT_SMALL, appState.glucoseData.getDirectionArrow(), Graphics.TEXT_JUSTIFY_LEFT);
            leftContentRight = arrowX + dc.getTextWidthInPixels(appState.glucoseData.getDirectionArrow(), Graphics.FONT_SMALL);
        }

        // Right-hand info column: freshness then range label, dimmed and
        // right-aligned, vertically centered against the big number.
        var rowGap = 4;
        var columnHeight = unitHeight + rowGap + unitHeight;
        var colTop = valueY + (numberHeight - columnHeight) / 2;
        if (colTop < valueY) { colTop = valueY; }

        var freshnessText = bloodSugar > 0 ? appState.glucoseData.getTimeSinceUpdate() + " ago" : "";
        var rightColWidth = dc.getTextWidthInPixels("LAST 4H", Graphics.FONT_XTINY);
        var freshnessWidth = dc.getTextWidthInPixels(freshnessText, Graphics.FONT_XTINY);
        if (freshnessWidth > rightColWidth) { rightColWidth = freshnessWidth; }
        var rightColLeft = width - margin - rightColWidth;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        if (bloodSugar > 0) {
            dc.drawText(width - margin, colTop, Graphics.FONT_XTINY, freshnessText, Graphics.TEXT_JUSTIFY_RIGHT);
        }
        // Range label reflects the selected window; sits last so it's closest
        // to the chart it labels.
        dc.drawText(width - margin, colTop + unitHeight + rowGap, Graphics.FONT_XTINY, "LAST " + chartWindowShortLabel(), Graphics.TEXT_JUSTIFY_RIGHT);

        // Active Nightscout profile, shown as a chip centered in the gap
        // between the number and the right-hand column.
        var activeProfile = appState.activeProfile;
        if (activeProfile != null && activeProfile.length() > 0) {
            var chipPad = 8;
            var chipH = unitHeight + 6;
            var chipTextW = dc.getTextWidthInPixels(activeProfile, Graphics.FONT_XTINY);
            var chipW = chipTextW + chipPad * 2;
            var gapLeft = leftContentRight + 8;
            var gapRight = rightColLeft - 8;
            // Only draw if there is enough room so it never collides
            if (gapRight - gapLeft >= chipW) {
                var chipX = (gapLeft + gapRight) / 2 - chipW / 2;
                var chipY = valueY + (numberHeight - chipH) / 2;
                dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(chipX, chipY, chipW, chipH, 6);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(chipX + chipW / 2, chipY + 2, Graphics.FONT_XTINY, activeProfile, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // Trend chart: occupies the rest of the card space, no tile/border around it
        var chartTop = valueY + numberHeight + 12;
        var chartBottom = cardBottom - 16;
        drawGlucoseChart(dc, innerX, chartTop, width - margin, chartBottom);

        // No data placeholder
        if (bloodSugar == 0) {
            dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, chartTop + 20, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.check_nightscout_config), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Record tap regions for hit-testing: header (value + info block) above,
        // chart below. cardBottom includes the chart's axis labels.
        appState.updateHeaderRegion(0, cardTop, width, chartTop);
        appState.updateChartRegion(innerX, chartTop, width - margin, cardBottom);

        return cardBottom;
    }

    //! Draw the last ~4h glucose trend as a bar chart between (x0,y0) and (x1,y1)
    private function drawGlucoseChart(dc as Dc, x0 as Lang.Number, y0 as Lang.Number, x1 as Lang.Number, y1 as Lang.Number) as Void {
        var history = appState.glucoseHistory;
        if (history == null || history.size() == 0) {
            return;
        }

        // Only show the most recent window (readings are ~5 min apart), so the
        // chart zooms in as the user cycles 4h -> 2h -> 1h -> 30m on tap.
        var fullSize = history.size();
        var pointsPerWindow = appState.chartWindowMinutes / MIN_PER_POINT;
        var startIdx = fullSize - pointsPerWindow;
        if (startIdx < 0) { startIdx = 0; }

        // Auto-scale the vertical range to the readings actually seen in the
        // visible window, so the bars fill the available height instead of being
        // squashed against a fixed 40-260 scale. A minimum span keeps a flat
        // "stable" line from being amplified into meaningless noise.
        // Non-nullable Number accumulators keep the type checker cheap.
        var dataMin = 0;
        var dataMax = 0;
        var seen = false;
        for (var j = startIdx; j < fullSize; j++) {
            var v = history[j];
            if (!(v instanceof Lang.Number)) {
                continue;
            }
            if (!seen) {
                dataMin = v;
                dataMax = v;
                seen = true;
            } else if (v < dataMin) {
                dataMin = v;
            } else if (v > dataMax) {
                dataMax = v;
            }
        }
        if (!seen) {
            return;
        }

        // Anchor the top of the scale just above the peak so the tallest bar
        // (the 4h maximum) reaches near the top of the chart and no vertical
        // space is wasted above the curve. Only the bottom is padded/extended.
        var span = dataMax - dataMin;
        var topHeadroom = (span * 0.12).toNumber();
        if (topHeadroom < 4) { topHeadroom = 4; }
        var vMax = dataMax + topHeadroom;
        var vMin = dataMin - (span * 0.25).toNumber();

        // Keep a minimum range so a flat "stable" line isn't amplified into
        // noise; extend downward only, leaving the peak pinned near the top.
        var minRange = 50;
        if (vMax - vMin < minRange) {
            vMin = vMax - minRange;
        }
        if (vMin < 0) { vMin = 0; }

        var chartHeight = y1 - y0;
        var chartWidth = x1 - x0;

        var barCount = fullSize - startIdx;
        var gap = barCount > 1 ? 3 : 0;

        // Lay the bars out in float space and round each edge, so cumulative
        // rounding never leaves a gap at the right edge: the last bar's right
        // edge lands exactly on x1.
        var slot = (chartWidth - gap * (barCount - 1)).toFloat() / barCount;
        if (slot < 1.0) {
            slot = 1.0;
        }
        var step = slot + gap;

        for (var i = 0; i < barCount; i++) {
            var value = history[startIdx + i];
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

            var barX = (x0 + i * step).toNumber();
            var barRight = (x0 + i * step + slot).toNumber();
            var w = barRight - barX;
            if (w < 1) {
                w = 1;
            }
            var barY = y1 - barHeight;

            // Neutral gray bars: only the trend badge carries the zone color
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, w, barHeight);
        }

        // Axis labels, dimmed to sit quietly under the bars; reflect the window
        var windowMinutes = appState.chartWindowMinutes;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, y1 + 4, Graphics.FONT_XTINY, agoLabel(windowMinutes), Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(x0 + chartWidth / 2, y1 + 4, Graphics.FONT_XTINY, agoLabel(windowMinutes / 2), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x1, y1 + 4, Graphics.FONT_XTINY, "Now", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    //! Short window label for the header, e.g. "4H", "30M"
    private function chartWindowShortLabel() as Lang.String {
        var m = appState.chartWindowMinutes;
        if (m >= 60) {
            return (m / 60) + "H";
        }
        return m + "M";
    }

    //! "N ago" axis label for a given number of minutes, e.g. "2h ago", "30m ago"
    private function agoLabel(minutes as Lang.Number) as Lang.String {
        if (minutes >= 60) {
            return (minutes / 60) + "h ago";
        }
        return minutes + "m ago";
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
                // Keep the active profile chip current alongside the glucose data
                nightscoutService.fetchTempBasalData();
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