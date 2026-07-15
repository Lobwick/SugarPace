import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

//! Level 1 of food selection: list of subcategories with selected/total counters.
class FoodSelectionView extends WatchUi.View {

    private var appState as AppState;
    private var allItems as Lang.Array;
    // Row tap regions: Array of { "subcategory" => String, "y0" => Number, "y1" => Number }
    var rowCoordinates as Lang.Array = [];

    function initialize(appState as AppState, allItems as Lang.Array) {
        View.initialize();
        self.appState = appState;
        self.allItems = allItems;
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

        var subcategories = FoodDatabase.getSubcategories(allItems);
        for (var i = 0; i < subcategories.size(); i++) {
            var sub = subcategories[i].toString();
            var subItems = FoodDatabase.getItemsForSubcategory(allItems, sub);
            var selectedCount = appState.countSelected(subItems);
            var totalCount = subItems.size();

            drawRow(dc, yPos, width, rowHeight, sub, selectedCount, totalCount);
            rowCoordinates.add({ "subcategory" => sub, "y0" => yPos, "y1" => yPos + rowHeight });
            yPos += rowHeight;
        }
    }

    private function drawRow(dc as Dc, y as Lang.Number, width as Lang.Number, rowHeight as Lang.Number,
                             subcategory as Lang.String, selected as Lang.Number, total as Lang.Number) as Void {
        var midY = y + rowHeight / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(16, midY, Graphics.FONT_SMALL, subcategory, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var counter = selected.toString() + "/" + total.toString();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 16, midY, Graphics.FONT_XTINY, counter + " >", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, y + rowHeight - 1, width, y + rowHeight - 1);
    }

    //! Find which subcategory was tapped at y coordinate.
    function subcategoryAtY(y as Lang.Number) as Lang.String? {
        for (var i = 0; i < rowCoordinates.size(); i++) {
            var row = rowCoordinates[i];
            if (row instanceof Lang.Dictionary) {
                var y0 = row.get("y0");
                var y1 = row.get("y1");
                if (y0 instanceof Lang.Number && y1 instanceof Lang.Number && y >= y0 && y <= y1) {
                    var sub = row.get("subcategory");
                    if (sub instanceof Lang.String) {
                        return sub;
                    }
                }
            }
        }
        return null;
    }
}
