import Toybox.Lang;

//! Model for food item with coordinates for touch detection
(:glance, :background)
class FoodItem {
    
    public var name as Lang.String;
    public var carbs as Lang.Number;
    public var category as Lang.String?;
    public var subcategory as Lang.String?;
    public var portion as Lang.String?;
    public var startY as Lang.Number = 0;
    public var endY as Lang.Number = 0;
    public var index as Lang.Number = 0;

    function initialize(foodData as Lang.Dictionary, itemIndex as Lang.Number) {
        name = foodData.hasKey("name") ? foodData.get("name").toString() : "Unknown";
        var carbsValue = foodData.hasKey("carbs") ? foodData.get("carbs") : 0;
        if (carbsValue instanceof Lang.String) {
            carbs = carbsValue.toNumber();
        } else if (carbsValue instanceof Lang.Number) {
            carbs = carbsValue;
        } else {
            carbs = 0;
        }
        category = foodData.hasKey("category") ? foodData.get("category") : null;
        subcategory = foodData.hasKey("subcategory") ? foodData.get("subcategory") : null;
        portion = foodData.hasKey("portion") ? foodData.get("portion") : null;
        index = itemIndex;
    }

    //! Set display coordinates for touch detection
    function setCoordinates(startY as Lang.Number, endY as Lang.Number) as Void {
        self.startY = startY;
        self.endY = endY;
    }

    //! Check if a Y coordinate falls within this food item
    function containsY(y as Lang.Number) as Lang.Boolean {
        return y >= startY && y <= endY;
    }

    //! Get distance from center of this food item to a Y coordinate
    function getDistanceFromCenter(y as Lang.Number) as Lang.Number {
        var centerY = (startY + endY) / 2;
        return y > centerY ? y - centerY : centerY - y;
    }

    //! Convert to dictionary for API calls
    function toDictionary() as Lang.Dictionary {
        return {
            "name" => name,
            "carbs" => carbs,
            "category" => category,
            "subcategory" => subcategory,
            "portion" => portion
        };
    }
}