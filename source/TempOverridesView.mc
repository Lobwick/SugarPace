import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;
import Toybox.Time;
import Toybox.Timer;

class TempOverridesView extends WatchUi.View {
    private var appState as AppState;
    // Row highlighted for physical-button selection (touch uses coordinates).
    private var focusedIndex as Lang.Number = 0;
    // Redraw ticker, running only while a bolus confirmation / send is active.
    private var bolusTimer as Timer.Timer?;

    function initialize(appState as AppState) {
        View.initialize();
        self.appState = appState;
    }

    //! Move the button-selection focus, wrapping around the row list.
    function focusNext() as Void {
        var count = appState.presetCoordinatesProfile.size();
        if (count > 0) {
            focusedIndex = (focusedIndex + 1) % count;
            WatchUi.requestUpdate();
        }
    }

    function focusPrevious() as Void {
        var count = appState.presetCoordinatesProfile.size();
        if (count > 0) {
            focusedIndex = (focusedIndex - 1 + count) % count;
            WatchUi.requestUpdate();
        }
    }

    //! Hide the previous failure message when a new activation starts.
    function clearError() as Void {
        appState.setProfileError(0);
    }

    //! Name of the currently focused row (for physical-button activation).
    function getFocusedName() as Lang.String? {
        if (focusedIndex >= 0 && focusedIndex < appState.presetCoordinatesProfile.size()) {
            var coord = appState.presetCoordinatesProfile[focusedIndex];
            if (coord instanceof Lang.Dictionary) {
                var name = coord.get("name");
                if (name != null) {
                    return name.toString();
                }
            }
        }
        return null;
    }

    function onShow() as Void {
        appState.profileErrorCode = 0;
        appState.cancelBolusConfirm();
        // Refresh the recommendation on open; the previous one stays displayed
        // (with its age) until the new one arrives. A failed refresh disables the button.
        var shown = Application.getApp() as SugarPaceApp;
        var svc = shown.getNightscoutService();
        if (svc != null) {
            svc.fetchRecommendedBolus();
        }
        startBolusTick();
        // Déclencher la récupération des données
        var app = Application.getApp() as SugarPaceApp;
        if (app != null) {
            app.getNightscoutService().fetchTempBasalData();
        }
        
        // Programmer une mise à jour dans 2 secondes pour laisser le temps au réseau
        var timer = new Timer.Timer();
        timer.start(method(:updateData), 2000, false);
    }

    function updateData() as Void {
        var app = Application.getApp() as SugarPaceApp;
        if (app != null) {
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Dc) as Void {
        var overridePresets = appState.overridePresets;
        var activeProfile = appState.activeProfile;

        // Dark theme is always used, to match the app's design
        appState.backgroundColor = Graphics.COLOR_BLACK;
        appState.foregroundColor = Graphics.COLOR_WHITE;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();

        // Title, centered, with a thin divider underneath — native list header
        var titleY = 14;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, titleY, Graphics.FONT_SMALL, WatchUi.loadResource(Rez.Strings.temp_overrides_label), Graphics.TEXT_JUSTIFY_CENTER);
        var dividerY = titleY + dc.getFontHeight(Graphics.FONT_SMALL) + 8;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, dividerY, width, dividerY);

        // The bolus section is pinned to the bottom; profile rows share what
        // is left (they shrink on short screens instead of being cut off).
        var bolusTop = height - Layout.BOLUS_SECTION_H;
        var yPos = dividerY + 1;
        var rowCount = 1 + overridePresets.size();
        var rowHeight = Layout.ROW_HEIGHT;
        var fitHeight = (bolusTop - yPos) / rowCount;
        if (fitHeight < rowHeight) { rowHeight = fitHeight; }
        if (rowHeight < Layout.ROW_MIN_HEIGHT) { rowHeight = Layout.ROW_MIN_HEIGHT; }

        // Réinitialiser les coordonnées
        appState.presetCoordinatesProfile = [];
        var rowIndex = 0;

        // Default row (always present)
        drawProfileRow(dc, yPos, width, rowHeight, Constants.DEFAULT_OVERRIDE_PROFIL, activeProfile.equals(Constants.DEFAULT_OVERRIDE_PROFIL), rowIndex == focusedIndex);
        appState.presetCoordinatesProfile.add({
            "name" => Constants.DEFAULT_OVERRIDE_PROFIL,
            "startY" => yPos,
            "endY" => yPos + rowHeight
        });
        yPos += rowHeight;
        rowIndex += 1;

