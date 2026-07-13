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
        // Refresh on the CGM cadence
        updateTimer = new Timer.Timer();
        updateTimer.start(method(:requestDataUpdate), Layout.REFRESH_INTERVAL_MS, true);

        // Load the active Nightscout profile. Safe to call alongside the startup
        // glucose fetch: NightscoutService serializes all requests, so nothing
        // hits the BLE bridge concurrently.
        fetchProfile();
    }

    //! Fetch the active Nightscout profile and available presets
    function fetchProfile() as Void {
        var app = Application.getApp() as DiabetesFoodLoopApp;
        if (app != null) {
            var nightscoutService = app.getNightscoutService();
            if (nightscoutService != null) {
                nightscoutService.fetchTempBasalData();
            }
        }
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
        var scroll = appState.scrollOffset;

        // Two scroll modes:
        //  - Tall screens (1040/1050/850/550): header + chart stay pinned; only
        //    the food grid scrolls inside its clipped viewport below.
        //  - Short screens (540/840): too little room for that, so the WHOLE page
        //    scrolls (chart included) and the grid can use the full height.
        var wholePage = height < Layout.COMPACT_HEIGHT_THRESHOLD;

        var cardTop = wholePage ? Layout.CARD_TOP - scroll : Layout.CARD_TOP;
        var cardBottom = drawGlucoseCard(dc, width, height, cardTop);
        var gridTop = cardBottom + Layout.CARD_GRID_GAP;

        var maxScroll;
        if (wholePage) {
            // Grid drawn at its shifted position; nothing pinned, no clip, no
            // extra internal scroll. Cells stay full size (no viewport cap).
            var gridContentH = drawFoodGrid(dc, width, gridTop, height, 0, 0, 0);
            var contentBottom = gridTop + gridContentH + scroll; // absolute
            maxScroll = contentBottom - height + Layout.CARD_BOTTOM_PAD;
        } else {
            // Grid scrolls within a fixed, clipped viewport below the pinned card.
            var viewportHeight = height - gridTop;
            var gridContentH = drawFoodGrid(dc, width, gridTop, height, scroll, gridTop, viewportHeight);
            maxScroll = gridContentH - viewportHeight;
        }

        if (maxScroll < 0) { maxScroll = 0; }
        appState.maxScroll = maxScroll;
        if (appState.scrollOffset > maxScroll) {
            appState.scrollOffset = maxScroll;
        }
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
    private function drawGlucoseCard(dc as Dc, width as Lang.Number, height as Lang.Number, cardTop as Lang.Number) as Lang.Number {
        var margin = Layout.CARD_MARGIN;

        var bloodSugar = appState.glucoseData.bloodSugarLevel;
        var default_unit = Application.Properties.getValue("default_unit").toString();
        var bloodSugarText = bloodSugar > 0 ? bloodSugar.toString() : "--";

        var innerX = margin;
        var valueY = cardTop;

        // Short screens (Edge 540/840) get a smaller number + shorter chart so
        // the food grid isn't squeezed to a single cramped row.
        var compact = height < Layout.COMPACT_HEIGHT_THRESHOLD;
        var numberFont = compact ? Graphics.FONT_NUMBER_MILD : Graphics.FONT_NUMBER_MEDIUM;
        var chartPct = compact ? Layout.CHART_HEIGHT_PCT_COMPACT : Layout.CHART_HEIGHT_PCT;

        // Big current value, colored by glucose zone so the number itself
        // signals the state at a glance.
        var numberHeight = dc.getFontHeight(numberFont);
        var unitHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        var zoneColor = bloodSugar > 0 ? GlucoseData.getZoneColor(bloodSugar) : appState.foregroundColor;
        dc.setColor(zoneColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(innerX, valueY, numberFont, bloodSugarText, Graphics.TEXT_JUSTIFY_LEFT);

        // Unit sits to the right of the number, aligned near its baseline
        var valueWidth = dc.getTextWidthInPixels(bloodSugarText, numberFont);
        var unitX = innerX + valueWidth + Layout.VALUE_UNIT_GAP;
        dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(unitX, valueY + numberHeight - unitHeight - Layout.UNIT_BASELINE_LIFT, Graphics.FONT_XTINY, default_unit, Graphics.TEXT_JUSTIFY_LEFT);

        // Direction arrow right after the unit, in the zone color
        var unitWidth = dc.getTextWidthInPixels(default_unit, Graphics.FONT_XTINY);
        var leftContentRight = unitX + unitWidth;
        if (bloodSugar > 0) {
            var arrowHeight = dc.getFontHeight(Graphics.FONT_SMALL);
            var arrowX = unitX + unitWidth + Layout.VALUE_UNIT_GAP;
            dc.setColor(zoneColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(arrowX, valueY + (numberHeight - arrowHeight) / 2, Graphics.FONT_SMALL, appState.glucoseData.getDirectionArrow(), Graphics.TEXT_JUSTIFY_LEFT);
            leftContentRight = arrowX + dc.getTextWidthInPixels(appState.glucoseData.getDirectionArrow(), Graphics.FONT_SMALL);
        }

        // Right-hand info column: just the freshness, dimmed and right-aligned,
        // vertically centered against the big number. (The window/range is
        // already labelled under the chart, so no "LAST 4H" here.)
        var colTop = valueY + (numberHeight - unitHeight) / 2;
        if (colTop < valueY) { colTop = valueY; }

        var freshnessText = bloodSugar > 0 ? appState.glucoseData.getTimeSinceUpdate() + " ago" : "";
        var rightColWidth = dc.getTextWidthInPixels(freshnessText, Graphics.FONT_XTINY);
        var rightColLeft = width - margin - rightColWidth;

        if (bloodSugar > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width - margin, colTop, Graphics.FONT_XTINY, freshnessText, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Active Nightscout profile: a small accent dot + name, flat and
        // centered in the gap between the number and the right-hand column.
        var activeProfile = appState.activeProfile;
        if (activeProfile != null && activeProfile.length() > 0) {
            var dotRadius = Layout.PROFILE_DOT_RADIUS;
            var dotGap = Layout.PROFILE_DOT_GAP;
            var profileTextW = dc.getTextWidthInPixels(activeProfile, Graphics.FONT_XTINY);
            var blockW = dotRadius * 2 + dotGap + profileTextW;
            var gapLeft = leftContentRight + Layout.PROFILE_SIDE_GAP;
            var gapRight = rightColLeft - Layout.PROFILE_SIDE_GAP;
            // Only draw if there is enough room so it never collides
            if (gapRight - gapLeft >= blockW) {
                var blockLeft = (gapLeft + gapRight) / 2 - blockW / 2;
                var centerY = valueY + numberHeight / 2;
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(blockLeft + dotRadius, centerY, dotRadius);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(blockLeft + dotRadius * 2 + dotGap, centerY - unitHeight / 2, Graphics.FONT_XTINY, activeProfile, Graphics.TEXT_JUSTIFY_LEFT);
            }
        }

        // Trend chart below the header. Its height is a fraction of the screen
        // so it scales; the card then sizes itself to fit number + chart + axis
        // labels (no fixed card height that would overflow small screens).
        var chartTop = valueY + numberHeight + Layout.HEADER_CHART_GAP;
        var chartHeight = (height * chartPct).toNumber();
        var chartBottom = chartTop + chartHeight;
        drawGlucoseChart(dc, innerX, chartTop, width - margin, chartBottom);

        var cardBottom = chartBottom + Layout.CHART_AXIS_GAP + unitHeight + Layout.CARD_BOTTOM_PAD;

        // No data placeholder
        if (bloodSugar == 0) {
            dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, chartTop + Layout.NODATA_TEXT_OFFSET, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.check_nightscout_config), Graphics.TEXT_JUSTIFY_CENTER);
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
        var pointsPerWindow = appState.chartWindowMinutes / Layout.MIN_PER_POINT;
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
        var topHeadroom = (span * Layout.CHART_TOP_HEADROOM_PCT).toNumber();
        if (topHeadroom < Layout.CHART_BAR_MIN_H) { topHeadroom = Layout.CHART_BAR_MIN_H; }
        var vMax = dataMax + topHeadroom;
        var vMin = dataMin - (span * Layout.CHART_BOTTOM_PAD_PCT).toNumber();

        // Keep a minimum range so a flat "stable" line isn't amplified into
        // noise; extend downward only, leaving the peak pinned near the top.
        if (vMax - vMin < Layout.CHART_MIN_RANGE) {
            vMin = vMax - Layout.CHART_MIN_RANGE;
        }
        if (vMin < 0) { vMin = 0; }

        var chartHeight = y1 - y0;
        var chartWidth = x1 - x0;

        var barCount = fullSize - startIdx;
        var gap = barCount > 1 ? Layout.CHART_BAR_GAP : 0;

        // Lay the bars out in float space and round each edge, so cumulative
        // rounding never leaves a gap at the right edge: the last bar's right
        // edge lands exactly on x1.
        var slot = (chartWidth - gap * (barCount - 1)).toFloat() / barCount;
        if (slot < 1.0) {
            slot = 1.0;
        }
        var step = slot + gap;

        // Optional: color each bar by its glucose zone instead of neutral gray
        var colorByZone = false;
        var pref = Application.Properties.getValue("chart_color_by_zone");
        if (pref instanceof Lang.Boolean) {
            colorByZone = pref;
        }

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
            if (barHeight < Layout.CHART_BAR_MIN_H) {
                barHeight = Layout.CHART_BAR_MIN_H;
            }

            var barX = (x0 + i * step).toNumber();
            var barRight = (x0 + i * step + slot).toNumber();
            var w = barRight - barX;
            if (w < 1) {
                w = 1;
            }
            var barY = y1 - barHeight;

            // Gray by default; colored by glucose zone when the preference is on
            var barColor = colorByZone ? GlucoseData.getZoneColor(value) : Graphics.COLOR_LT_GRAY;
            dc.setColor(barColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, w, barHeight);
        }

        // Axis labels, dimmed to sit quietly under the bars; reflect the window
        var windowMinutes = appState.chartWindowMinutes;
        var labelY = y1 + Layout.CHART_AXIS_GAP;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, labelY, Graphics.FONT_XTINY, agoLabel(windowMinutes), Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(x0 + chartWidth / 2, labelY, Graphics.FONT_XTINY, agoLabel(windowMinutes / 2), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x1, labelY, Graphics.FONT_XTINY, "Now", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    //! "N ago" axis label for a given number of minutes, e.g. "2h ago", "30m ago"
    private function agoLabel(minutes as Lang.Number) as Lang.String {
        if (minutes >= 60) {
            return (minutes / 60) + "h ago";
        }
        return minutes + "m ago";
    }

    //! Draw the 2-column food grid. `scroll` hides that many px of content above
    //! `gridTop`. `clipTop` is the top of the clip/tap region (== gridTop when a
    //! fixed header is pinned above, 0 when the whole page scrolls). `capViewport`
    //! caps the cell height so one full tile fits a fixed viewport (0 = no cap,
    //! used in whole-page mode). Returns the total pixel height of the content.
    private function drawFoodGrid(dc as Dc, width as Lang.Number, gridTop as Lang.Number, height as Lang.Number, scroll as Lang.Number, clipTop as Lang.Number, capViewport as Lang.Number) as Lang.Number {
        dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);

        if (appState.foodItems.size() == 0) {
            dc.drawText(width / 2, gridTop + Layout.GRID_EMPTY_TITLE_OFFSET, Graphics.FONT_SMALL, WatchUi.loadResource(Rez.Strings.loading_foods), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width / 2, gridTop + Layout.GRID_EMPTY_SUBTITLE_OFFSET, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.check_nightscout_config), Graphics.TEXT_JUSTIFY_CENTER);
            appState.updateFoodGridCoordinates([]);
            return 0;
        }

        var margin = Layout.GRID_MARGIN;
        var gap = Layout.GRID_GAP;
        var columns = Layout.GRID_COLUMNS;
        var cellWidth = (width - margin * 2 - gap) / columns;
        var nameBand = Layout.GRID_NAME_BAND; // space reserved at the bottom for the product name

        // Cell height: preferred size, but capped so one full tile fits a fixed
        // viewport (pinned-header mode), never below the image+name floor.
        var cellHeight = Layout.GRID_CELL_HEIGHT;
        if (capViewport > 0 && cellHeight > capViewport - gap) {
            cellHeight = capViewport - gap;
        }
        if (cellHeight < Layout.GRID_CELL_MIN_HEIGHT) {
            cellHeight = Layout.GRID_CELL_MIN_HEIGHT;
        }

        var coordinates = [];
        var rowCount = 0;

        // Clip to the grid region so scrolled rows don't paint over a pinned
        // header (in whole-page mode clipTop is 0, i.e. the full screen).
        dc.setClip(0, clipTop, width, height - clipTop);

        for (var i = 0; i < appState.foodItems.size(); i++) {
            var foodItem = appState.foodItems[i];
            if (!(foodItem instanceof FoodItem)) {
                continue;
            }

            var col = i % columns;
            var row = i / columns;
            rowCount = row + 1;
            var x0 = margin + col * (cellWidth + gap);
            var y0 = gridTop + row * (cellHeight + gap) - scroll; // on-screen y
            var y1 = y0 + cellHeight;

            // Record the tap region clamped to the visible band, so a partially
            // scrolled tile is tappable on its visible part and a tile hidden
            // under a pinned header can't be tapped.
            var cy0 = y0 < clipTop ? clipTop : y0;
            var cy1 = y1 > height ? height : y1;
            if (cy1 > cy0) {
                coordinates.add({
                    "x0" => x0,
                    "y0" => cy0,
                    "x1" => x0 + cellWidth,
                    "y1" => cy1,
                    "index" => i
                });
            }

            // Skip painting rows entirely outside the visible band.
            if (y1 < clipTop || y0 > height) {
                continue;
            }

            dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x0, y0, cellWidth, cellHeight);

            var bitmap = resolveBitmap(foodItem);
            if (bitmap != null) {
                // Center the image in the area above the name band
                var areaTop = y0 + Layout.GRID_IMAGE_TOP_PAD;
                var areaHeight = cellHeight - nameBand - Layout.GRID_IMAGE_TOP_PAD;
                var bx = x0 + (cellWidth - bitmap.getWidth()) / 2;
                var by = areaTop + (areaHeight - bitmap.getHeight()) / 2;
                dc.drawBitmap(bx, by, bitmap);
            }

            dc.setColor(appState.foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 + cellWidth / 2, y0 + cellHeight - Layout.GRID_NAME_LIFT, Graphics.FONT_XTINY, foodItem.name, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.clearClip();
        appState.updateFoodGridCoordinates(coordinates);
        return rowCount * (cellHeight + gap);
    }

    //! Resolve the bitmap to display: brand-specific first, then category default.
    private function resolveBitmap(foodItem as FoodItem) as BitmapResource? {
        // Brand-specific drawable by picture id. NB: Rez.Drawables can't be
        // indexed by a runtime string in Monkey C (it silently fails), so map
        // the id to its compile-time symbol explicitly.
        var id = brandDrawableId(foodItem.picture);
        if (id == null) {
            id = defaultDrawableId(foodItem.subcategory);
        }
        if (id != null) {
            try {
                return WatchUi.loadResource(id) as BitmapResource;
            } catch (ex) { }
        }
        return null;
    }

    //! Map a brand picture id (from foods.json) to its drawable resource.
    private function brandDrawableId(picture as Lang.String?) as Lang.ResourceId? {
        if (picture == null) {
            return null;
        }
        if (picture.equals("gel_decathlon_energygelplus_redfruit")) {
            return Rez.Drawables.gel_decathlon_energygelplus_redfruit;
        } else if (picture.equals("gel_decathlon_energygel_redfruit_minus3h")) {
            return Rez.Drawables.gel_decathlon_energygel_redfruit_minus3h;
        } else if (picture.equals("gel_decathlon_108_cola")) {
            return Rez.Drawables.gel_decathlon_108_cola;
        } else if (picture.equals("jelly_red_fruit")) {
            return Rez.Drawables.jelly_red_fruit;
        } else if (picture.equals("bar_energy_dates_nuts")) {
            return Rez.Drawables.bar_energy_dates_nuts;
        }
        return null;
    }

    //! Category fallback drawable when a food has no (known) brand picture.
    private function defaultDrawableId(subcategory as Lang.String) as Lang.ResourceId? {
        var sub = subcategory.toUpper();
        if (sub.equals("GEL")) {
            return Rez.Drawables.default_gel;
        } else if (sub.equals("JELLIES")) {
            return Rez.Drawables.default_jellies;
        } else if (sub.equals("BAR")) {
            return Rez.Drawables.default_bar;
        } else if (sub.equals("DRINKS")) {
            return Rez.Drawables.default_drinks;
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
                // Both queued and serialized by NightscoutService
                nightscoutService.fetchGlucoseData();
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