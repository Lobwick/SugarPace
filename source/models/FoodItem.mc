import Toybox.Lang;

//! Model for a food item, identified in the UI by its index in the grid
(:glance, :background)
class FoodItem {
    
    public var name as Lang.String;
    public var brand as Lang.String;
    public var subcategory as Lang.String;  // GEL | JELLIES | BAR | DRINKS
    public var picture as Lang.String?;     // optional brand-specific drawable id
    public var carbs as Lang.Number;
    public var portion_g as Lang.Number;
    public var gi as Lang.Number;
    public var fat_g as Lang.Float;
    public var protein_g as Lang.Float;
    public var energy_kj as Lang.Number;
    public var index as Lang.Number = 0;

    function initialize(foodData as Lang.Dictionary, itemIndex as Lang.Number) {
        name        = foodData.hasKey("name")        ? foodData.get("name").toString()        : "Unknown";
        brand       = foodData.hasKey("brand")       ? foodData.get("brand").toString()       : "";
        subcategory = foodData.hasKey("subcategory") ? foodData.get("subcategory").toString() : "GEL";
        var pictureValue = foodData.hasKey("picture") ? foodData.get("picture") : null;
        picture = pictureValue != null ? pictureValue.toString() : null;

        var carbsValue = foodData.hasKey("carbs_g") ? foodData.get("carbs_g") : 0;
        if (carbsValue instanceof Lang.String) {
            carbs = carbsValue.toNumber();
        } else if (carbsValue instanceof Lang.Number) {
            carbs = carbsValue;
        } else {
            carbs = 0;
        }

        portion_g  = _toInt(foodData, "portion_g");
        gi         = _toInt(foodData, "gi");
        energy_kj  = _toInt(foodData, "energy_kj");
        fat_g      = _toFloat(foodData, "fat_g");
        protein_g  = _toFloat(foodData, "protein_g");

        index = itemIndex;
    }

    private function _toInt(d as Lang.Dictionary, key as Lang.String) as Lang.Number {
        if (!d.hasKey(key)) { return 0; }
        var v = d.get(key);
        if (v instanceof Lang.Number) { return v; }
        if (v instanceof Lang.Float)  { return v.toNumber(); }
        if (v instanceof Lang.String) { return v.toNumber(); }
        return 0;
    }

    private function _toFloat(d as Lang.Dictionary, key as Lang.String) as Lang.Float {
        if (!d.hasKey(key)) { return 0.0; }
        var v = d.get(key);
        if (v instanceof Lang.Float)  { return v; }
        if (v instanceof Lang.Number) { return v.toFloat(); }
        if (v instanceof Lang.String) { return v.toFloat(); }
        return 0.0;
    }

    //! Convert to dictionary for Loop API call (only carb-entry fields)
    function toDictionary() as Lang.Dictionary {
        return {
            "name"       => name,
            "carbs_g"    => carbs,
            "subcategory" => subcategory
        };
    }
}