        // One row per preset
        for (var i = 0; i < overridePresets.size() && yPos + rowHeight <= bolusTop; i++) {
            var override = overridePresets[i];
            if (override instanceof Lang.Dictionary && override.hasKey("name")) {
                var nameStr = override.get("name").toString();
                drawProfileRow(dc, yPos, width, rowHeight, nameStr, activeProfile.equals(nameStr), rowIndex == focusedIndex);
                appState.presetCoordinatesProfile.add({
                    "name" => nameStr,
                    "startY" => yPos,
                    "endY" => yPos + rowHeight
                });
                yPos += rowHeight;
                rowIndex += 1;
            }
        }

        // Last activation failed: say why, in a few words, just above the bolus section.
        if (appState.profileErrorCode != 0) {
            var fh = dc.getFontHeight(Graphics.FONT_XTINY);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, bolusTop - fh - Layout.BOLUS_ERR_GAP, Graphics.FONT_XTINY, ErrorText.longText(appState.profileErrorCode), Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawBolusSection(dc, width, bolusTop);

        // Keep the focus in range if the preset list shrank
        if (focusedIndex >= rowIndex && rowIndex > 0) {
            focusedIndex = rowIndex - 1;
        }
    }

    //! True when the user turned the feature on in the settings (off by default).
    private function bolusSendEnabled() as Lang.Boolean {
        var flag = Application.Properties.getValue("enable_bolus_send");
        return flag instanceof Lang.Boolean && flag;
    }

    //! Bottom section: Loop's recommended bolus + a two-tap "send" button.
    private function drawBolusSection(dc as Dc, width as Lang.Number, top as Lang.Number) as Void {
        var now = System.getTimer();
        appState.normalizeBolusState(now);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, top, width, top);

