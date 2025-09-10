import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;
import Toybox.Time;
import Toybox.Timer;

class TempOverridesView extends WatchUi.View {

    //private var tempBasals as Lang.Array = [];
    //public var activeProfile as Lang.String = "";
    //private var presetCoordinates as Lang.Array = [];
    private var appState as AppState;

    function initialize(appState as AppState) {
        View.initialize();
        self.appState = appState;
    }

    function onShow() as Void {
        // Déclencher la récupération des données
        var app = Application.getApp() as DiabetesFoodManagementApp;
        if (app != null) {
            app.getNightscoutService().fetchTempBasalData();
        }
        
        // Programmer une mise à jour dans 2 secondes pour laisser le temps au réseau
        var timer = new Timer.Timer();
        timer.start(method(:updateData), 2000, false);
    }

    function updateData() as Void {
        var app = Application.getApp() as DiabetesFoodManagementApp;
        if (app != null) {
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Dc) as Void {
        // Récupérer les données à chaque mise à jour
        var tempBasals = appState.tempBasals;
        var activeProfile = appState.activeProfile;
        System.println("activeProfile: " + activeProfile);
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Title
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, 10, Graphics.FONT_SMALL, WatchUi.loadResource(Rez.Strings.temp_overrides_label), Graphics.TEXT_JUSTIFY_CENTER);
        
        var yPos = 50;
        var buttonHeight = 50;
        var buttonWidth = width - 20;
        var buttonX = 10;
        
        // Réinitialiser les coordonnées
        appState.presetCoordinatesProfile = [];
        
        // Bouton "Default" (toujours présent)
        var defaultColor = activeProfile.equals(Constants.DEFAULT_OVERRIDE_PROFIL) ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_BLUE;
        drawButton(dc, buttonX, yPos, buttonWidth, buttonHeight, Constants.DEFAULT_OVERRIDE_PROFIL, defaultColor);
        
        // Enregistrer les coordonnées du bouton Default
        appState.presetCoordinatesProfile.add({
            "name" => Constants.DEFAULT_OVERRIDE_PROFIL,
            "startY" => yPos,
            "endY" => yPos + buttonHeight
        });
        
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
                
                // Enregistrer les coordonnées de ce preset
                appState.presetCoordinatesProfile.add({
                    "name" => nameStr,
                    "startY" => yPos,
                    "endY" => yPos + buttonHeight
                });
                
                yPos += buttonHeight + 10;
            }
        }
        
        // Afficher le profil actif
        if (activeProfile.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var profileText = WatchUi.loadResource(Rez.Strings.active_profile_label) + ": " + activeProfile;
            dc.drawText(width/2, yPos + 10, Graphics.FONT_XTINY, profileText, Graphics.TEXT_JUSTIFY_CENTER);
        }   
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
            var app = Application.getApp() as DiabetesFoodManagementApp;
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