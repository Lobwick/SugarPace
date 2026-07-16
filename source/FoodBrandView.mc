import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

//! Level 2 of food selection.
//! brandFirst=false: shows brands within a subcategory (filter = subcategory name).
//! brandFirst=true:  shows subcategories within a brand (filter = brand name).
//! Each row is split: left zone navigates to items, right zone (80px) toggles all in scope.
class FoodBrandView extends WatchUi.View {

    private var appState as AppState;
    private var allItems as Lang.Array;
    private var filter as Lang.String;       // subcategory or brand depending on brandFirst
    private var brandFirst as Lang.Boolean;
    // Row tap regions: { "label" => String, "y0" => Number, "y1" => Number,
    //                    "toggleAll" => Boolean, "toggleX" => Number }
    var rowCoordinates as Lang.Array = [];

    function initialize(appState as AppState, allItems as Lang.Array, filter as Lang.String,
                        brandFirst as Lang.Boolean) {
        View.initialize();
        self.appState = appState;
        self.allItems = allItems;
        self.filter = filter;
        self.brandFirst = brandFirst;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var titleY = 14;
        dc.drawText(width / 2, titleY, Graphics.FONT_SMALL, filter, Graphics.TEXT_JUSTIFY_CENTER);

        var dividerY = titleY + dc.getFontHeight(Graphics.FONT_SMALL) + 8;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, dividerY, width, dividerY);

        var rowHeight = 54;
        var yPos = dividerY + 1;
        rowCoordinates = [];

        // Toggle-all first row (full-row toggle, scope = all items for this filter)
        var scopeItems = brandFirst
            ? FoodDatabase.getItemsForBrand(allItems, filter)
            : FoodDatabase.getItemsForSubcategory(allItems, filter);
        var scopeSelected = appState.countSelected(scopeItems);
        var scopeTotal = scopeItems.size();
        drawToggleAllRow(dc, yPos, width, rowHeight, scopeSelected, scopeTotal);
        rowCoordinates.add({ "label" => "", "y0" => yPos, "y1" => yPos + rowHeight,
                             "toggleAll" => true, "toggleX" => 0 });
        yPos += rowHeight;

        // Sub-rows: brands (normal mode) or subcategories (brand-first mode)
        var labels = brandFirst
            ? FoodDatabase.getSubcategoriesForBrand(allItems, filter)
            : FoodDatabase.getBrandsForSubcategory(allItems, filter);
        var toggleX = width - 80;
        for (var i = 0; i < labels.size(); i++) {
            var label = labels[i].toString();
            var labelItems = brandFirst
                ? FoodDatabase.getItemsForSubcategoryAndBrand(allItems, label, filter)
                : FoodDatabase.getItemsForSubcategoryAndBrand(allItems, filter, label);
            var selectedCount = appState.countSelected(labelItems);
            var totalCount = labelItems.size();
            var display = label.length() > 0 ? label : "—";

            drawRow(dc, yPos, width, rowHeight, display, selectedCount, totalCount, toggleX);
            rowCoordinates.add({ "label" => label, "y0" => yPos, "y1" => yPos + rowHeight,
                                 "toggleAll" => false, "toggleX" => toggleX });
            yPos += rowHeight;
        }
    }

    private function drawToggleAllRow(dc as Dc, y as Lang.Number, width as Lang.Number,
                                      rowHeight as Lang.Number, selected as Lang.Number,
                                      total as Lang.Number) as Void {
        var midY = y + rowHeight / 2;
        var checkSize = 18;
        var checkX = 14;
        var checkY = midY - checkSize / 2;

        if (selected == total && total > 0) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(checkX, checkY, checkSize, checkSize);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(checkX + 3, checkY + checkSize / 2, checkX + checkSize / 2 - 1, checkY + checkSize - 4);
            dc.drawLine(checkX + checkSize / 2 - 1, checkY + checkSize - 4, checkX + checkSize - 3, checkY + 4);
            dc.setPenWidth(1);
        } else if (selected > 0) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(checkX, checkY + checkSize / 2 - 2, checkSize, 4);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(checkX, checkY, checkSize, checkSize);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(checkX + checkSize + 10, midY, Graphics.FONT_SMALL, "Tout",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var counter = selected.toString() + "/" + total.toString();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 8, midY, Graphics.FONT_XTINY, counter,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, y + rowHeight - 1, width, y + rowHeight - 1);
    }

    //! Left zone: label + ">" navigate cue. Right zone (80px): checkbox + counter to toggle all.
    private function drawRow(dc as Dc, y as Lang.Number, width as Lang.Number, rowHeight as Lang.Number,
                             label as Lang.String, selected as Lang.Number, total as Lang.Number,
                             toggleX as Lang.Number) as Void {
        var midY = y + rowHeight / 2;

        // Left zone: label and navigate indicator
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(16, midY, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(toggleX - 8, midY, Graphics.FONT_XTINY, ">", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Vertical separator
        dc.drawLine(toggleX, y + 4, toggleX, y + rowHeight - 5);

        // Right zone: toggle-all checkbox + counter
        var checkSize = 14;
        var checkX = toggleX + 6;
        var checkY = midY - checkSize / 2;
        if (selected == total && total > 0) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(checkX, checkY, checkSize, checkSize);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(checkX + 2, checkY + checkSize / 2, checkX + checkSize / 2 - 1, checkY + checkSize - 3);
            dc.drawLine(checkX + checkSize / 2 - 1, checkY + checkSize - 3, checkX + checkSize - 2, checkY + 3);
            dc.setPenWidth(1);
        } else if (selected > 0) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(checkX, checkY + checkSize / 2 - 2, checkSize, 3);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(checkX, checkY, checkSize, checkSize);
        }
        var counter = selected.toString() + "/" + total.toString();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 6, midY, Graphics.FONT_XTINY, counter,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, y + rowHeight - 1, width, y + rowHeight - 1);
    }

    //! Returns the row dict at y, or null.
    function rowAtY(y as Lang.Number) as Lang.Dictionary? {
        for (var i = 0; i < rowCoordinates.size(); i++) {
            var row = rowCoordinates[i];
            if (!(row instanceof Lang.Dictionary)) { continue; }
            var y0 = row.get("y0");
            var y1 = row.get("y1");
            if (!(y0 instanceof Lang.Number)) { continue; }
            if (!(y1 instanceof Lang.Number)) { continue; }
            if (y < y0 || y > y1) { continue; }
            return row;
        }
        return null;
    }

    //! Legacy accessor: returns label for non-toggle rows.
    function brandAtY(y as Lang.Number) as Lang.String? {
        var row = rowAtY(y);
        if (row == null) { return null; }
        var isToggle = row.get("toggleAll");
        if (isToggle instanceof Lang.Boolean && isToggle) { return null; }
        var label = row.get("label");
        if (label instanceof Lang.String) { return label; }
        return null;
    }
}
