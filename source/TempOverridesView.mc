import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;
import Toybox.Time;
import Toybox.Timer;

class TempOverridesView extends WatchUi.View {
    private var appState as AppState;

    function initialize(appState as AppState) {
        View.initialize();
        self.appState = appState;
    }

    function onShow() as Void {
        // Déclencher la récupération des données
        var app = Application.getApp() as DiabetesFoodLoopApp;
        if (app != null) {
            app.getNightscoutService().fetchTempBasalData();
        }
        
        // Programmer une mise à jour dans 2 secondes pour laisser le temps au réseau
        var timer = new Timer.Timer();
        timer.start(method(:updateData), 2000, false);
    }

    function updateData() as Void {
        var app = Application.getApp() as DiabetesFoodLoopApp;
        if (app != null) {
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Dc) as Void {
        var tempBasals = appState.tempBasals;
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

        // Default row (always present)
        drawProfileRow(dc, yPos, width, rowHeight, Constants.DEFAULT_OVERRIDE_PROFIL, activeProfile.equals(Constants.DEFAULT_OVERRIDE_PROFIL));
        appState.presetCoordinatesProfile.add({
            "name" => Constants.DEFAULT_OVERRIDE_PROFIL,
            "startY" => yPos,
            "endY" => yPos + rowHeight
        });
        yPos += rowHeight;

        // One row per preset
        for (var i = 0; i < tempBasals.size() && yPos < height - rowHeight; i++) {
            var override = tempBasals[i];
            if (override instanceof Lang.Dictionary && override.hasKey("name")) {
                var nameStr = override.get("name").toString();
                drawProfileRow(dc, yPos, width, rowHeight, nameStr, activeProfile.equals(nameStr));
                appState.presetCoordinatesProfile.add({
                    "name" => nameStr,
                    "startY" => yPos,
                    "endY" => yPos + rowHeight
                });
                yPos += rowHeight;
            }
        }
    }

    //! Draw one full-width list row, Garmin Edge style: left-aligned label, a
    //! thin separator underneath, and — when active — a green left accent bar,
    //! green label and a checkmark on the right. No boxes, no neon fills.
    function drawProfileRow(dc as Dc, y as Lang.Number, width as Lang.Number, height as Lang.Number, text as Lang.String, isActive as Lang.Boolean) as Void {
        var padLeft = 20;

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
        handlePresetSelection(getCenterYPosition());
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) {
            handlePresetSelection(getCenterYPosition());
            return true;
        }
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coordinates = clickEvent.getCoordinates();
        handlePresetSelection(coordinates[1]); // Y coordinate
        return true;
    }

    private function handlePresetSelection(tapY as Lang.Number) as Void {
        var presetName = view.findPresetAtY(tapY);
        
        if (presetName != null) {
            var app = Application.getApp() as DiabetesFoodLoopApp;
            if (app != null) {
                var nightscoutService = app.getNightscoutService();
                if (presetName.equals(Constants.DEFAULT_OVERRIDE_PROFIL)) {
                    nightscoutService.desactivePreset();
                }else{
                    nightscoutService.activatePreset(presetName);
                }
                System.println("Activating preset: " + presetName);
            }
        } else {
            System.println("No preset found at Y: " + tapY);
        }
    }


    //! Get estimated center Y position for button selection
    private function getCenterYPosition() as Lang.Number {
        return 100; // Default center position when no tap coordinates
    }
}