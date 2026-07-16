import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

//! Level 3 of food selection: individual items with check/uncheck toggle.
class FoodItemSelectionView extends WatchUi.View {

    private var appState as AppState;
    var items as Lang.Array;
    // Row tap regions: { "id" => String, "y0" => Number, "y1" => Number }
    // Special id "__all__" identifies the toggle-all row.
    var rowCoordinates as Lang.Array = [];

    function initialize(appState as AppState, items as Lang.Array) {
        View.initialize();
        self.appState = appState;
        self.items = items;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var titleY = 14;
        dc.drawText(width / 2, titleY, Graphics.FONT_SMALL,
            WatchUi.loadResource(Rez.Strings.food_selection_label),
            Graphics.TEXT_JUSTIFY_CENTER);

        var dividerY = titleY + dc.getFontHeight(Graphics.FONT_SMALL) + 8;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, dividerY, width, dividerY);

        var rowHeight = 54;
        var yPos = dividerY + 1;
        rowCoordinates = [];

        // Toggle-all first row
        var selectedCount = appState.countSelected(items);
        var totalCount = items.size();
        drawToggleAllRow(dc, yPos, width, rowHeight, selectedCount, totalCount);
        rowCoordinates.add({ "id" => "__all__", "y0" => yPos, "y1" => yPos + rowHeight });
        yPos += rowHeight;

        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (!(item instanceof FoodItem)) {
                continue;
            }
            var selected = appState.isFoodSelected(item.id);
            drawRow(dc, yPos, width, rowHeight, item.name, selected);
            rowCoordinates.add({ "id" => item.id, "y0" => yPos, "y1" => yPos + rowHeight });
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
        dc.drawText(width - 16, midY, Graphics.FONT_XTINY, counter,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, y + rowHeight - 1, width, y + rowHeight - 1);
    }

    private function drawRow(dc as Dc, y as Lang.Number, width as Lang.Number, rowHeight as Lang.Number,
                             itemName as Lang.String, selected as Lang.Boolean) as Void {
        var midY = y + rowHeight / 2;
        var checkSize = 18;
        var checkX = 14;
        var checkY = midY - checkSize / 2;

        if (selected) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(checkX, checkY, checkSize, checkSize);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(checkX + 3, checkY + checkSize / 2, checkX + checkSize / 2 - 1, checkY + checkSize - 4);
            dc.drawLine(checkX + checkSize / 2 - 1, checkY + checkSize - 4, checkX + checkSize - 3, checkY + 4);
            dc.setPenWidth(1);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(checkX, checkY, checkSize, checkSize);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(checkX + checkSize + 10, midY, Graphics.FONT_SMALL, itemName,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, y + rowHeight - 1, width, y + rowHeight - 1);
    }

    //! Find which food id was tapped at y coordinate. Returns "__all__" for the toggle-all row.
    function foodIdAtY(y as Lang.Number) as Lang.String? {
        for (var i = 0; i < rowCoordinates.size(); i++) {
            var row = rowCoordinates[i];
            if (!(row instanceof Lang.Dictionary)) { continue; }
            var y0 = row.get("y0");
            var y1 = row.get("y1");
            if (!(y0 instanceof Lang.Number)) { continue; }
            if (!(y1 instanceof Lang.Number)) { continue; }
            if (y < y0 || y > y1) { continue; }
            var id = row.get("id");
            if (id instanceof Lang.String) { return id; }
        }
        return null;
    }
}
