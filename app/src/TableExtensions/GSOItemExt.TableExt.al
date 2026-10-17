namespace GMSoft.InventoryPlanning;

using Microsoft.Inventory.Item;

/// <summary>
/// Per-item planning controls: an exclusion flag so planner-maintained values
/// are never overwritten by a bulk or scheduled run, and an optional per-item
/// service level that overrides the company default (0 = use setup default).
/// </summary>
tableextension 73030575 "GSO Item Ext" extends Item
{
    fields
    {
        field(73030575; "GSO Exclude From Planning"; Boolean)
        {
            Caption = 'Exclude from Inventory Planning';
            DataClassification = CustomerContent;
        }
        field(73030576; "GSO Service Level %"; Decimal)
        {
            Caption = 'Planning Service Level % (0 = default)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            MaxValue = 99.99;
        }
    }
}
