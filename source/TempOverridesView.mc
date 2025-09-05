import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;
import Toybox.Time;
import Toybox.Timer;

class TempOverridesView extends WatchUi.View {

    private var tempBasals as Lang.Array = [];
    private var activeProfile as Lang.String = "";

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        // Déclencher la récupération des données
        var app = Application.getApp() as DiabetesFoodManagementApp;
        if (app != null) {
            app.fetchTempBasalData();
        }
        
        // Programmer une mise à jour dans 2 secondes pour laisser le temps au réseau
        var timer = new Timer.Timer();
        timer.start(method(:updateData), 2000, false);
    }

    function updateData() as Void {
        var app = Application.getApp() as DiabetesFoodManagementApp;
        if (app != null) {
            tempBasals = app.getTempBasals();
            activeProfile = app.getActiveProfile();
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Dc) as Void {
        // Récupérer les données à chaque mise à jour
        var app = Application.getApp() as DiabetesFoodManagementApp;
        if (app != null) {
            tempBasals = app.getTempBasals();
            activeProfile = app.getActiveProfile();
        }
        
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Title
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, 10, Graphics.FONT_SMALL, "Temp Overrides", Graphics.TEXT_JUSTIFY_CENTER);
        
        var yPos = 50;
        var buttonHeight = 35;
        var buttonWidth = width - 20;
        var buttonX = 10;
        
        // Bouton "Default" (toujours présent)
        var defaultColor = activeProfile.equals("Default") ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GRAY;
        drawButton(dc, buttonX, yPos, buttonWidth, buttonHeight, "Default", defaultColor);
        yPos += buttonHeight + 10;
        
        // Boutons pour chaque preset
        for (var i = 0; i < tempBasals.size() && yPos < height - 50; i++) {
            var override = tempBasals[i];
            if (override instanceof Lang.Dictionary && override.hasKey("name")) {
                var name = override.get("name");
                var nameStr = name.toString();
                // Mettre en vert si c'est l'override actif
                var buttonColor = activeProfile.equals(nameStr) ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_BLUE;
                drawButton(dc, buttonX, yPos, buttonWidth, buttonHeight, nameStr, buttonColor);
                yPos += buttonHeight + 10;
            }
        }
        
        // Afficher le profil actif
        if (activeProfile.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var profileText = "Profil actif: " + activeProfile;
            dc.drawText(width/2, yPos + 10, Graphics.FONT_XTINY, profileText, Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        // Instructions en bas
        dc.drawText(width/2, height - 15, Graphics.FONT_XTINY, "Menu pour retour", Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    function drawButton(dc as Dc, x as Lang.Number, y as Lang.Number, width as Lang.Number, height as Lang.Number, text as Lang.String, color as Lang.Number) as Void {
        // Dessiner le fond du bouton
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, width, height, 5);
        
        // Dessiner le contour
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, width, height, 5);
        
        // Dessiner le texte centré
        dc.drawText(x + width/2, y + height/2 - 8, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class TempOverridesInputDelegate extends WatchUi.InputDelegate {
    function initialize() {
        InputDelegate.initialize();
    }

    function onMenu() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}