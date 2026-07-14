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

        var rowHeight = 54;
        var yPos = dividerY + 1;

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
        for (var i = 0; i < overridePresets.size() && yPos < height - rowHeight; i++) {
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

        // Keep the focus in range if the preset list shrank
        if (focusedIndex >= rowIndex && rowIndex > 0) {
            focusedIndex = rowIndex - 1;
        }
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
        activatePreset(view.findPresetAtY(coordinates[1])); // Y coordinate
        return true;
    }

    //! Activate (or, for Default, cancel) the named override preset.
    private function activatePreset(presetName as Lang.String?) as Void {
        if (presetName == null) {
            System.println("No preset selected");
            return;
        }
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