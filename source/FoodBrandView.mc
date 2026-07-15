import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

//! Level 2 of food selection: brands within a subcategory.
class FoodBrandView extends WatchUi.View {

    private var appState as AppState;
    private var allItems as Lang.Array;
    private var subcategory as Lang.String;
    // Row tap regions: Array of { "brand" => String, "y0" => Number, "y1" => Number }
    var rowCoordinates as Lang.Array = [];

    function initialize(appState as AppState, allItems as Lang.Array, subcategory as Lang.String) {
        View.initialize();
        self.appState = appState;
        self.allItems = allItems;
        self.subcategory = subcategory;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var titleY = 14;
        dc.drawText(width / 2, titleY, Graphics.FONT_SMALL, subcategory,
            Graphics.TEXT_JUSTIFY_CENTER);

        var dividerY = titleY + dc.getFontHeight(Graphics.FONT_SMALL) + 8;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, dividerY, width, dividerY);

        var rowHeight = 54;
        var yPos = dividerY + 1;
        rowCoordinates = [];

        var brands = FoodDatabase.getBrandsForSubcategory(allItems, subcategory);
        for (var i = 0; i < brands.size(); i++) {
            var brand = brands[i].toString();
            var brandItems = FoodDatabase.getItemsForSubcategoryAndBrand(allItems, subcategory, brand);
            var selectedCount = appState.countSelected(brandItems);
            var totalCount = brandItems.size();

            drawRow(dc, yPos, width, rowHeight, brand, selectedCount, totalCount);
            rowCoordinates.add({ "brand" => brand, "y0" => yPos, "y1" => yPos + rowHeight });
            yPos += rowHeight;
        }
    }

    private function drawRow(dc as Dc, y as Lang.Number, width as Lang.Number, rowHeight as Lang.Number,
                             brand as Lang.String, selected as Lang.Number, total as Lang.Number) as Void {
        var midY = y + rowHeight / 2;
        var displayBrand = brand.length() > 0 ? brand : "—";

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(16, midY, Graphics.FONT_SMALL, displayBrand, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var counter = selected.toString() + "/" + total.toString();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 16, midY, Graphics.FONT_XTINY, counter + " >", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, y + rowHeight - 1, width, y + rowHeight - 1);
    }

    //! Find which brand was tapped at y coordinate.
    function brandAtY(y as Lang.Number) as Lang.String? {
        for (var i = 0; i < rowCoordinates.size(); i++) {
            var row = rowCoordinates[i];
            if (row instanceof Lang.Dictionary) {
                var y0 = row.get("y0");
                var y1 = row.get("y1");
                if (y0 instanceof Lang.Number && y1 instanceof Lang.Number && y >= y0 && y <= y1) {
                    var brand = row.get("brand");
                    if (brand instanceof Lang.String) {
                        return brand;
                    }
                }
            }
        }
        return null;
    }
}