        var pad = Layout.BOLUS_PAD;
        var tinyH = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(pad, top + Layout.BOLUS_LABEL_TOP, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.bolus_section), Graphics.TEXT_JUSTIFY_LEFT);

        // Recommended amount (same freshness rules as the header: hidden when stale)
        var age = appState.getRecommendedBolusAgeSeconds();
        var valueVisible = appState.hasRecommendedBolus && age >= 0 && age < Constants.GLUCOSE_STALE_SEC;
        var valueText = valueVisible ? Units.formatBolus(appState.recommendedBolus) + " U" : "--";
        var valueColor = Graphics.COLOR_YELLOW;
        if (!valueVisible || age >= Constants.GLUCOSE_WARN_SEC || appState.recommendedBolusError != 0) {
            valueColor = Graphics.COLOR_DK_GRAY;
        }
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(pad, top + Layout.BOLUS_LABEL_TOP + tinyH, Graphics.FONT_MEDIUM, valueText, Graphics.TEXT_JUSTIFY_LEFT);
        if (appState.isAwaitingRevalidation()) {
            // A previous send ended ambiguously: say so instead of the age
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pad, top + Layout.BOLUS_SECTION_H - tinyH - Layout.BOLUS_AGE_BOTTOM_PAD, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.bolus_check_loop), Graphics.TEXT_JUSTIFY_LEFT);
        } else if (valueVisible) {
            var ageText = age < 60 ? age + "s" : (age / 60) + "m";
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pad, top + Layout.BOLUS_SECTION_H - tinyH - Layout.BOLUS_AGE_BOTTOM_PAD, Graphics.FONT_XTINY, ageText + " ago", Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Button, right side
        var btnW = (width * Layout.BOLUS_BTN_W_PCT).toNumber();
        if (btnW < Layout.BOLUS_BTN_MIN_W) { btnW = Layout.BOLUS_BTN_MIN_W; }
        var btnX = width - pad - btnW;
        var btnY = top + (Layout.BOLUS_SECTION_H - Layout.BOLUS_BTN_H) / 2;

        var label = "";
        var fill = Graphics.COLOR_BLACK;
        var line = Graphics.COLOR_DK_GRAY;
        var textColor = Graphics.COLOR_DK_GRAY;
        var state = appState.bolusSendState;
        var tappable = false;

        if (state == Constants.SEND_PENDING) {
            label = WatchUi.loadResource(Rez.Strings.send_pending) as Lang.String;
            fill = Graphics.COLOR_ORANGE; line = Graphics.COLOR_ORANGE; textColor = Graphics.COLOR_BLACK;
        } else if (state == Constants.SEND_OK) {
            label = WatchUi.loadResource(Rez.Strings.bolus_sent) as Lang.String;
            fill = Graphics.COLOR_GREEN; line = Graphics.COLOR_GREEN; textColor = Graphics.COLOR_BLACK;
        } else if (state == Constants.SEND_UNCONFIRMED) {
            label = WatchUi.loadResource(Rez.Strings.send_unconfirmed) as Lang.String;
            fill = Graphics.COLOR_RED; line = Graphics.COLOR_RED; textColor = Graphics.COLOR_BLACK;
        } else if (state == Constants.SEND_FAILED) {
            label = ErrorText.shortText(appState.bolusSendErrorCode);
            fill = Graphics.COLOR_RED; line = Graphics.COLOR_RED; textColor = Graphics.COLOR_BLACK;
        } else if (!bolusSendEnabled()) {
            label = WatchUi.loadResource(Rez.Strings.bolus_off) as Lang.String;
        } else if (!appState.canSendBolus()) {
            label = WatchUi.loadResource(Rez.Strings.bolus_none) as Lang.String;
        } else if (appState.isBolusConfirmArmed(now)) {
            label = WatchUi.loadResource(Rez.Strings.bolus_confirm) as Lang.String;
            fill = Graphics.COLOR_ORANGE; line = Graphics.COLOR_ORANGE; textColor = Graphics.COLOR_BLACK;
            tappable = true;
        } else {
            label = WatchUi.loadResource(Rez.Strings.bolus_send) as Lang.String;
            line = Graphics.COLOR_WHITE; textColor = Graphics.COLOR_WHITE;
            tappable = true;
        }
        dc.setColor(fill, fill);
        dc.fillRoundedRectangle(btnX, btnY, btnW, Layout.BOLUS_BTN_H, Layout.BOLUS_BTN_RADIUS);
        dc.setColor(line, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(btnX, btnY, btnW, Layout.BOLUS_BTN_H, Layout.BOLUS_BTN_RADIUS);
        dc.setPenWidth(1);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(btnX + btnW / 2, btnY + (Layout.BOLUS_BTN_H - dc.getFontHeight(Graphics.FONT_SMALL)) / 2, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);

        // Only a button that can act is a tap target
        appState.bolusButtonRegion = tappable
            ? { "x0" => btnX, "y0" => btnY, "x1" => btnX + btnW, "y1" => btnY + Layout.BOLUS_BTN_H }
            : null;
    }

    function isInBolusButton(x as Lang.Number, y as Lang.Number) as Lang.Boolean {
        return appState.isPointInRegion(appState.bolusButtonRegion, x, y);
    }

    //! Two-tap send: the first tap arms a short confirmation window showing the
    //! amount; a second tap inside it (same amount, same recommendation) sends.
    //! Called only for a tap inside the button region.
    function onBolusTap() as Void {
        var now = System.getTimer();
        appState.normalizeBolusState(now);
        if (!bolusSendEnabled() || appState.isBolusLocked(now) || !appState.canSendBolus()) {
            return;
        }
        if (!appState.isBolusConfirmArmed(now)) {
            appState.armBolusConfirm(now);
            startBolusTick();
            return;
        }
        // Confirmed: send exactly what was on screen, then block this recommendation
        var units = appState.bolusArmedUnits;
        appState.cancelBolusConfirm();
        var app = Application.getApp() as SugarPaceApp;
        var otp = app.getOtpService();
        var service = app.getNightscoutService();
        if (otp == null || service == null) {
            return;
        }
        appState.markBolusSent(appState.recommendedBolusTime);
        appState.bolusSentUnits = units;
        appState.setBolusSendState(Constants.SEND_PENDING, 0);
        startBolusTick();
        service.sendBolusEntry(otp.createBolusEntryData(units));
    }

    //! Redraw ticker, alive only while this screen is shown: keeps the age,
    //! the confirmation countdown and the button state honest.
    private function startBolusTick() as Void {
        if (bolusTimer == null) {
            bolusTimer = new Timer.Timer();
        }
        bolusTimer.stop();
        bolusTimer.start(method(:onBolusTick), Layout.BOLUS_TICK_MS, true);
    }

    function onHide() as Void {
        if (bolusTimer != null) {
            bolusTimer.stop();
        }
        appState.cancelBolusConfirm();
    }

    function onBolusTick() as Void {
        var nowMs = System.getTimer();
        var app = Application.getApp() as SugarPaceApp;
        var svc = app.getNightscoutService();
        // A bolus still queued behind another request is cancelled after a while
        // (nothing sent), instead of being left able to deliver later.
        if (appState.bolusSendState == Constants.SEND_PENDING && appState.bolusDispatchedMs < 0 &&
            nowMs - appState.bolusSendChangedMs >= Constants.BOLUS_QUEUE_WAIT_MS && svc != null) {
            if (svc.cancelQueuedBolus()) {
                appState.setBolusSendState(Constants.SEND_FAILED, Constants.QUEUE_BUSY_CODE);
            }
        }
        appState.normalizeBolusState(nowMs);
        if (appState.bolusNeedsRevalidationFetch(Toybox.Time.now().value())) {
            appState.bolusAwaitFetchIssued = true;
            if (svc != null) {
                svc.fetchRecommendedBolus();
            }
        }
        WatchUi.requestUpdate();
    }

    //! Draw one full-width list row, Garmin Edge style: left-aligned label, a
    //! thin separator underneath, and — when active — a green left accent bar,
    //! green label and a checkmark on the right. No boxes, no neon fills.
    function drawProfileRow(dc as Dc, y as Lang.Number, width as Lang.Number, height as Lang.Number, text as Lang.String, isActive as Lang.Boolean, isFocused as Lang.Boolean) as Void {
        var padLeft = 20;

        // Focused (button navigation): subtle inset outline, distinct from the
        // green "active" styling.
        if (isFocused) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRectangle(2, y + 2, width - 4, height - 4);
            dc.setPenWidth(1);
        }

        // Active: green accent bar down the left edge
        if (isActive) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, y, 5, height);
        }

        // Label, left-aligned and vertically centered
        var fh = dc.getFontHeight(Graphics.FONT_SMALL);
        dc.setColor(isActive ? Graphics.COLOR_GREEN : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(padLeft, y + (height - fh) / 2, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_LEFT);

        // Active: checkmark on the right (drawn from lines, glyph-free)
        if (isActive) {
            var cy = y + height / 2;
            var cx = width - 40;
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(cx, cy + 1, cx + 6, cy + 8);
            dc.drawLine(cx + 6, cy + 8, cx + 18, cy - 8);
            dc.setPenWidth(1);
        }

        // Bottom separator line
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, y + height, width, y + height);
    }

    //! Find preset at given Y coordinate
    function findPresetAtY(tapY as Lang.Number) as Lang.String? {
        for (var i = 0; i < appState.presetCoordinatesProfile.size(); i++) {
            var coord = appState.presetCoordinatesProfile[i];
            if (coord instanceof Lang.Dictionary) {
                var startY = coord.get("startY");
                var endY = coord.get("endY");
                if (startY instanceof Lang.Number && endY instanceof Lang.Number && 
                    tapY >= startY && tapY <= endY) {
                    return coord.get("name");
                }
            }
        }
        return null;
    }
}

class TempOverridesInputDelegate extends WatchUi.InputDelegate {
    private var view as TempOverridesView;

    function initialize(view as TempOverridesView) {
        InputDelegate.initialize();
        self.view = view;
    }

    function onMenu() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Lang.Boolean {
        activatePreset(view.getFocusedName());
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) {
            activatePreset(view.getFocusedName());
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            view.focusNext();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            view.focusPrevious();
            return true;
        }
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coordinates = clickEvent.getCoordinates();
        if (view.isInBolusButton(coordinates[0], coordinates[1])) {
            view.onBolusTap();
            return true;
        }
        activatePreset(view.findPresetAtY(coordinates[1])); // Y coordinate
        return true;
    }

    //! Activate (or, for Default, cancel) the named override preset.
    private function activatePreset(presetName as Lang.String?) as Void {
        if (presetName == null) {
            System.println("No preset selected");
            return;
        }
        view.clearError();
        var app = Application.getApp() as SugarPaceApp;
        if (app != null) {
            var nightscoutService = app.getNightscoutService();
            if (presetName.equals(Constants.DEFAULT_OVERRIDE_PROFIL)) {
                nightscoutService.deactivatePreset();
            } else {
                nightscoutService.activatePreset(presetName);
            }
            System.println("Activating preset: " + presetName);
        }
    }
}